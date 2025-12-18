// test/core/crypto/ed25519_signer_test.dart
//
// Tests for Ed25519 signing service (SEC-004)

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/crypto_utils.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:test/test.dart';

void main() {
  group('Ed25519Signer', () {
    late Ed25519Signer signer;

    setUp(() {
      signer = Ed25519Signer();
    });

    group('generateKeyPair', () {
      test('generates valid key pair', () async {
        final keyPair = await signer.generateKeyPair();
        final publicKey = await signer.extractPublicKeyBytes(keyPair);

        expect(publicKey.length, equals(32));
      });

      test('generates different key pairs each time', () async {
        final keyPair1 = await signer.generateKeyPair();
        final keyPair2 = await signer.generateKeyPair();

        final pk1 = await signer.extractPublicKeyBytes(keyPair1);
        final pk2 = await signer.extractPublicKeyBytes(keyPair2);

        expect(pk1, isNot(equals(pk2)));
      });

      test('generates deterministic key pair from seed', () async {
        final seed = CryptoUtils.randomBytes(32);

        final keyPair1 = await signer.generateKeyPair(seed: seed);
        final keyPair2 = await signer.generateKeyPair(seed: seed);

        final pk1 = await signer.extractPublicKeyBytes(keyPair1);
        final pk2 = await signer.extractPublicKeyBytes(keyPair2);

        expect(pk1, equals(pk2));
      });

      test('rejects seed of wrong length', () async {
        final wrongSeed = CryptoUtils.randomBytes(16);

        expect(
          () => signer.generateKeyPair(seed: wrongSeed),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('sign and verify', () {
      test('signs data and verifies signature', () async {
        final keyPair = await signer.generateKeyPair();
        final data = Uint8List.fromList(utf8.encode('Hello, IPNS!'));

        final signature = await signer.sign(data, keyPair);
        final publicKey = await signer.extractPublicKey(keyPair);

        expect(signature.length, equals(64));
        expect(await signer.verify(data, signature, publicKey), isTrue);
      });

      test('fails to verify with wrong data', () async {
        final keyPair = await signer.generateKeyPair();
        final data1 = Uint8List.fromList(utf8.encode('Original'));
        final data2 = Uint8List.fromList(utf8.encode('Tampered'));

        final signature = await signer.sign(data1, keyPair);
        final publicKey = await signer.extractPublicKey(keyPair);

        expect(await signer.verify(data2, signature, publicKey), isFalse);
      });

      test('fails to verify with wrong public key', () async {
        final keyPair1 = await signer.generateKeyPair();
        final keyPair2 = await signer.generateKeyPair();
        final data = Uint8List.fromList(utf8.encode('Test data'));

        final signature = await signer.sign(data, keyPair1);
        final wrongPublicKey = await signer.extractPublicKey(keyPair2);

        expect(await signer.verify(data, signature, wrongPublicKey), isFalse);
      });

      test('fails to verify tampered signature', () async {
        final keyPair = await signer.generateKeyPair();
        final data = Uint8List.fromList(utf8.encode('Important'));

        final signature = await signer.sign(data, keyPair);
        signature[0] ^= 0xFF; // Tamper with signature

        final publicKey = await signer.extractPublicKey(keyPair);

        expect(await signer.verify(data, signature, publicKey), isFalse);
      });
    });

    group('keyPairFromSeed', () {
      test('recovers key pair from seed', () async {
        final seed = CryptoUtils.randomBytes(32);

        final keyPair1 = await signer.keyPairFromSeed(seed);
        final keyPair2 = await signer.keyPairFromSeed(seed);

        final pk1 = await signer.extractPublicKeyBytes(keyPair1);
        final pk2 = await signer.extractPublicKeyBytes(keyPair2);

        expect(pk1, equals(pk2));
      });
    });

    group('extractSeed', () {
      test('extracts 32-byte seed from key pair', () async {
        final keyPair = await signer.generateKeyPair();

        final seed = await signer.extractSeed(keyPair);

        expect(seed.length, equals(32));
      });

      test('extracted seed can recreate same key pair', () async {
        final keyPair1 = await signer.generateKeyPair();
        final seed = await signer.extractSeed(keyPair1);
        final keyPair2 = await signer.keyPairFromSeed(seed);

        final pk1 = await signer.extractPublicKeyBytes(keyPair1);
        final pk2 = await signer.extractPublicKeyBytes(keyPair2);

        expect(pk1, equals(pk2));
      });
    });

    group('publicKeyFromBytes', () {
      test('creates public key from bytes', () async {
        final keyPair = await signer.generateKeyPair();
        final pkBytes = await signer.extractPublicKeyBytes(keyPair);

        final publicKey = signer.publicKeyFromBytes(pkBytes);

        expect(publicKey.bytes, equals(pkBytes));
      });

      test('rejects wrong length bytes', () {
        final wrongBytes = Uint8List(16);

        expect(
          () => signer.publicKeyFromBytes(wrongBytes),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
