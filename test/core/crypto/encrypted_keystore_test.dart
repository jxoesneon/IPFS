// test/core/crypto/encrypted_keystore_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:test/test.dart';

void main() {
  group('EncryptedKeyEntry', () {
    test('toJson serializes correctly', () {
      final entry = EncryptedKeyEntry(
        encryptedSeed: Uint8List.fromList([1, 2, 3]),
        nonce: Uint8List.fromList([4, 5, 6]),
        publicKey: Uint8List.fromList([7, 8, 9]),
        createdAt: DateTime(2025, 1, 1),
        label: 'test-label',
      );

      final json = entry.toJson();
      expect(json['label'], equals('test-label'));
      expect(json.containsKey('encryptedSeed'), isTrue);
      expect(json.containsKey('nonce'), isTrue);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'encryptedSeed': base64Encode([1, 2, 3]),
        'nonce': base64Encode([4, 5, 6]),
        'publicKey': base64Encode([7, 8, 9]),
        'createdAt': '2025-01-01T00:00:00.000',
        'label': 'restored',
      };

      final entry = EncryptedKeyEntry.fromJson(json);
      expect(entry.label, equals('restored'));
      expect(entry.publicKey.length, equals(3));
    });
  });

  group('EncryptedKeystore Lifecycle', () {
    late EncryptedKeystore keystore;

    setUp(() {
      keystore = EncryptedKeystore();
    });

    tearDown(() {
      keystore.lock();
    });

    test('isUnlocked is false by default', () {
      expect(keystore.isUnlocked, isFalse);
    });

    test('unlock sets isUnlocked to true', () async {
      await keystore.unlock('password123');
      expect(keystore.isUnlocked, isTrue);
    });

    test('lock sets isUnlocked to false', () async {
      await keystore.unlock('password123');
      keystore.lock();
      expect(keystore.isUnlocked, isFalse);
    });
  });

  group('EncryptedKeystore Key Management', () {
    late EncryptedKeystore keystore;

    setUp(() async {
      keystore = EncryptedKeystore();
      await keystore.unlock('secure-password');
    });

    tearDown(() {
      keystore.lock();
    });

    test('generateKey creates new key', () async {
      final publicKey = await keystore.generateKey('my-key');
      expect(publicKey.length, equals(32)); // Ed25519 public key
    });

    test('generateKey with label stores label', () async {
      await keystore.generateKey('labeled-key', label: 'My Label');
      expect(keystore.hasKey('labeled-key'), isTrue);
    });

    test('generateKey throws for duplicate name', () async {
      await keystore.generateKey('dup-key');
      expect(() => keystore.generateKey('dup-key'), throwsA(isA<StateError>()));
    });

    test('hasKey returns true for existing key', () async {
      await keystore.generateKey('existing');
      expect(keystore.hasKey('existing'), isTrue);
    });

    test('hasKey returns false for non-existent key', () {
      expect(keystore.hasKey('nonexistent'), isFalse);
    });

    test('getPublicKey returns public key bytes', () async {
      final generated = await keystore.generateKey('pub-test');
      final retrieved = keystore.getPublicKey('pub-test');
      expect(retrieved, equals(generated));
    });

    test('getPublicKey returns null for missing key', () {
      expect(keystore.getPublicKey('missing'), isNull);
    });

    test('removeKey removes key', () async {
      await keystore.generateKey('to-remove');
      keystore.removeKey('to-remove');
      expect(keystore.hasKey('to-remove'), isFalse);
    });

    test('keyNames lists all keys', () async {
      await keystore.generateKey('key1');
      await keystore.generateKey('key2');
      final names = keystore.keyNames;
      expect(names, contains('key1'));
      expect(names, contains('key2'));
    });
  });

  group('EncryptedKeystore importSeed', () {
    late EncryptedKeystore keystore;

    setUp(() async {
      keystore = EncryptedKeystore();
      await keystore.unlock('password');
    });

    tearDown(() {
      keystore.lock();
    });

    test('importSeed stores seed successfully', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final publicKey = await keystore.importSeed('imported', seed);
      expect(publicKey.length, equals(32));
      expect(keystore.hasKey('imported'), isTrue);
    });

    test('importSeed throws for invalid seed length', () async {
      final invalidSeed = Uint8List.fromList([1, 2, 3]);
      expect(() => keystore.importSeed('bad', invalidSeed), throwsArgumentError);
    });
  });

  group('EncryptedKeystore getKey', () {
    late EncryptedKeystore keystore;

    setUp(() async {
      keystore = EncryptedKeystore();
      await keystore.unlock('password');
    });

    tearDown(() {
      keystore.lock();
    });

    test('getKey retrieves decryptable key', () async {
      await keystore.generateKey('decrypt-test');
      final keyPair = await keystore.getKey('decrypt-test');
      expect(keyPair, isNotNull);
    });

    test('getKey throws for missing key', () async {
      expect(() => keystore.getKey('nonexistent'), throwsArgumentError);
    });
  });

  group('EncryptedKeystore Serialization', () {
    test('serialize produces valid JSON', () async {
      final keystore = EncryptedKeystore();
      await keystore.unlock('password');
      await keystore.generateKey('ser-key');

      final json = keystore.serialize();
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      expect(parsed['version'], equals(1));
      expect(parsed.containsKey('salt'), isTrue);
      expect(parsed.containsKey('keys'), isTrue);

      keystore.lock();
    });

    test('deserialize restores keystore', () async {
      final original = EncryptedKeystore();
      await original.unlock('password');
      await original.generateKey('deser-key');
      final json = original.serialize();
      original.lock();

      final restored = EncryptedKeystore.deserialize(json);
      expect(restored.hasKey('deser-key'), isTrue);
    });

    test('deserialize throws for unsupported version', () {
      final badJson = '{"version":99,"salt":"AAAA","keys":{}}';
      expect(() => EncryptedKeystore.deserialize(badJson), throwsFormatException);
    });
  });

  group('EncryptedKeystore Locked Operations', () {
    test('generateKey throws when locked', () {
      final keystore = EncryptedKeystore();
      expect(() => keystore.generateKey('test'), throwsA(isA<StateError>()));
    });

    test('getKey throws when locked', () {
      final keystore = EncryptedKeystore();
      expect(() => keystore.getKey('test'), throwsA(isA<StateError>()));
    });
  });
}
