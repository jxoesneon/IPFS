// Fuzz tests for the DAG-CBOR parser.
//
// These tests feed random, truncated, and corrupt byte sequences to
// [EnhancedCBORHandler.decodeDagCbor] and verify that the parser either
// produces a valid result or throws a known exception type — it must never
// crash, hang, or throw an unhandled error.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '_fuzz_helpers.dart';

void main() {
  group('CBOR fuzz', () {
    final rng = makeRandom();

    test('random byte sequences of various lengths do not crash', () {
      // 2000 iterations across lengths 1..10000.
      for (var i = 0; i < 2000; i++) {
        final length = 1 + rng.nextInt(10000);
        final data = randomBytes(rng, length);
        _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(data));
      }
    });

    test('empty input throws a known exception', () {
      _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(Uint8List(0)));
    });

    test('truncated valid CBOR sequences are handled gracefully', () {
      final validSequences = _generateValidCborSequences();
      for (final seq in validSequences) {
        for (var cut = 0; cut < seq.length; cut++) {
          final truncatedSeq = truncated(seq, cut);
          _expectGraceful(
            () => EnhancedCBORHandler.decodeDagCbor(truncatedSeq),
          );
        }
      }
    });

    test('CBOR with invalid major types is handled gracefully', () {
      // Major type 7 (simple/float) with unusual additional info values.
      final invalidMajor = <Uint8List>[
        // Simple value 16-23 reserved / unsupported in strict mode.
        Uint8List.fromList([0xf0]),
        Uint8List.fromList([0xf1]),
        Uint8List.fromList([0xf2]),
        Uint8List.fromList([0xf3]),
        // Break code outside indefinite context.
        Uint8List.fromList([0xff]),
        // Float16 / float32 not canonical in DAG-CBOR (additional 25/26).
        Uint8List.fromList([0xf9, 0x00, 0x00]),
        Uint8List.fromList([0xfa, 0x00, 0x00, 0x00, 0x00]),
      ];
      for (final data in invalidMajor) {
        _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(data));
      }
    });

    test('CBOR with extreme nesting depth is handled gracefully', () {
      // Build a deeply nested array: 0x9f is indefinite, but DAG-CBOR rejects
      // indefinite. Use definite arrays: 0x81 (array of 1) repeated.
      final depth = 2000;
      final builder = BytesBuilder();
      for (var i = 0; i < depth; i++) {
        builder.addByte(0x81); // array(1)
      }
      builder.addByte(0x00); // null value at the bottom
      final data = builder.toBytes();
      // With default options (maxDepth=64) this must throw, not crash.
      _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(data));
    });

    test('CBOR with invalid UTF-8 strings is handled gracefully', () {
      // A text string (major type 3) whose payload is invalid UTF-8.
      final invalidUtf8 = invalidUtf8Bytes(rng, 20);
      final builder = BytesBuilder();
      // text string of length 20: 0x74 = major 3, additional 20.
      builder.addByte(0x70 | invalidUtf8.length);
      builder.add(invalidUtf8);
      final data = builder.toBytes();
      _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(data));

      // Also test with larger invalid UTF-8 payloads.
      for (var i = 0; i < 100; i++) {
        final len = 1 + rng.nextInt(500);
        final payload = invalidUtf8Bytes(rng, len);
        final b = BytesBuilder();
        _encodeLengthPrefix(b, 3, len);
        b.add(payload);
        _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(b.toBytes()));
      }
    });

    test('random bytes with CBOR-like first byte do not crash', () {
      // Ensure every possible first-byte value is exercised with random tail.
      for (var firstByte = 0; firstByte < 256; firstByte++) {
        final tail = randomBytesRange(rng, 0, 200);
        final data = Uint8List.fromList([firstByte, ...tail]);
        _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(data));
      }
    });

    test('corrupted valid CBOR with flipped bytes is handled gracefully', () {
      final validSequences = _generateValidCborSequences();
      for (final seq in validSequences) {
        for (var trial = 0; trial < 50; trial++) {
          final corrupted = withFlippedBytes(rng, seq, 1 + rng.nextInt(3));
          _expectGraceful(() => EnhancedCBORHandler.decodeDagCbor(corrupted));
        }
      }
    });

    test('lenient mode handles random bytes without crashing', () {
      for (var i = 0; i < 500; i++) {
        final data = randomBytesRange(rng, 1, 5000);
        _expectGraceful(
          () => EnhancedCBORHandler.decodeDagCbor(data, strict: false),
        );
      }
    });
  });
}

/// Asserts that [action] either completes normally or throws a known,
/// expected exception type ([IPLDDecodingError], [FormatException],
/// [ArgumentError], or [StateError]). It must never throw an unexpected
/// exception or crash.
void _expectGraceful(void Function() action) {
  try {
    action();
  } on IPLDDecodingError {
    // Expected — invalid CBOR is rejected with a typed error.
  } on FormatException {
    // Expected — malformed input rejected.
  } on RangeError {
    // Expected — out-of-bounds rejected.
  } on ArgumentError {
    // Expected — invalid argument rejected.
  } on StateError {
    // Expected — bad state rejected.
  }
  // If no exception, the parser produced a valid result — also acceptable.
}

/// Generates a collection of valid DAG-CBOR byte sequences for truncation and
/// corruption tests.
List<Uint8List> _generateValidCborSequences() {
  final sequences = <Uint8List>[];

  // Integer.
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(42),
    ),
  );
  // String.
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hello world',
    ),
  );
  // Bytes.
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = List.filled(50, 0xAB),
    ),
  );
  // List.
  final list = IPLDList()
    ..values.addAll([
      IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(1),
      IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'two',
      IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true,
    ]);
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.LIST
        ..listValue = list,
    ),
  );
  // Map.
  final map = IPLDMap()
    ..entries.addAll([
      MapEntry()
        ..key = 'a'
        ..value = (IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = Int64(1)),
      MapEntry()
        ..key = 'bb'
        ..value = (IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'val'),
    ]);
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = map,
    ),
  );
  // Nested map inside list.
  final innerMap = IPLDMap()
    ..entries.add(
      MapEntry()
        ..key = 'x'
        ..value = (IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = Int64(99)),
    );
  final nestedList = IPLDList()
    ..values.add(
      IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = innerMap,
    );
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.LIST
        ..listValue = nestedList,
    ),
  );
  // Large byte string.
  sequences.add(
    EnhancedCBORHandler.encodeDagCbor(
      IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = List.filled(1000, 0x00),
    ),
  );

  return sequences;
}

/// Encodes a CBOR length prefix for [majorType] and [length] into [builder].
void _encodeLengthPrefix(BytesBuilder builder, int majorType, int length) {
  final majorShifted = majorType << 5;
  if (length < 24) {
    builder.addByte(majorShifted | length);
  } else if (length < 256) {
    builder.addByte(majorShifted | 24);
    builder.addByte(length);
  } else if (length < 65536) {
    builder.addByte(majorShifted | 25);
    builder.addByte((length >> 8) & 0xFF);
    builder.addByte(length & 0xFF);
  } else {
    builder.addByte(majorShifted | 26);
    builder.addByte((length >> 24) & 0xFF);
    builder.addByte((length >> 16) & 0xFF);
    builder.addByte((length >> 8) & 0xFF);
    builder.addByte(length & 0xFF);
  }
}
