// Fuzz tests for the multihash parser.
//
// These tests feed random, truncated, and corrupt byte sequences to
// [Multihash.decode] and verify that the parser either produces a valid
// multihash or throws a known exception type — it must never crash.
import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';
import 'package:test/test.dart';

import '_fuzz_helpers.dart';

void main() {
  group('Multihash fuzz', () {
    final rng = makeRandom();

    test('random bytes do not crash Multihash.decode', () {
      for (var i = 0; i < 5000; i++) {
        final data = randomBytesRange(rng, 1, 200);
        _expectGraceful(() => Multihash.decode(data));
      }
    });

    test('empty input throws a known exception', () {
      _expectGraceful(() => Multihash.decode(Uint8List(0)));
    });

    test('valid multihash with corrupted hash function code', () {
      final validHashes = _generateValidMultihashes();
      for (final mhBytes in validHashes) {
        // Corrupt the hash function code (first byte / varint).
        for (var code = 0; code < 256; code++) {
          final corrupted = withByte(mhBytes, 0, code);
          _expectGraceful(() => Multihash.decode(corrupted));
        }
      }
    });

    test('valid multihash with corrupted length field', () {
      final validHashes = _generateValidMultihashes();
      for (final mhBytes in validHashes) {
        // Corrupt the length field (second byte for sha2-256).
        for (var len = 0; len < 256; len++) {
          final corrupted = withByte(mhBytes, 1, len);
          _expectGraceful(() => Multihash.decode(corrupted));
        }
      }
    });

    test('truncated multihashes are handled gracefully', () {
      final validHashes = _generateValidMultihashes();
      for (final mhBytes in validHashes) {
        for (var cut = 0; cut < mhBytes.length; cut++) {
          final truncatedMh = truncated(mhBytes, cut);
          _expectGraceful(() => Multihash.decode(truncatedMh));
        }
      }
    });

    test('multihash with extreme length field is handled gracefully', () {
      // Code 0x12 (sha2-256) with length 255 but only 32 bytes of digest.
      final data = Uint8List.fromList([0x12, 0xFF, ...List.filled(32, 0)]);
      _expectGraceful(() => Multihash.decode(data));

      // Code 0x12 with length 0.
      final empty = Uint8List.fromList([0x12, 0x00]);
      _expectGraceful(() => Multihash.decode(empty));
    });

    test('every single-byte and two-byte input is handled gracefully', () {
      for (var b = 0; b < 256; b++) {
        _expectGraceful(() => Multihash.decode(Uint8List.fromList([b])));
        for (var b2 = 0; b2 < 256; b2++) {
          _expectGraceful(() => Multihash.decode(Uint8List.fromList([b, b2])));
        }
      }
    });

    test('corrupted valid multihash with flipped bytes', () {
      final validHashes = _generateValidMultihashes();
      for (final mhBytes in validHashes) {
        for (var trial = 0; trial < 100; trial++) {
          final corrupted = withFlippedBytes(rng, mhBytes, 1 + rng.nextInt(4));
          _expectGraceful(() => Multihash.decode(corrupted));
        }
      }
    });
  });
}

/// Asserts that [action] either completes normally or throws a known,
/// expected exception type.
void _expectGraceful(void Function() action) {
  try {
    action();
  } on FormatException {
    // Expected — malformed input rejected.
  } on RangeError {
    // Expected — out-of-bounds rejected.
  } on ArgumentError {
    // Expected — invalid argument rejected.
  } on StateError {
    // Expected — bad state rejected.
  } on UnsupportedError {
    // Expected — unknown hash function code rejected.
  } on Exception {
    // Expected — any typed exception from the decoder.
  }
}

/// Generates valid multihash byte sequences.
List<Uint8List> _generateValidMultihashes() {
  final sequences = <Uint8List>[];
  // sha2-256: 0x12 0x20 + 32-byte digest.
  sequences.add(Multihash.encode('sha2-256', Uint8List(32)).toBytes());
  // sha2-256 with non-zero digest.
  final digest = Uint8List.fromList(List.generate(32, (i) => i));
  sequences.add(Multihash.encode('sha2-256', digest).toBytes());
  return sequences;
}
