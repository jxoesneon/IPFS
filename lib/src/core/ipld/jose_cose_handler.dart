// src/core/ipld/jose_cose_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:catalyst_cose/catalyst_cose.dart';
import 'package:cbor/cbor.dart';
import 'package:convert/convert.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:jose/jose.dart';

/// Handler for JOSE (JWS/JWE) and COSE encoding of IPLD data.
///
/// Provides signing, encryption, and verification for IPLD nodes.
class JoseCoseHandler {
  /// Encodes an IPLD node as a JWS (JSON Web Signature).
  static Future<Uint8List> encodeJWS(IPLDNode node, IPFSPrivateKey privateKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JWS encoding requires a map structure');
    }

    final payload = _extractPayload(node);

    // Cast to ECPublicKey to access EC-specific properties
    final pubKey = privateKey.publicKey;
    final privKey = privateKey.privateKey;

    final jwk = JsonWebKey.fromJson({
      'kty': 'EC',
      'crv': 'P-256',
      'x': base64Url.encode(_bigIntToBytes(pubKey.Q!.x?.toBigInteger())),
      'y': base64Url.encode(_bigIntToBytes(pubKey.Q!.y?.toBigInteger())),
      'd': base64Url.encode(_bigIntToBytes(privKey.d)),
    });

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = utf8.decode(payload)
      ..addRecipient(jwk, algorithm: 'ES256');

    final jws = builder.build();
    return Uint8List.fromList(utf8.encode(jws.toCompactSerialization()));
  }

  /// Encodes an IPLD node as a JWE (JSON Web Encryption).
  static Future<Uint8List> encodeJWE(IPLDNode node, List<int> recipientPublicKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JWE encoding requires a map structure');
    }

    final payload = _extractPayload(node);
    final recipientJwk = JsonWebKey.fromJson({
      'kty': 'EC',
      'crv': 'P-256',
      'x': base64Url.encode(recipientPublicKey.sublist(1, 33)),
      'y': base64Url.encode(recipientPublicKey.sublist(33, 65)),
    });

    final builder = JsonWebEncryptionBuilder()
      ..content = payload
      ..addRecipient(recipientJwk, algorithm: 'ECDH-ES+A256KW')
      ..encryptionAlgorithm = 'A256GCM';

    final jwe = builder.build();
    return Uint8List.fromList(utf8.encode(jwe.toCompactSerialization()));
  }

  /// Encodes an IPLD node as COSE Sign1 (CBOR Object Signing and Encryption).
  static Future<Uint8List> encodeCOSE(IPLDNode node, IPFSPrivateKey privateKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('COSE encoding requires a map structure');
    }

    final payload = _extractPayload(node);

    // Create signer adapter
    final signer = _IpfsCoseSigner(privateKey);

    // Create COSE Sign1 message using named parameters
    final coseSign1 = await CoseSign1.sign(
      protectedHeaders: CoseHeaders.protected(
        alg: signer.alg,
        kid: Uint8List.fromList(utf8.encode('ipfs-key')),
      ),
      unprotectedHeaders: const CoseHeaders.unprotected(),
      payload: payload,
      signer: signer,
    );

    // Encode to CBOR bytes
    final cborValue = coseSign1.toCbor();
    return Uint8List.fromList(cbor.encode(cborValue));
  }

  /// Decodes and verifies a JWS-encoded IPLD node.
  static Future<Uint8List> decodeJWS(IPLDNode node, IPFSPrivateKey privateKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JWS decoding requires a map structure');
    }

    final jwsString = utf8.decode(_extractPayload(node));
    final jws = JsonWebSignature.fromCompactSerialization(jwsString);

    final jwk = JsonWebKey.fromJson({
      'kty': 'EC',
      'crv': 'P-256',
      'x': base64Url.encode(_bigIntToBytes(privateKey.publicKey.Q!.x!.toBigInteger())),
      'y': base64Url.encode(_bigIntToBytes(privateKey.publicKey.Q!.y!.toBigInteger())),
    });

    // Create a key store and add the key
    final keyStore = JsonWebKeyStore()..addKey(jwk);

    final payload = await jws.getPayload(keyStore);
    return Uint8List.fromList(utf8.encode(payload.stringContent));
  }

  /// Decrypts a JWE-encoded IPLD node.
  static Future<Uint8List> decodeJWE(IPLDNode node, List<int> recipientPrivateKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JWE decoding requires a map structure');
    }

    final jweString = utf8.decode(_extractPayload(node));
    final jwe = JsonWebEncryption.fromCompactSerialization(jweString);

    final jwk = JsonWebKey.fromJson({
      'kty': 'EC',
      'crv': 'P-256',
      'd': base64Url.encode(recipientPrivateKey),
    });

    // Create a key store and add the key
    final keyStore = JsonWebKeyStore()..addKey(jwk);

    final payload = await jwe.getPayload(keyStore);
    return Uint8List.fromList(payload.data);
  }

  /// Decodes and verifies a COSE Sign1-encoded IPLD node.
  static Future<Uint8List> decodeCOSE(IPLDNode node, IPFSPrivateKey privateKey) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('COSE decoding requires a map structure');
    }

    final coseData = _extractPayload(node);
    final cborValue = cbor.decode(coseData);

    // Parse COSE Sign1 structure
    final coseSign1 = CoseSign1.fromCbor(cborValue);

    // Create verifier adapter
    final verifier = _IpfsCoseVerifier(privateKey);

    // Verify signature
    final isValid = await coseSign1.verify(verifier: verifier);
    if (!isValid) {
      throw IPLDDecodingError('COSE signature verification failed');
    }

    return coseSign1.payload;
  }

  static Uint8List _extractPayload(IPLDNode node) {
    final payloadEntry = node.mapValue.entries.firstWhere((e) => e.key == 'payload');
    if (payloadEntry.value.kind == Kind.BYTES) {
      return Uint8List.fromList(payloadEntry.value.bytesValue);
    }
    return Uint8List.fromList(utf8.encode(payloadEntry.value.stringValue));
  }

  // Helper method to convert BigInt to bytes
  static Uint8List _bigIntToBytes(BigInt? value) {
    if (value == null) {
      throw IPLDEncodingError('Invalid EC key parameters');
    }
    var hexString = value.toRadixString(16);
    if (hexString.length % 2 != 0) hexString = '0$hexString';
    // Pad to 32 bytes for EC P-256 curve
    hexString = hexString.padLeft(64, '0');
    return Uint8List.fromList(hex.decode(hexString));
  }
}

/// Adapter to use IPFSPrivateKey with catalyst_cose signing API.
class _IpfsCoseSigner implements CatalystCoseSigner {
  _IpfsCoseSigner(this._privateKey);

  final IPFSPrivateKey _privateKey;

  @override
  StringOrInt get alg => const IntValue(-7); // ES256 algorithm identifier

  @override
  Future<Uint8List?> get kid async => Uint8List.fromList(utf8.encode('ipfs-key'));

  @override
  Future<Uint8List> sign(Uint8List data) async {
    // Use IPFSPrivateKey's sign method which does ECDSA with SHA-256
    return _privateKey.sign(data);
  }
}

/// Adapter to use IPFSPrivateKey for verification with catalyst_cose API.
class _IpfsCoseVerifier implements CatalystCoseVerifier {
  _IpfsCoseVerifier(this._privateKey);

  final IPFSPrivateKey _privateKey;

  @override
  StringOrInt get alg => const IntValue(-7); // ES256 algorithm identifier

  @override
  Future<Uint8List?> get kid async => Uint8List.fromList(utf8.encode('ipfs-key'));

  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    // Use IPFSPrivateKey's verify method
    return _privateKey.verify(data, signature);
  }
}
