// test/core/crypto/crypto_utils_test.dart
//
// Tests for cryptographic utilities (SEC-001)

import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/crypto/crypto_utils.dart';
import 'package:test/test.dart';

void main() {
  group('CryptoUtils', () {
    group('deriveKey', () {
      test('derives consistent key from password and salt', () {
        const testIterations = 1000;
        final password = 'test-password-123';
        final salt = CryptoUtils.randomBytes(16);

        final key1 = CryptoUtils.deriveKey(password, salt, iterations: testIterations);
        final key2 = CryptoUtils.deriveKey(password, salt, iterations: testIterations);

        expect(key1.length, equals(32));
        expect(key1, equals(key2));
      });

      test('derives different keys with different salts', () {
        final password = 'test-password-123';
        final salt1 = CryptoUtils.randomBytes(16);
        final salt2 = CryptoUtils.randomBytes(16);

        final key1 = CryptoUtils.deriveKey(password, salt1, iterations: 1000);
        final key2 = CryptoUtils.deriveKey(password, salt2, iterations: 1000);

        expect(key1, isNot(equals(key2)));
      });

      test('derives different keys with different passwords', () {
        final salt = CryptoUtils.randomBytes(16);

        final key1 = CryptoUtils.deriveKey('password1', salt, iterations: 1000);
        final key2 = CryptoUtils.deriveKey('password2', salt, iterations: 1000);

        expect(key1, isNot(equals(key2)));
      });

      test('supports custom key length', () {
        final password = 'test-password';
        final salt = CryptoUtils.randomBytes(16);

        final key64 = CryptoUtils.deriveKey(password, salt, keyLength: 64, iterations: 1000);

        expect(key64.length, equals(64));
      });
    });

    group('encrypt/decrypt', () {
      test('encrypts and decrypts data correctly', () async {
        final key = CryptoUtils.randomBytes(32);
        final plaintext = Uint8List.fromList(utf8.encode('Hello, World!'));

        final encrypted = await CryptoUtils.encrypt(plaintext, key);
        final decrypted = await CryptoUtils.decrypt(encrypted, key);

        expect(decrypted, equals(plaintext));
      });

      test('produces different ciphertext each time (random nonce)', () async {
        final key = CryptoUtils.randomBytes(32);
        final plaintext = Uint8List.fromList(utf8.encode('Same message'));

        final encrypted1 = await CryptoUtils.encrypt(plaintext, key);
        final encrypted2 = await CryptoUtils.encrypt(plaintext, key);

        expect(encrypted1.ciphertext, isNot(equals(encrypted2.ciphertext)));
        expect(encrypted1.nonce, isNot(equals(encrypted2.nonce)));
      });

      test('fails to decrypt with wrong key', () async {
        final key1 = CryptoUtils.randomBytes(32);
        final key2 = CryptoUtils.randomBytes(32);
        final plaintext = Uint8List.fromList(utf8.encode('Secret data'));

        final encrypted = await CryptoUtils.encrypt(plaintext, key1);

        expect(() => CryptoUtils.decrypt(encrypted, key2), throwsA(anything));
      });

      test('rejects key of wrong size', () async {
        final wrongKey = CryptoUtils.randomBytes(16); // Should be 32
        final plaintext = Uint8List.fromList([1, 2, 3]);

        expect(() => CryptoUtils.encrypt(plaintext, wrongKey), throwsA(isA<ArgumentError>()));
      });
    });

    group('zeroMemory', () {
      test('zeros buffer contents', () {
        final buffer = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        CryptoUtils.zeroMemory(buffer);

        expect(buffer, equals(Uint8List(8)));
        expect(buffer.every((b) => b == 0), isTrue);
      });

      test('handles empty buffer', () {
        final buffer = Uint8List(0);

        // Should not throw
        CryptoUtils.zeroMemory(buffer);

        expect(buffer.isEmpty, isTrue);
      });
    });

    group('randomBytes', () {
      test('generates bytes of correct length', () {
        expect(CryptoUtils.randomBytes(16).length, equals(16));
        expect(CryptoUtils.randomBytes(32).length, equals(32));
        expect(CryptoUtils.randomBytes(64).length, equals(64));
      });

      test('generates different bytes each call', () {
        final a = CryptoUtils.randomBytes(32);
        final b = CryptoUtils.randomBytes(32);

        expect(a, isNot(equals(b)));
      });
    });

    group('constantTimeEquals', () {
      test('returns true for equal buffers', () {
        final a = Uint8List.fromList([1, 2, 3, 4]);
        final b = Uint8List.fromList([1, 2, 3, 4]);

        expect(CryptoUtils.constantTimeEquals(a, b), isTrue);
      });

      test('returns false for different buffers', () {
        final a = Uint8List.fromList([1, 2, 3, 4]);
        final b = Uint8List.fromList([1, 2, 3, 5]);

        expect(CryptoUtils.constantTimeEquals(a, b), isFalse);
      });

      test('returns false for different length buffers', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 3, 4]);

        expect(CryptoUtils.constantTimeEquals(a, b), isFalse);
      });
    });
  });
}
