import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('RawCodec', () {
    final codec = RawCodec();

    test('identifier is "raw"', () {
      expect(codec.identifier, equals('raw'));
    });

    test('encode returns the bytes payload', () async {
      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3, 4];
      final encoded = await codec.encode(node);
      expect(encoded, equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('encode rejects non-bytes nodes', () async {
      final node = IPLDNode()..kind = Kind.STRING;
      expect(() => codec.encode(node), throwsArgumentError);
    });

    test('decode produces a BYTES node', () async {
      final node = await codec.decode(Uint8List.fromList([7, 8, 9]));
      expect(node.kind, equals(Kind.BYTES));
      expect(node.bytesValue, equals([7, 8, 9]));
    });
  });

  group('DagJsonCodec', () {
    final codec = DagJsonCodec();

    test('identifier is "dag-json"', () {
      expect(codec.identifier, equals('dag-json'));
    });

    test('encode/decode round-trips a string node', () async {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hello';
      final encoded = await codec.encode(node);
      // Encoded bytes are valid UTF-8 JSON.
      expect(() => utf8.decode(encoded), returnsNormally);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.STRING));
      expect(decoded.stringValue, equals('hello'));
    });

    test('encode/decode round-trips a map node', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry(
          key: 'key',
          value: IPLDNode()
            ..kind = Kind.STRING
            ..stringValue = 'value',
        ),
      );
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
    });

    test('encode/decode round-trips a list node', () async {
      final node = IPLDNode()
        ..kind = Kind.LIST
        ..listValue = IPLDList();
      node.listValue.values.add(
        IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'item1',
      );
      node.listValue.values.add(
        IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'item2',
      );
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.LIST));
    });

    test('encode/decode round-trips a bool node', () async {
      final node = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true;
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.BOOL));
      expect(decoded.boolValue, isTrue);
    });

    test('encode/decode round-trips null', () async {
      final node = IPLDNode()..kind = Kind.NULL;
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.NULL));
    });

    test('encode/decode round-trips int', () async {
      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(42);
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.INTEGER));
      expect(decoded.intValue.toInt(), equals(42));
    });

    test('encode/decode round-trips bytes', () async {
      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3];
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.BYTES));
      expect(decoded.bytesValue, equals([1, 2, 3]));
    });
  });

  group('DagPbCodec', () {
    final codec = DagPbCodec();

    test('identifier is "dag-pb"', () {
      expect(codec.identifier, equals('dag-pb'));
    });

    test('encode rejects non-map nodes', () async {
      final node = IPLDNode()..kind = Kind.STRING;
      expect(() => codec.encode(node), throwsArgumentError);
    });

    test('encode with valid map node', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Data'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = [1, 2, 3]),
      );
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Links'
          ..value = (IPLDNode()
            ..kind = Kind.LIST
            ..listValue = IPLDList()),
      );

      final encoded = await codec.encode(node);
      expect(encoded, isNotNull);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('decode produces node', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Data'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = [1, 2, 3]),
      );
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Links'
          ..value = (IPLDNode()
            ..kind = Kind.LIST
            ..listValue = IPLDList()),
      );

      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded.kind, Kind.MAP);
    });

    test('encode handles missing Data field', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Links'
          ..value = (IPLDNode()
            ..kind = Kind.LIST
            ..listValue = IPLDList()),
      );

      final encoded = await codec.encode(node);
      expect(encoded, isNotNull);
    });

    test('encode handles missing Links field', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Data'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = [1, 2, 3]),
      );

      final encoded = await codec.encode(node);
      expect(encoded, isNotNull);
    });

    test('encode throws on invalid link format', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Data'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = [1, 2, 3]),
      );
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'Links'
          ..value = (IPLDNode()
            ..kind = Kind.LIST
            ..listValue = IPLDList()),
      );
      // Add a non-map link
      node.mapValue.entries[1].value.listValue.values.add(
        IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'invalid',
      );

      expect(() => codec.encode(node), throwsArgumentError);
    });
  });

  group('DagCborCodec', () {
    final codec = DagCborCodec();

    test('identifier is "dag-cbor"', () {
      expect(codec.identifier, equals('dag-cbor'));
    });

    test('encode produces bytes', () async {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';
      final encoded = await codec.encode(node);
      expect(encoded, isNotNull);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('decode produces node', () async {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded, isNotNull);
    });

    test('encode/decode round-trips string', () async {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hello world';
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.STRING));
      expect(decoded.stringValue, equals('hello world'));
    });

    test('encode/decode round-trips int', () async {
      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(42);
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.INTEGER));
      expect(decoded.intValue.toInt(), equals(42));
    });

    test('encode/decode round-trips map', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'key'
          ..value = (IPLDNode()
            ..kind = Kind.STRING
            ..stringValue = 'value'),
      );
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
    });

    test('encode/decode round-trips list', () async {
      final node = IPLDNode()
        ..kind = Kind.LIST
        ..listValue = IPLDList();
      node.listValue.values.add(
        IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'item1',
      );
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.LIST));
    });

    test('encode/decode round-trips bool', () async {
      final node = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true;
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.BOOL));
      expect(decoded.boolValue, isTrue);
    });

    test('encode/decode round-trips bytes', () async {
      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3];
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.BYTES));
      expect(decoded.bytesValue, equals([1, 2, 3]));
    });

    test('encode/decode round-trips null', () async {
      final node = IPLDNode()..kind = Kind.NULL;
      final encoded = await codec.encode(node);
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.NULL));
    });
  });
}
