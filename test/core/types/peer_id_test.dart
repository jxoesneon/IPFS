import 'dart:typed_data';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:test/test.dart';

void main() {
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

