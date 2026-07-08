import 'dart:typed_data';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:test/test.dart';

void main() {
  group('PeerId base36', () {
    test('toBase36 returns multibase-prefixed string', () {
      final pid = PeerId(value: Uint8List.fromList([0, 1, 2, 3, 255]));
      final encoded = pid.toBase36();
      expect(encoded.startsWith('k'), isTrue);
      expect(encoded.length, greaterThan(1));
    });

    test('fromBase36 round-trips', () {
      final original = PeerId(value: Uint8List.fromList([0xAB, 0xCD, 0xEF]));
      final encoded = original.toBase36();
      final decoded = PeerId.fromBase36(encoded);
      expect(decoded.value, orderedEquals(original.value));
    });

    test('fromBase36 accepts bare string without k prefix', () {
      final original = PeerId(value: Uint8List.fromList([0x01, 0x02]));
      final bare = original.toBase36().substring(1);
      final decoded = PeerId.fromBase36(bare);
      expect(decoded.value, orderedEquals(original.value));
    });

    test('fromBase36 rejects invalid characters', () {
      expect(() => PeerId.fromBase36('k!'), throwsArgumentError);
    });

    test('fromPublicKey Ed25519 derives deterministic PeerId', () {
      final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
      final pid1 = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
      final pid2 = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
      expect(pid1, equals(pid2));
      expect(pid1.value.length, equals(32));
    });

    test('fromPublicKey requires Ed25519 type and 32-byte key', () {
      expect(
        () => PeerId.fromPublicKey(Uint8List(32), type: 'secp256k1'),
        throwsUnsupportedError,
      );
      expect(
        () => PeerId.fromPublicKey(Uint8List(31), type: 'Ed25519'),
        throwsArgumentError,
      );
    });
  });

  group('PeerId PoW', () {
    test('verifyPoW should accept PeerId with enough leading zeros', () {
      // Find a PeerId that satisfies a 4-bit difficulty
      PeerId? found;
      for (int i = 0; i < 1000; i++) {
        final pid = PeerId(
          value: Uint8List.fromList([i & 0xFF, (i >> 8) & 0xFF]),
        );
        if (pid.verifyPoW(difficulty: 4)) {
          found = pid;
          break;
        }
      }

      expect(found, isNotNull);
      expect(found!.verifyPoW(difficulty: 4), isTrue);
    });

    test('verifyPoW should reject PeerId with insufficient leading zeros', () {
      // Find a PeerId that DOES NOT satisfy a 16-bit difficulty (statistically likely)
      final pid = PeerId(value: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
      expect(pid.verifyPoW(difficulty: 16), isFalse);
    });

    test('difficulty 0 should always pass', () {
      final pid = PeerId(value: Uint8List.fromList([0xFF]));
      expect(pid.verifyPoW(difficulty: 0), isTrue);
    });
  });
}
