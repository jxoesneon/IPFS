// lib/src/core/crypto/rsa_signer.dart
//
// RSA signing service for libp2p peer identity and message signing.
// Uses pointycastle for RSA key generation, signing, and verification.
//
// Peer ID derivation follows the libp2p peer-ids spec:
//   1. Serialize the public key as a protobuf PublicKey message
//      (KeyType=RSA=0, Data=DER-encoded PKIX SubjectPublicKeyInfo).
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
///
/// Keys whose protobuf-encoded form exceeds this size are hashed with SHA-256.
const int _maxInlineKeyBytes = 42;

/// Multihash code for the identity (no-hash) function.
const int _identityMultihashCode = 0x00;

/// Multihash code for SHA-256.
const int _sha256MultihashCode = 0x12;

/// DER hex identifier for SHA-256 used in DigestInfo.
const String _sha256DigestIdentifierHex = '0609608648016503040201';

/// RSA signing service.
///
/// Provides RSA key generation (2048-bit minimum), signing, verification,
/// and peer ID derivation following the libp2p peer-ids specification.
///
/// **Security Features:**
/// - RSA 2048-bit keys (112-bit security level)
/// - RSASSA-PKCS1-v1.5 with SHA-256
/// - PKIX/SPKI DER serialization for public keys
/// - PKCS#1 DER serialization for private keys
///
/// Example:
/// ```dart
/// final signer = RsaSigner();
/// final keyPair = await signer.generateKeyPair();
/// final signature = await signer.sign(data, keyPair);
/// final isValid = await signer.verify(data, signature, keyPair.publicKey);
/// final peerId = signer.derivePeerId(keyPair.publicKey);
/// ```
class RsaSigner {
  /// Creates an RSA signer.
  RsaSigner();

  /// Minimum RSA key size in bits.
  static const int minKeySize = 2048;

  /// Default RSA key size in bits.
  static const int defaultKeySize = 2048;

  /// Generates a new RSA key pair.
  ///
  /// [keySize] - The key size in bits (minimum 2048).
  ///
  /// Throws [ArgumentError] if [keySize] is less than 2048.
  Future<RsaKeyPair> generateKeyPair({int keySize = defaultKeySize}) async {
    if (keySize < minKeySize) {
      throw ArgumentError(
        'RSA key size must be at least $minKeySize bits, got $keySize',
      );
    }

    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), keySize, 64),
          _createSecureRandom(),
        ),
      );

    final pair = keyGen.generateKeyPair();
    return RsaKeyPair(publicKey: pair.publicKey, privateKey: pair.privateKey);
  }

  /// Signs data using RSASSA-PKCS1-v1.5 with SHA-256.
  ///
  /// [data] - The message to sign.
  /// [keyPair] - The RSA key pair containing the private key.
  ///
  /// Returns the RSA signature bytes.
  Future<Uint8List> sign(Uint8List data, RsaKeyPair keyPair) async {
    final modulus = keyPair.privateKey.modulus!;
    final keyLen = (modulus.bitLength + 7) ~/ 8;

    // Hash the message with SHA-256
    final digest = crypto.sha256.convert(data);

    // DER-encode the DigestInfo
    final digestInfo = _derEncodeDigestInfo(digest.bytes);

    // PKCS1 type 1 pad: 0x00 0x01 0xFF...0xFF 0x00 DigestInfo
    final padded = _pkcs1Pad(digestInfo, keyLen);

    // Convert to BigInt
    final paddedInt = _bytesToBigInt(padded);

    // RSA sign: signature = padded^d mod n (using CRT)
    final signatureInt = _rsaSign(paddedInt, keyPair.privateKey);

    // Convert back to bytes
    return _bigIntToBytes(signatureInt, keyLen);
  }

  /// Verifies an RSA signature.
  ///
  /// [data] - The signed message.
  /// [signatureBytes] - The signature to verify.
  /// [publicKey] - The RSA public key.
  ///
  /// Returns `true` if the signature is valid.
  Future<bool> verify(
    Uint8List data,
    Uint8List signatureBytes,
    RSAPublicKey publicKey,
  ) async {
    try {
      final modulus = publicKey.modulus!;
      final keyLen = (modulus.bitLength + 7) ~/ 8;

      // Convert signature to BigInt
      final sigInt = _bytesToBigInt(signatureBytes);

      // RSA verify: decrypted = signature^e mod n
      final decryptedInt = sigInt.modPow(publicKey.publicExponent!, modulus);

      // Convert back to bytes
      final decrypted = _bigIntToBytes(decryptedInt, keyLen);

      // Check PKCS1 type 1 padding and extract DigestInfo
      final digestInfo = _pkcs1Unpad(decrypted, keyLen);
      if (digestInfo == null) return false;

      // Hash the message
      final expectedDigest = crypto.sha256.convert(data);

      // DER-encode the expected DigestInfo
      final expectedDigestInfo = _derEncodeDigestInfo(expectedDigest.bytes);

      // Compare
      return _constantTimeEquals(digestInfo, expectedDigestInfo);
    } catch (e) {
      return false;
    }
  }

  /// Performs RSA signing using CRT (Chinese Remainder Theorem).
  BigInt _rsaSign(BigInt message, RSAPrivateKey privateKey) {
    final p = privateKey.p!;
    final q = privateKey.q!;
    final d = privateKey.privateExponent!;

    final dP = d.remainder(p - BigInt.one);
    final dQ = d.remainder(q - BigInt.one);
    final qInv = q.modInverse(p);

    final mP = message.remainder(p).modPow(dP, p);
    final mQ = message.remainder(q).modPow(dQ, q);

    var h = (mP - mQ) * qInv;
    h = h % p;

    return h * q + mQ;
  }

  /// DER-encodes a DigestInfo structure for SHA-256.
  ///
  /// Format: SEQUENCE { SEQUENCE { OID, NULL }, OCTET STRING hash }
  Uint8List _derEncodeDigestInfo(List<int> hash) {
    final digestIdentifier = _hexStringToBytes(_sha256DigestIdentifierHex);
    // SEQUENCE { SEQUENCE { OID, NULL }, OCTET STRING hash }
    final result = <int>[];
    // Inner SEQUENCE: algorithm identifier + null
    final innerSeq = <int>[
      ...digestIdentifier,
      0x05, 0x00, // NULL
    ];
    // OCTET STRING
    final octetString = <int>[0x04, hash.length, ...hash];
    // Outer SEQUENCE
    final totalLen = innerSeq.length + octetString.length;
    result.addAll([0x30, totalLen, ...innerSeq, ...octetString]);
    return Uint8List.fromList(result);
  }

  /// Applies PKCS#1 v1.5 type 1 padding.
  ///
  /// Format: 0x00 0x01 0xFF...0xFF 0x00 data
  Uint8List _pkcs1Pad(Uint8List data, int keyLen) {
    final padLen = keyLen - data.length - 3;
    final result = Uint8List(keyLen);
    result[0] = 0x00;
    result[1] = 0x01;
    for (var i = 0; i < padLen; i++) {
      result[2 + i] = 0xFF;
    }
    result[2 + padLen] = 0x00;
    result.setRange(3 + padLen, keyLen, data);
    return result;
  }

  /// Removes PKCS#1 v1.5 type 1 padding and returns the data, or null if invalid.
  Uint8List? _pkcs1Unpad(Uint8List padded, int keyLen) {
    if (padded.length < 10) return null;
    if (padded[0] != 0x00 || padded[1] != 0x01) return null;

    var i = 2;
    while (i < padded.length && padded[i] == 0xFF) {
      i++;
    }
    if (i == padded.length || padded[i] != 0x00) return null;
    i++;
    return Uint8List.fromList(padded.sublist(i));
  }

  /// Converts bytes to a BigInt (big-endian, unsigned).
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = result * BigInt.from(256) + BigInt.from(byte);
    }
    return result;
  }

  /// Converts a BigInt to bytes (big-endian, zero-padded to [length]).
  Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(255)).toInt();
      v = v >> 8;
    }
    return result;
  }

  /// Constant-time comparison of two byte arrays.
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Converts a hex string to bytes.
  Uint8List _hexStringToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Serializes an RSA public key to DER-encoded PKIX/SPKI format.
  ///
  /// This is the format used in the libp2p protobuf PublicKey `Data` field
  /// for RSA keys.
  Uint8List serializePublicKey(RSAPublicKey publicKey) {
    // Build the PKCS#1 RSAPublicKey: SEQUENCE { INTEGER modulus, INTEGER exponent }
    final pkcs1Key = ASN1Sequence(
      elements: [
        ASN1Integer(publicKey.modulus!),
        ASN1Integer(publicKey.publicExponent!),
      ],
    );
    final pkcs1Bytes = pkcs1Key.encode();

    // Wrap in SubjectPublicKeyInfo
    final spki = ASN1SubjectPublicKeyInfo(
      ASN1AlgorithmIdentifier(
        ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
      ),
      ASN1BitString(stringValues: pkcs1Bytes),
    );
    return spki.encode();
  }

  /// Deserializes an RSA public key from DER-encoded PKIX/SPKI format.
  RSAPublicKey deserializePublicKey(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    final spki = ASN1SubjectPublicKeyInfo.fromSequence(seq);
    final keyBytes = Uint8List.fromList(spki.subjectPublicKey.stringValues!);
    final keyParser = ASN1Parser(keyBytes);
    final keySeq = keyParser.nextObject() as ASN1Sequence;
    final modulus = (keySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  /// Serializes an RSA private key to DER-encoded PKCS#1 format.
  Uint8List serializePrivateKey(RSAPrivateKey privateKey) {
    final seq = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.zero), // version
        ASN1Integer(privateKey.modulus!),
        ASN1Integer(privateKey.publicExponent!),
        ASN1Integer(privateKey.privateExponent!),
        ASN1Integer(privateKey.p!),
        ASN1Integer(privateKey.q!),
        ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
        ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
        ASN1Integer(privateKey.q!.modInverse(privateKey.p!)),
      ],
    );
    return seq.encode();
  }

  /// Derives a libp2p peer ID from an RSA public key.
  ///
  /// The peer ID is a base58-encoded multihash of the protobuf-encoded
  /// public key. For RSA keys (which are larger than 42 bytes when
  /// protobuf-encoded), SHA-256 is used as the hash function.
  String derivePeerId(RSAPublicKey publicKey) {
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
  Uint8List encodePublicKeyPb(RSAPublicKey publicKey) {
    final publicKeyBytes = serializePublicKey(publicKey);
    final publicKeyPb = PublicKeyPb(
      type: KeyType.rsa,
      data: Uint8List.fromList(publicKeyBytes),
    );
    return publicKeyPb.encode();
  }

  /// Decodes a protobuf PublicKey message into an RSA public key.
  RSAPublicKey decodePublicKeyPb(Uint8List pbBytes) {
    final pb = PublicKeyPb.decode(pbBytes);
    if (pb.type != KeyType.rsa) {
      throw ArgumentError('Expected RSA key type, got ${pb.type}');
    }
    return deserializePublicKey(pb.data);
  }
}

/// An RSA key pair containing the public and private keys.
class RsaKeyPair {
  /// Creates an RSA key pair.
  RsaKeyPair({required this.publicKey, required this.privateKey});

  /// The RSA public key.
  final RSAPublicKey publicKey;

  /// The RSA private key.
  final RSAPrivateKey privateKey;
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
