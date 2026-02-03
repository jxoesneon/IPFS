import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' hide KeyPair;
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:test/test.dart';

void main() {
  group('Keystore', () {
    late Keystore keystore;

    setUp(() {
      keystore = Keystore();
    });

    test('add and get key pair', () {
      final pair = KeyPair('pub', 'priv');
      keystore.addKeyPair('test', pair);

      expect(keystore.hasKeyPair('test'), isTrue);
      final retrieved = keystore.getKeyPair('test');
      expect(retrieved.publicKey, equals('pub'));
      expect(retrieved.privateKey, equals('priv'));
    });

    test('getKeyPair throws if not found', () {
      expect(() => keystore.getKeyPair('missing'), throwsArgumentError);
    });

    test('remove key pair', () {
      keystore.addKeyPair('test', KeyPair('pub', 'priv'));
      keystore.removeKeyPair('test');
      expect(keystore.hasKeyPair('test'), isFalse);
    });

    test('remove non-existent key pair (warning path)', () {
      // Should not throw, just log warning
      keystore.removeKeyPair('missing');
    });

    test('listKeyPairs', () {
      keystore.addKeyPair('k1', KeyPair('p1', 's1'));
      keystore.addKeyPair('k2', KeyPair('p2', 's2'));

      final list = keystore.listKeyPairs();
      expect(list, containsAll(['k1', 'k2']));
      expect(list.length, equals(2));
    });

    test('serialize and deserialize', () {
      keystore.addKeyPair('k1', KeyPair('p1', 's1'));
      final serialized = keystore.serialize();

      final keystore2 = Keystore();
      keystore2.deserialize(serialized);

      expect(keystore2.hasKeyPair('k1'), isTrue);
      final pair = keystore2.getKeyPair('k1');
      expect(pair.publicKey, equals('p1'));
      expect(pair.privateKey, equals('s1'));
    });

    test('withConfig named constructor', () {
      final ks = Keystore.withConfig({});
      expect(ks, isNotNull);
    });

    test('privateKey getter (defaultKeyName)', () {
      // Should throw if 'self' is missing
      expect(() => keystore.privateKey, throwsStateError);

      // Add 'self'
      // Note: fromString expects base64Url or similar typically,
      // but Keystore's privateKey getter uses IPFSPrivateKey.fromString.
      // Let's use a dummy base64 string that will likely pass minimal fromString checks
      // or at least test the getter logic.
      final dummyPriv = base64Url.encode(Uint8List(32));
      keystore.addKeyPair(Keystore.defaultKeyName, KeyPair('pub', dummyPriv));

      final pk = keystore.privateKey;
      expect(pk, isNotNull);
    });

    test('verifySignature - simple hex pubkey', () async {
      // Ed25519 hex key (32 bytes = 64 hex chars)
      final seed = Uint8List(32); // All zeros
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(seed);
      final pubKey = await keyPair.extractPublicKey();
      final pubHex = pubKey.bytes
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join();

      final data = Uint8List.fromList(utf8.encode('hello'));
      final signature = await algorithm.sign(data, keyPair: keyPair);

      final isValid = await keystore.verifySignature(
        pubHex,
        data,
        Uint8List.fromList(signature.bytes),
      );
      expect(isValid, isTrue);
    });

    test('verifySignature - base64 pubkey', () async {
      final seed = Uint8List(32)..fillRange(0, 32, 1);
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(seed);
      final pubKey = await keyPair.extractPublicKey();
      final pubBase64 = base64Encode(pubKey.bytes);

      final data = Uint8List.fromList(utf8.encode('world'));
      final signature = await algorithm.sign(data, keyPair: keyPair);

      final isValid = await keystore.verifySignature(
        pubBase64,
        data,
        Uint8List.fromList(signature.bytes),
      );
      expect(isValid, isTrue);
    });

    test('verifySignature - raw string fallback', () async {
      // This is a weird path in the code: return Uint8List.fromList(utf8.encode(publicKey))
      // It won't actually result in a valid Ed25519 public key unless the string IS exactly 32 bytes of raw data.
      // But we can test that it doesn't crash.
      final isValid = await keystore.verifySignature(
        'too-short',
        Uint8List(0),
        Uint8List(64),
      );
      expect(isValid, isFalse);
    });

    test('exportKeysForMigration and clearAfterMigration', () {
      final priv1 = base64Url.encode(Uint8List.fromList([1, 2, 3]));
      final priv2 = 'legacy-raw-string';

      keystore.addKeyPair('k1', KeyPair('p1', priv1));
      keystore.addKeyPair('k2', KeyPair('p2', priv2));

      final exported = keystore.exportKeysForMigration();
      expect(exported['k1'], equals(Uint8List.fromList([1, 2, 3])));
      expect(exported['k2'], equals(Uint8List.fromList(utf8.encode(priv2))));

      keystore.clearAfterMigration();
      expect(keystore.listKeyPairs(), isEmpty);
    });
  });
}

