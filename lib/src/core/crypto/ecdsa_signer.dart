// lib/src/core/crypto/ecdsa_signer.dart
//
// ECDSA signing service for libp2p peer identity and message signing.
// Uses pointycastle for ECDSA key generation, signing, and verification
// on the P-256 (secp256r1/prime256v1) curve.
//
// Peer ID derivation follows the libp2p peer-ids spec:
//   1. Serialize the public key as a protobuf PublicKey message
//      (KeyType=ECDSA=3, Data=DER-encoded PKIX SubjectPublicKeyInfo).
//   2. If the protobuf encoding is <= 42 bytes, use identity multihash;
//      otherwise hash with SHA-256 (code 0x12).
//   3. Base58-encode the resulting multihash.
//
// Spec: https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import '../../utils/base58.dart';
import '../peer/peer_record_pb.dart';

/// Maximum protobuf-encoded public key size that uses identity multihash.
const int _maxInlineKeyBytes = 42;

/// Multihash code for the identity (no-hash) function.
const int _identityMultihashCode = 0x00;

/// Multihash code for SHA-256.
const int _sha256MultihashCode = 0x12;

/// ECDSA signing service using the P-256 (secp256r1) curve.
///
/// Provides ECDSA key generation, signing, verification, and peer ID
/// derivation following the libp2p peer-ids specification.
///
/// **Security Features:**
/// - ECDSA P-256 curve (128-bit security level)
/// - SHA-256 message hashing before signing
/// - PKIX/SPKI DER serialization for public keys
/// - ASN.1 DER signature encoding (SEQUENCE { INTEGER r, INTEGER s })
///
/// Example:
/// ```dart
/// final signer = EcdsaSigner();
/// final keyPair = await signer.generateKeyPair();
/// final signature = await signer.sign(data, keyPair);
/// final isValid = await signer.verify(data, signature, keyPair.publicKey);
/// final peerId = signer.derivePeerId(keyPair.publicKey);
/// ```
class EcdsaSigner {

  /// Creates an ECDSA signer.
  EcdsaSigner();
  /// The P-256 domain parameters.
  final ECDomainParameters domainParams = ECDomainParameters('secp256r1');

  /// Generates a new ECDSA P-256 key pair.
  Future<EcdsaKeyPair> generateKeyPair() async {
    final keyGen = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(domainParams),
          _createSecureRandom(),
        ),
      );

    final pair = keyGen.generateKeyPair();
    return EcdsaKeyPair(publicKey: pair.publicKey, privateKey: pair.privateKey);
  }

  /// Signs data using ECDSA with SHA-256 on P-256.
  ///
  /// [data] - The message to sign.
  /// [keyPair] - The ECDSA key pair containing the private key.
  ///
  /// Returns the ASN.1 DER-encoded signature (SEQUENCE { INTEGER r, INTEGER s }).
  Future<Uint8List> sign(Uint8List data, EcdsaKeyPair keyPair) async {
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(keyPair.privateKey),
          _createSecureRandom(),
        ),
      );
    final sig = signer.generateSignature(data) as ECSignature;
    return _encodeEcdsaSignature(sig);
  }

  /// Verifies an ECDSA signature.
  ///
  /// [data] - The signed message.
  /// [signatureBytes] - The ASN.1 DER-encoded signature.
  /// [publicKey] - The ECDSA public key.
  ///
  /// Returns `true` if the signature is valid.
  Future<bool> verify(
    Uint8List data,
    Uint8List signatureBytes,
    ECPublicKey publicKey,
  ) async {
    try {
      final sig = _decodeEcdsaSignature(signatureBytes);
      final verifier = ECDSASigner(SHA256Digest())
        ..init(false, PublicKeyParameter<ECPublicKey>(publicKey));
      return verifier.verifySignature(data, sig);
    } catch (e) {
      return false;
    }
  }

  /// Serializes an ECDSA public key to DER-encoded PKIX/SPKI format.
  ///
  /// This is the format used in the libp2p protobuf PublicKey `Data` field
  /// for ECDSA keys.
  Uint8List serializePublicKey(ECPublicKey publicKey) {
    // Get the encoded EC point (uncompressed: 0x04 || x || y)
    final ecPointBytes = publicKey.Q!.getEncoded(false);

    // Wrap in SubjectPublicKeyInfo with EC algorithm identifier
    final spki = ASN1SubjectPublicKeyInfo(
      ASN1AlgorithmIdentifier(
        ASN1ObjectIdentifier.fromIdentifierString('1.2.840.10045.2.1'),
        parameters: ASN1ObjectIdentifier.fromIdentifierString(
          '1.2.840.10045.3.1.7',
        ),
      ),
      ASN1BitString(stringValues: ecPointBytes),
    );
    return spki.encode();
  }

  /// Deserializes an ECDSA public key from DER-encoded PKIX/SPKI format.
  ECPublicKey deserializePublicKey(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    final spki = ASN1SubjectPublicKeyInfo.fromSequence(seq);
    final ecPointBytes = Uint8List.fromList(
      spki.subjectPublicKey.stringValues!,
    );
    final point = domainParams.curve.decodePoint(ecPointBytes);
    return ECPublicKey(point, domainParams);
  }

  /// Derives a libp2p peer ID from an ECDSA public key.
  ///
  /// The peer ID is a base58-encoded multihash of the protobuf-encoded
  /// public key. For ECDSA P-256 keys (which are larger than 42 bytes when
  /// protobuf-encoded), SHA-256 is used as the hash function.
  String derivePeerId(ECPublicKey publicKey) {
    final encoded = encodePublicKeyPb(publicKey);
    return _multihashToPeerId(encoded);
  }

  /// Creates a peer ID string from a protobuf-encoded public key.
  String _multihashToPeerId(Uint8List encodedPublicKey) {
    Uint8List multihash;
    if (encodedPublicKey.length <= _maxInlineKeyBytes) {
      // Identity multihash
      final result = <int>[
        _identityMultihashCode,
        encodedPublicKey.length,
        ...encodedPublicKey,
      ];
      multihash = Uint8List.fromList(result);
    } else {
      // SHA-256 multihash
      final digest = crypto.sha256.convert(encodedPublicKey);
      final result = <int>[
        _sha256MultihashCode,
        digest.bytes.length,
        ...digest.bytes,
      ];
      multihash = Uint8List.fromList(result);
    }
    return Base58().encode(multihash);
  }

  /// Encodes a public key as a protobuf PublicKey message.
  ///
  /// Returns the raw protobuf bytes.
  Uint8List encodePublicKeyPb(ECPublicKey publicKey) {
    final publicKeyBytes = serializePublicKey(publicKey);
    final publicKeyPb = PublicKeyPb(
      type: KeyType.ecdsa,
      data: Uint8List.fromList(publicKeyBytes),
    );
    return publicKeyPb.encode();
  }

  /// Decodes a protobuf PublicKey message into an ECDSA public key.
  ECPublicKey decodePublicKeyPb(Uint8List pbBytes) {
    final pb = PublicKeyPb.decode(pbBytes);
    if (pb.type != KeyType.ecdsa) {
      throw ArgumentError('Expected ECDSA key type, got ${pb.type}');
    }
    return deserializePublicKey(pb.data);
  }

  /// Encodes an ECSignature to ASN.1 DER format.
  ///
  /// Format: SEQUENCE { INTEGER r, INTEGER s }
  Uint8List _encodeEcdsaSignature(ECSignature sig) {
    final seq = ASN1Sequence(
      elements: [ASN1Integer(sig.r), ASN1Integer(sig.s)],
    );
    return seq.encode();
  }

  /// Decodes an ASN.1 DER-encoded ECDSA signature.
  ECSignature _decodeEcdsaSignature(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    final r = (seq.elements![0] as ASN1Integer).integer!;
    final s = (seq.elements![1] as ASN1Integer).integer!;
    return ECSignature(r, s);
  }
}

/// An ECDSA key pair containing the public and private keys.
class EcdsaKeyPair {
  /// Creates an ECDSA key pair.
  EcdsaKeyPair({required this.publicKey, required this.privateKey});

  /// The ECDSA public key.
  final ECPublicKey publicKey;

  /// The ECDSA private key.
  final ECPrivateKey privateKey;
}

/// Creates a cryptographically secure random number generator.
SecureRandom _createSecureRandom() {
  final random = FortunaRandom();
  final secureRandom = Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    seed[i] = secureRandom.nextInt(256);
  }
  random.seed(KeyParameter(seed));
  return random;
}
