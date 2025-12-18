// test/core/crypto/encrypted_keystore_test.dart
//
// Tests for encrypted keystore (SEC-001)

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/crypto_utils.dart';
import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:test/test.dart';

void main() {
  group('EncryptedKeystore', () {
    const testPassword = 'secure-test-password-123';

    group('unlock/lock', () {
      test('unlocks keystore with password', () async {
        final keystore = EncryptedKeystore();

        await keystore.unlock(testPassword);

        expect(keystore.isUnlocked, isTrue);
      });

      test('locks keystore and clears master key', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);

        keystore.lock();

        expect(keystore.isUnlocked, isFalse);
      });

      test('uses provided salt', () async {
        final salt = CryptoUtils.randomBytes(16);
        final keystore = EncryptedKeystore();

        await keystore.unlock(testPassword, salt: salt);

        expect(keystore.isUnlocked, isTrue);
      });
    });

    group('generateKey', () {
      test('generates and stores encrypted key', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);

        final publicKey = await keystore.generateKey('test-key');

        expect(publicKey.length, equals(32));
        expect(keystore.hasKey('test-key'), isTrue);
      });

      test('throws if keystore is locked', () async {
        final keystore = EncryptedKeystore();

        expect(
          () => keystore.generateKey('test-key'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws if key name already exists', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('duplicate-key');

        expect(
          () => keystore.generateKey('duplicate-key'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('getKey', () {
      test('retrieves decrypted key pair', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('my-key');

        final keyPair = await keystore.getKey('my-key');

        expect(keyPair, isNotNull);
      });

      test('throws if key not found', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);

        expect(
          () => keystore.getKey('nonexistent'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws if keystore is locked', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('test-key');
        keystore.lock();

        expect(() => keystore.getKey('test-key'), throwsA(isA<StateError>()));
      });
    });

    group('importSeed', () {
      test('imports seed and stores encrypted', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        final seed = CryptoUtils.randomBytes(32);

        final publicKey = await keystore.importSeed('imported', seed);

        expect(publicKey.length, equals(32));
        expect(keystore.hasKey('imported'), isTrue);
      });

      test('rejects wrong length seed', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        final wrongSeed = CryptoUtils.randomBytes(16);

        expect(
          () => keystore.importSeed('bad-import', wrongSeed),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('serialize/deserialize', () {
      test('serializes and deserializes keystore', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('key1', label: 'Test Key');
        await keystore.generateKey('key2');

        final json = keystore.serialize();
        final restored = EncryptedKeystore.deserialize(json);
        await restored.unlock(testPassword, salt: restored._salt);

        expect(restored.hasKey('key1'), isTrue);
        expect(restored.hasKey('key2'), isTrue);
      });

      test('loadAndUnlock restores functional keystore', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        final originalPk = await keystore.generateKey('test');
        final json = keystore.serialize();

        final restored = await EncryptedKeystore.loadAndUnlock(
          json,
          testPassword,
        );
        final restoredPk = restored.getPublicKey('test');

        expect(restoredPk, equals(originalPk));
      });
    });

    group('keyNames and hasKey', () {
      test('lists all key names', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('alpha');
        await keystore.generateKey('beta');
        await keystore.generateKey('gamma');

        expect(keystore.keyNames, containsAll(['alpha', 'beta', 'gamma']));
        expect(keystore.keyNames.length, equals(3));
      });

      test('removeKey removes a key', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        await keystore.generateKey('to-remove');

        expect(keystore.hasKey('to-remove'), isTrue);
        keystore.removeKey('to-remove');
        expect(keystore.hasKey('to-remove'), isFalse);
      });
    });

    group('getPublicKey', () {
      test('returns public key without requiring unlock', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);
        final originalPk = await keystore.generateKey('test');
        keystore.lock();

        final retrievedPk = keystore.getPublicKey('test');

        expect(retrievedPk, equals(originalPk));
      });

      test('returns null for non-existent key', () async {
        final keystore = EncryptedKeystore();
        await keystore.unlock(testPassword);

        expect(keystore.getPublicKey('nonexistent'), isNull);
      });
    });
  });
}

// Extension to access private salt for testing
extension TestableKeystore on EncryptedKeystore {
  Uint8List? get _salt {
    // Access via serialization/deserialization
    final json = serialize();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final saltStr = decoded['salt'] as String?;
    return saltStr != null ? base64Decode(saltStr) : null;
  }
}
