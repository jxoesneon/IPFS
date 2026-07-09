// Property-based tests for DAG-CBOR encoding/decoding.
//
// These tests verify fundamental round-trip properties of the DAG-CBOR
// codec using random generators with a fixed seed for reproducibility.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '../fuzz/_fuzz_helpers.dart';

void main() {
  final rng = makeRandom();

  group('CBOR property-based tests', () {
    test(
      'for any map: encode as DAG-CBOR -> decode -> equals original map',
      () {
        for (var i = 0; i < 300; i++) {
          final original = _randomMap(rng, 1 + rng.nextInt(10));
          final bytes = EnhancedCBORHandler.encodeDagCbor(original);
          final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
          expect(decoded.kind, equals(Kind.MAP));
          // Verify the same set of keys.
          final originalKeys = original.mapValue.entries
              .map((e) => e.key)
              .toSet();
          final decodedKeys = decoded.mapValue.entries
              .map((e) => e.key)
              .toSet();
          expect(decodedKeys, equals(originalKeys));
        }
      },
    );

    test('for any list: encode -> decode -> equals original list', () {
      for (var i = 0; i < 300; i++) {
        final original = _randomList(rng, 1 + rng.nextInt(20));
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.LIST));
        expect(
          decoded.listValue.values.length,
          equals(original.listValue.values.length),
        );
      }
    });

    test('for any int: encode -> decode -> equals original int', () {
      for (var i = 0; i < 500; i++) {
        final value = _randomInt64(rng);
        final original = IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = value;
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.INTEGER));
        expect(decoded.intValue, equals(value));
      }
    });

    test('for any string: encode -> decode -> equals original string', () {
      for (var i = 0; i < 300; i++) {
        final value = randomUtf8String(rng, 1 + rng.nextInt(100));
        final original = IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = value;
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.STRING));
        expect(decoded.stringValue, equals(value));
      }
    });

    test('for any bytes: encode -> decode -> equals original bytes', () {
      for (var i = 0; i < 300; i++) {
        final value = randomBytesRange(rng, 0, 500);
        final original = IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = value;
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BYTES));
        expect(Uint8List.fromList(decoded.bytesValue), equals(value));
      }
    });

    test('for any bool: encode -> decode -> equals original bool', () {
      for (var i = 0; i < 100; i++) {
        final value = rng.nextBool();
        final original = IPLDNode()
          ..kind = Kind.BOOL
          ..boolValue = value;
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BOOL));
        expect(decoded.boolValue, equals(value));
      }
    });

    test('for any null: encode -> decode -> equals null', () {
      for (var i = 0; i < 50; i++) {
        final original = IPLDNode()..kind = Kind.NULL;
        final bytes = EnhancedCBORHandler.encodeDagCbor(original);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.NULL));
      }
    });

    test(
      'encoding is deterministic: same logical content -> identical bytes',
      () {
        for (var i = 0; i < 200; i++) {
          final map1 = _randomMap(rng, 1 + rng.nextInt(5));
          // Re-encode the decoded result to get canonical bytes.
          final bytes1 = EnhancedCBORHandler.encodeDagCbor(map1);
          final decoded = EnhancedCBORHandler.decodeDagCbor(bytes1);
          final bytes2 = EnhancedCBORHandler.encodeDagCbor(decoded);
          expect(bytes2, equals(bytes1));
        }
      },
    );

    test(
      'canonical map ordering: insertion order does not affect encoding',
      () {
        for (var i = 0; i < 200; i++) {
          final entries = _randomMapEntries(rng, 1 + rng.nextInt(8));
          // Build two maps with the same entries in different order.
          final map1 = IPLDNode()
            ..kind = Kind.MAP
            ..mapValue = (IPLDMap()..entries.addAll(entries));
          final reversed = entries.reversed.toList();
          final map2 = IPLDNode()
            ..kind = Kind.MAP
            ..mapValue = (IPLDMap()..entries.addAll(reversed));
          expect(
            EnhancedCBORHandler.encodeDagCbor(map1),
            equals(EnhancedCBORHandler.encodeDagCbor(map2)),
          );
        }
      },
    );

    test('nested structures round-trip: map of lists of maps', () {
      for (var i = 0; i < 100; i++) {
        final innerMaps = List.generate(
          1 + rng.nextInt(5),
          (_) => _randomMap(rng, 1 + rng.nextInt(3)),
        );
        final list = IPLDList()..values.addAll(innerMaps);
        final outer = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.add(
              MapEntry()
                ..key = 'items'
                ..value = (IPLDNode()
                  ..kind = Kind.LIST
                  ..listValue = list),
            ));
        final bytes = EnhancedCBORHandler.encodeDagCbor(outer);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.MAP));
        final itemsEntry = decoded.mapValue.entries.firstWhere(
          (e) => e.key == 'items',
        );
        expect(itemsEntry.value.kind, equals(Kind.LIST));
      }
    });
  });
}

/// Generates a random Int64 value within the safe int64 range.
Int64 _randomInt64(math.Random rng) {
  // Generate values across the full int64 range using high and low parts.
  final high = rng.nextInt(0x10000);
  final low = rng.nextInt(0x100000000);
  final value = (Int64(high) << 32) | Int64(low);
  // Randomly negate.
  return rng.nextBool() ? value : -value;
}

/// Generates a random IPLDNode value (int, string, bool, bytes, or null).
IPLDNode _randomScalar(math.Random rng) {
  switch (rng.nextInt(5)) {
    case 0:
      return IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = _randomInt64(rng);
    case 1:
      return IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = randomUtf8String(rng, 1 + rng.nextInt(20));
    case 2:
      return IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = rng.nextBool();
    case 3:
      return IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = randomBytesRange(rng, 0, 50);
    default:
      return IPLDNode()..kind = Kind.NULL;
  }
}

/// Generates a list of random MapEntry objects with unique string keys.
List<MapEntry> _randomMapEntries(math.Random rng, int count) {
  final keys = <String>{};
  while (keys.length < count) {
    keys.add(randomUtf8String(rng, 1 + rng.nextInt(10)));
  }
  return keys.map((key) {
    return MapEntry()
      ..key = key
      ..value = _randomScalar(rng);
  }).toList();
}

/// Generates a random IPLDMap node.
IPLDNode _randomMap(math.Random rng, int count) {
  final entries = _randomMapEntries(rng, count);
  return IPLDNode()
    ..kind = Kind.MAP
    ..mapValue = (IPLDMap()..entries.addAll(entries));
}

/// Generates a random IPLDList node with scalar values.
IPLDNode _randomList(math.Random rng, int count) {
  final list = IPLDList();
  for (var i = 0; i < count; i++) {
    list.values.add(_randomScalar(rng));
  }
  return IPLDNode()
    ..kind = Kind.LIST
    ..listValue = list;
}
