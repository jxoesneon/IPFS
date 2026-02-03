import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/dag_json_handler.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('DAGJsonHandler', () {
    test('encodes and decodes NULL', () {
      final node = IPLDNode()..kind = Kind.NULL;
      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, equals('null'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.NULL));
    });

    test('encodes and decodes BOOL', () {
      final node = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true;
      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, equals('true'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.BOOL));
      expect(decoded.boolValue, isTrue);
    });

    test('encodes and decodes INTEGER', () {
      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(42);
      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, equals('42'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.INTEGER));
      expect(decoded.intValue, equals(Int64(42)));
    });

    test('encodes and decodes FLOAT', () {
      final node = IPLDNode()
        ..kind = Kind.FLOAT
        ..floatValue = 3.14;
      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, equals('3.14'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.FLOAT));
      expect(decoded.floatValue, closeTo(3.14, 0.001));
    });

    test('encodes and decodes STRING', () {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hello';
      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, equals('"hello"'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.STRING));
      expect(decoded.stringValue, equals('hello'));
    });

    test('encodes and decodes BYTES', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = bytes;

      final encoded = DAGJsonHandler.encode(node);
      // Expect {"/": {"bytes": "AQID"}}
      final jsonMap = json.decode(encoded);
      expect(jsonMap['/']['bytes'], equals(base64.encode(bytes)));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.BYTES));
      expect(decoded.bytesValue, equals(bytes));
    });

    test('encodes and decodes LINK (CID)', () {
      final cid = CID.decode(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
      ); // V0
      final node = IPLDNode()
        ..kind = Kind.LINK
        ..linkValue = (IPLDLink()
          ..version = cid.version
          ..codec = 'dag-pb'
          ..multihash = cid.multihash.toBytes());

      final encoded = DAGJsonHandler.encode(node);
      // Expect {"/": "cid-string"}
      // Note: V0 converted to V1 in code if codec provided?
      // Code: final cid = CID.v1(...)
      // So encoded string will be V1.

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.LINK));
      // Decoded link might be V1 CID
      final decodedCid = CID.fromBytes(
        Uint8List.fromList(decoded.linkValue.multihash),
      );
      // But we can check codec
      expect(decoded.linkValue.codec, equals('dag-pb'));
    });

    test('encodes and decodes LIST', () {
      final node = IPLDNode()
        ..kind = Kind.LIST
        ..listValue = (IPLDList()
          ..values.add(
            IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(1),
          )
          ..values.add(
            IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = 'a',
          ));

      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, contains('[1,"a"]'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.LIST));
      expect(decoded.listValue.values.length, equals(2));
      expect(decoded.listValue.values[0].intValue, equals(Int64(1)));
    });

    test('encodes and decodes MAP', () {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.add(
            MapEntry()
              ..key = 'foo'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'bar'),
          ));

      final encoded = DAGJsonHandler.encode(node);
      expect(encoded, contains('{"foo":"bar"}'));

      final decoded = DAGJsonHandler.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
      expect(decoded.mapValue.entries.first.key, equals('foo'));
      expect(decoded.mapValue.entries.first.value.stringValue, equals('bar'));
    });

    test(
      'handles map with slash key correctly (escape mechanism or literal)',
      () {
        // {"/": ...} is special.
        // What if we mean a literal map with key "/"?
        // _fromPlainObject logic:
        // if (obj.length == 1 && obj.containsKey('/')) -> treats as Link/Bytes.
        // Unless it doesn't match link/bytes structure?
        // Code:
        // if link is String -> Link.
        // if link is Map && has bytes -> Bytes.
        // else -> Literal map.

        // Let's test literal map with key "/" and value 123
        final jsonStr = '{"/": 123}';
        final decoded = DAGJsonHandler.decode(jsonStr);
        expect(decoded.kind, equals(Kind.MAP));
        expect(decoded.mapValue.entries.first.key, equals('/'));
        expect(
          decoded.mapValue.entries.first.value.intValue,
          equals(Int64(123)),
        );
      },
    );
  });
}

