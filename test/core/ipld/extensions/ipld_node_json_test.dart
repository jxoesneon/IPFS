import 'dart:convert';

import 'package:dart_ipfs/src/core/ipld/extensions/ipld_node_json.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDNode JSON extension', () {
    test('NULL kind serialises to null', () {
      final node = IPLDNode()..kind = Kind.NULL;
      expect(node.toObject(), isNull);
      expect(node.toJson(), 'null');
    });

    test('BOOL kind serialises to bool', () {
      final node = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true;
      expect(node.toObject(), isTrue);
    });

    test('INTEGER kind serialises to int', () {
      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(42);
      expect(node.toObject(), equals(42));
    });

    test('FLOAT kind serialises to double', () {
      final node = IPLDNode()
        ..kind = Kind.FLOAT
        ..floatValue = 1.5;
      expect(node.toObject(), equals(1.5));
    });

    test('STRING kind serialises to string', () {
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hi';
      expect(node.toObject(), equals('hi'));
    });

    test('BYTES kind serialises to base64-wrapped link map', () {
      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3];
      final obj = node.toObject() as Map;
      expect(obj['/'], equals(base64Encode([1, 2, 3])));
    });

    test('LIST kind serialises children recursively', () {
      final inner = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'x';
      final list = IPLDList()..values.add(inner);
      final node = IPLDNode()
        ..kind = Kind.LIST
        ..listValue = list;
      expect(node.toObject(), equals(['x']));
    });

    test('MAP kind serialises into Dart map', () {
      final inner = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'v';
      final map = IPLDMap()
        ..entries.add(
          MapEntry()
            ..key = 'k'
            ..value = inner,
        );
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = map;
      expect(node.toObject(), equals({'k': 'v'}));
    });

    test('BIG_INT kind serialises as string of bytes', () {
      final node = IPLDNode()
        ..kind = Kind.BIG_INT
        ..bigIntValue = [1, 2, 3];
      // bigIntValue is stored as bytes; toObject calls toString on the list.
      expect(node.toObject(), isA<String>());
    });
  });
}
