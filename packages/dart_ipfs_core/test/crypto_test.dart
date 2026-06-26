import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('CryptoUtils', () {
    test('deriveKey returns deterministic key for same password/salt', () {
      final salt = CryptoUtils.generateSalt();
      final key1 = CryptoUtils.deriveKey('password', salt);
      final key2 = CryptoUtils.deriveKey('password', salt);
      expect(key1, equals(key2));
      expect(key1.length, equals(CryptoUtils.keySize));
    });

    test('deriveKey returns different keys for different salts', () {
      final salt1 = CryptoUtils.generateSalt();
      final salt2 = CryptoUtils.generateSalt();
      final key1 = CryptoUtils.deriveKey('password', salt1);
      final key2 = CryptoUtils.deriveKey('password', salt2);
      expect(key1, isNot(equals(key2)));
    });

    test('encrypt/decrypt round trip', () async {
      final key = CryptoUtils.randomBytes(CryptoUtils.keySize);
      final plaintext = Uint8List.fromList(utf8.encode('secret message'));
      final encrypted = await CryptoUtils.encrypt(plaintext, key);
      final decrypted = await CryptoUtils.decrypt(encrypted, key);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt fails with wrong key', () async {
      final key = CryptoUtils.randomBytes(CryptoUtils.keySize);
      final wrongKey = CryptoUtils.randomBytes(CryptoUtils.keySize);
      final plaintext = Uint8List.fromList(utf8.encode('secret message'));
      final encrypted = await CryptoUtils.encrypt(plaintext, key);
      expect(
        () => CryptoUtils.decrypt(encrypted, wrongKey),
        throwsA(isA<Exception>()),
      );
    });

    test('constantTimeEquals', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3]);
      final c = Uint8List.fromList([1, 2, 4]);
      expect(CryptoUtils.constantTimeEquals(a, b), isTrue);
      expect(CryptoUtils.constantTimeEquals(a, c), isFalse);
      expect(
        CryptoUtils.constantTimeEquals(a, Uint8List.fromList([1, 2])),
        isFalse,
      );
    });
  });

  group('Ed25519Signer', () {
    test('generates key pair', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKey(keyPair);
      expect(publicKey.bytes.length, equals(32));
    });

    test('sign/verify round trip', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKey(keyPair);
      final data = Uint8List.fromList(utf8.encode('message'));
      final signature = await signer.sign(data, keyPair);
      expect(signature.length, equals(64));
      final valid = await signer.verify(data, signature, publicKey);
      expect(valid, isTrue);
    });

    test('verify fails with wrong signature', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKey(keyPair);
      final data = Uint8List.fromList(utf8.encode('message'));
      final wrongSig = Uint8List(64);
      final valid = await signer.verify(data, wrongSig, publicKey);
      expect(valid, isFalse);
    });

    test('deterministic key pair from seed', () async {
      final signer = Ed25519Signer();
      final seed = Uint8List(32);
      final kp1 = await signer.generateKeyPair(seed: seed);
      final kp2 = await signer.generateKeyPair(seed: seed);
      final pub1 = await signer.extractPublicKeyBytes(kp1);
      final pub2 = await signer.extractPublicKeyBytes(kp2);
      expect(pub1, equals(pub2));
    });
  });
}
