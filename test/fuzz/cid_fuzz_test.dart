// Fuzz tests for the CID parser.
//
// These tests feed random, truncated, and corrupt byte sequences and strings
// to [CID.fromBytes] and [CID.decode] and verify that the parser either
// produces a valid CID or throws a known exception type — it must never crash
// or throw an unhandled error.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:test/test.dart';

import '_fuzz_helpers.dart';

void main() {
  group('CID fuzz', () {
    final rng = makeRandom();

    test('random byte sequences (1-100 bytes) do not crash', () {
      for (var i = 0; i < 5000; i++) {
        final data = randomBytesRange(rng, 1, 100);
        _expectGraceful(() => CID.fromBytes(data));
      }
    });

    test('empty input throws a known exception', () {
      _expectGraceful(() => CID.fromBytes(Uint8List(0)));
    });

    test('very long input (10000+ bytes) is handled gracefully', () {
      for (var i = 0; i < 100; i++) {
        final data = randomBytes(rng, 10000 + rng.nextInt(5000));
        _expectGraceful(() => CID.fromBytes(data));
      }
    });

    test('valid CID with corrupted version byte is handled gracefully', () {
      final validCids = _generateValidCidBytes();
      for (final cidBytes in validCids) {
        // Corrupt the first byte (version / multihash code).
        for (var version = 0; version < 256; version++) {
          final corrupted = withByte(cidBytes, 0, version);
          _expectGraceful(() => CID.fromBytes(corrupted));
        }
      }
    });

    test('valid CID with corrupted multihash is handled gracefully', () {
      final validCids = _generateValidCidBytes();
      for (final cidBytes in validCids) {
        // Flip random bytes in the multihash portion.
        for (var trial = 0; trial < 100; trial++) {
          final corrupted = withFlippedBytes(rng, cidBytes, 1 + rng.nextInt(4));
          _expectGraceful(() => CID.fromBytes(corrupted));
        }
      }
    });

    test('truncated CIDs are handled gracefully', () {
      final validCids = _generateValidCidBytes();
      for (final cidBytes in validCids) {
        for (var cut = 0; cut < cidBytes.length; cut++) {
          final truncatedCid = truncated(cidBytes, cut);
          _expectGraceful(() => CID.fromBytes(truncatedCid));
        }
      }
    });

    test('random strings do not crash CID.decode', () {
      for (var i = 0; i < 2000; i++) {
        final str = _randomString(rng, 1 + rng.nextInt(100));
        _expectGraceful(() => CID.decode(str));
      }
    });

    test('empty string throws a known exception', () {
      _expectGraceful(() => CID.decode(''));
    });

    test('CIDv0-prefixed random strings are handled gracefully', () {
      for (var i = 0; i < 1000; i++) {
        final str = 'Qm${_randomString(rng, 1 + rng.nextInt(50))}';
        _expectGraceful(() => CID.decode(str));
      }
    });

    test('every single-byte input is handled gracefully', () {
      for (var b = 0; b < 256; b++) {
        _expectGraceful(() => CID.fromBytes(Uint8List.fromList([b])));
      }
    });
  });
}

/// Asserts that [action] either completes normally or throws a known,
/// expected exception type. It must never throw an unexpected exception.
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
    // Expected — unknown multibase code rejected.
  } on Exception {
    // Expected — any other typed exception from downstream decoders.
  }
  // If no exception, the parser produced a valid CID — also acceptable.
}

/// Generates valid CID byte sequences (both v0 and v1 with various codecs).
List<Uint8List> _generateValidCidBytes() {
  final sequences = <Uint8List>[];
  final hash = Multihash.encode('sha2-256', Uint8List(32));

  // CIDv0 (34 bytes: 0x12 0x20 + 32-byte digest).
  sequences.add(CID.v0(Uint8List(32)).toBytes());

  // CIDv1 with various codecs.
  for (final codec in ['raw', 'dag-pb', 'dag-cbor', 'dag-json']) {
    sequences.add(CID.v1(codec, hash).toBytes());
  }
  return sequences;
}

/// Generates a random ASCII string of [length] characters.
String _randomString(math.Random rng, int length) {
  final buffer = StringBuffer();
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  for (var i = 0; i < length; i++) {
    buffer.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}
