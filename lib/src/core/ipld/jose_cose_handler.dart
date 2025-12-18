// src/core/ipld/jose_cose_handler.dart
import 'dart:convert';
import 'dart:typed_data';

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
  static Future<Uint8List> encodeJWS(
    IPLDNode node,
    IPFSPrivateKey privateKey,
  ) async {
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

  static Future<Uint8List> encodeJWE(
    IPLDNode node,
    List<int> recipientPublicKey,
  ) async {
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

  static Future<Uint8List> encodeCOSE(
    IPLDNode node,
    IPFSPrivateKey privateKey,
  ) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('COSE encoding requires a map structure');
    }

    // final payload = _extractPayload(node);

    // Create COSE Sign1 message using CatalystCose
    /*
    final coseValue = await CatalystCose.sign1(
      privateKey: _privateKeyToBytes(privateKey),
      payload: payload,
      kid: CborString('ipfs-key'),
    );
    */
    throw UnimplementedError('CatalystCose not available');
  }

  static Future<Uint8List> decodeJWS(
    IPLDNode node,
    IPFSPrivateKey privateKey,
  ) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JWS decoding requires a map structure');
    }

    final jwsString = utf8.decode(_extractPayload(node));
    final jws = JsonWebSignature.fromCompactSerialization(jwsString);

    final jwk = JsonWebKey.fromJson({
      'kty': 'EC',
      'crv': 'P-256',
      'x': base64Url.encode(
        _bigIntToBytes(privateKey.publicKey.Q!.x!.toBigInteger()),
      ),
      'y': base64Url.encode(
        _bigIntToBytes(privateKey.publicKey.Q!.y!.toBigInteger()),
      ),
    });

    // Create a key store and add the key
    final keyStore = JsonWebKeyStore()..addKey(jwk);

    final payload = await jws.getPayload(keyStore);
    return Uint8List.fromList(utf8.encode(payload.stringContent));
  }

  static Future<Uint8List> decodeJWE(
    IPLDNode node,
    List<int> recipientPrivateKey,
  ) async {
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

  static Future<Uint8List> decodeCOSE(
    IPLDNode node,
    IPFSPrivateKey privateKey,
  ) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('COSE decoding requires a map structure');
    }

    final coseData = _extractPayload(node);
    // ignore: unused_local_variable
    final coseValue = cbor.decode(coseData);

    /*
    final isValid = await CatalystCose.verifyCoseSign1(
      coseSign1: coseValue,
      publicKey: _publicKeyToBytes(privateKey.publicKey),
    );
    */
    // Stubbed validation
    // ignore: unused_local_variable
    final isValid = false;
    throw UnimplementedError('CatalystCose not available');
  }

  static Uint8List _extractPayload(IPLDNode node) {
    final payloadEntry = node.mapValue.entries.firstWhere(
      (e) => e.key == 'payload',
    );
    return Uint8List.fromList(utf8.encode(payloadEntry.value.stringValue));
  }

  // Helper method to convert BigInt to bytes
  static Uint8List _bigIntToBytes(BigInt? value) {
    if (value == null) {
      throw IPLDEncodingError('Invalid EC key parameters');
    }
    final bytes = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(hex.decode(bytes));
  }
}
