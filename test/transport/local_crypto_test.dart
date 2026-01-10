import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/transport/local_crypto.dart';
import 'package:p2plib/p2plib.dart' as p2p;

void main() {
  group('LocalCrypto', () {
    late LocalCrypto crypto;

    setUp(() {
      crypto = LocalCrypto();
    });

    test('init generates keys with random seed if none provided', () async {
      final result = await crypto.init();

      expect(result.seed, isNotNull);
      expect(result.seed.length, 32);
      expect(result.signPubKey, isNotNull);
      expect(result.signPubKey.length, 32);
      expect(result.encPubKey, equals(result.signPubKey)); // Current implementation behavior
    });

    test('init generates deterministic keys with provided seed', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));

      final result1 = await crypto.init(seed);
      final pubKey1 = result1.signPubKey;

      // Re-init new instance with same seed
      final crypto2 = LocalCrypto();
      final result2 = await crypto2.init(seed);
      final pubKey2 = result2.signPubKey;

      expect(result1.seed, equals(seed));
      expect(pubKey1, equals(pubKey2));
    });

    test('seal returns data unchanged (pass-through)', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final sealed = await crypto.seal(data);

      expect(sealed, equals(data));
    });

    test('unseal returns sublist excluding header size', () async {
      // Simulate p2plib usage where it strips header?
      // The code says: return data.sublist(p2p.Message.headerLength);
      // Let's check headerLength
      final headerLength = p2p.Message.headerLength;

      final payload = [10, 11, 12];
      final data = Uint8List.fromList([
        ...List.filled(headerLength, 0), // Header
        ...payload,
      ]);

      final unsealed = await crypto.unseal(data);
      expect(unsealed, equals(payload));
    });

    test('unseal returns data if shorter than header', () async {
      final data = Uint8List.fromList([1, 2]); // Shorter than header
      final unsealed = await crypto.unseal(data);

      expect(unsealed, equals(data));
    });

    test('verify returns data unchanged', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final verified = await crypto.verify(data);

      expect(verified, equals(data));
    });

    test('publicKeyBytes returns null before init', () async {
      final key = await crypto.publicKeyBytes;
      expect(key, isNull);
    });

    test('publicKeyBytes returns key after init', () async {
      await crypto.init();
      final key = await crypto.publicKeyBytes;
      expect(key, isNotNull);
    });
  });
}
