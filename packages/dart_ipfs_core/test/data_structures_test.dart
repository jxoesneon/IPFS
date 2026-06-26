import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('ImmutableBytes', () {
    test('value-based equality', () {
      final a = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      final b = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      final c = ImmutableBytes(Uint8List.fromList([1, 2, 4]));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('returns defensive copy', () {
      final original = Uint8List.fromList([1, 2, 3]);
      final immutable = ImmutableBytes(original);
      original[0] = 99;
      expect(immutable.toBytes(), equals(Uint8List.fromList([1, 2, 3])));
    });
  });

  group('TypedMap', () {
    test('gets typed values with defaults', () {
      final map = TypedMap({'count': 5, 'name': 'test'});
      expect(map.get<int>('count', 0), equals(5));
      expect(map.get<String>('missing', 'default'), equals('default'));
      expect(map.get<String>('name', ''), equals('test'));
    });

    test('contains key and length', () {
      final map = TypedMap({'a': 1, 'b': 2});
      expect(map.containsKey('a'), isTrue);
      expect(map.containsKey('c'), isFalse);
      expect(map.length, equals(2));
    });
  });
}
