import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';

class ValueFilter implements QueryFilter {
  final int expectedValue;
  ValueFilter(this.expectedValue);
  @override
  bool filter(MapEntry<Key, Uint8List> entry) {
    return entry.value[0] == expectedValue;
  }
}

class KeyOrder implements QueryOrder {
  @override
  int compare(MapEntry<Key, Uint8List> a, MapEntry<Key, Uint8List> b) {
    return a.key.toString().compareTo(b.key.toString());
  }
}

void main() {
  late MemoryDatastore ds;

  setUp(() {
    ds = MemoryDatastore();
  });

  group('MemoryDatastore', () {
    test('put and get', () async {
      final key = Key('/a/b');
      final val = Uint8List.fromList([1, 2]);
      await ds.put(key, val);

      expect(await ds.has(key), isTrue);
      expect(await ds.get(key), equals(val));
    });

    test('delete', () async {
      final key = Key('/a');
      await ds.put(key, Uint8List(0));
      await ds.delete(key);
      expect(await ds.has(key), isFalse);
    });

    test('query with prefix', () async {
      await ds.put(Key('/a/1'), Uint8List(1));
      await ds.put(Key('/a/2'), Uint8List(1));
      await ds.put(Key('/b/1'), Uint8List(1));

      final results = await ds.query(Query(prefix: '/a')).toList();
      expect(results.length, equals(2));
    });

    test('query with limit and offset', () async {
      await ds.put(Key('/1'), Uint8List(1));
      await ds.put(Key('/2'), Uint8List(1));
      await ds.put(Key('/3'), Uint8List(1));

      final results = await ds.query(Query(offset: 1, limit: 1)).toList();
      expect(results.length, equals(1));
    });

    test('close', () async {
      await ds.put(Key('/a'), Uint8List(0));
      await ds.close();
      expect(await ds.has(Key('/a')), isFalse);
    });

    test('init', () async {
      await ds.init();
      // Should not throw
    });

    test('query with keysOnly returns entries without values', () async {
      await ds.put(Key('/a/1'), Uint8List.fromList([1, 2]));
      await ds.put(Key('/a/2'), Uint8List.fromList([3, 4]));

      final results = await ds
          .query(Query(prefix: '/a', keysOnly: true))
          .toList();
      expect(results.length, equals(2));
      expect(results.first.value, isNull);
      expect(results.first.key, isNotNull);
    });

    test('query returns empty stream for no matches', () async {
      await ds.put(Key('/a/1'), Uint8List(1));

      final results = await ds.query(Query(prefix: '/b')).toList();
      expect(results, isEmpty);
    });

    test('get returns null for non-existent key', () async {
      final result = await ds.get(Key('/nonexistent'));
      expect(result, isNull);
    });

    test('has returns false for non-existent key', () async {
      final result = await ds.has(Key('/nonexistent'));
      expect(result, isFalse);
    });

    test('query with filters', () async {
      await ds.put(Key('/a/1'), Uint8List.fromList([1]));
      await ds.put(Key('/a/2'), Uint8List.fromList([2]));

      final filter = ValueFilter(1);
      final results = await ds
          .query(Query(prefix: '/a', filters: [filter]))
          .toList();
      expect(results.length, equals(1));
      expect(results.first.value![0], equals(1));
    });

    test('query with orders', () async {
      await ds.put(Key('/a/3'), Uint8List.fromList([3]));
      await ds.put(Key('/a/1'), Uint8List.fromList([1]));
      await ds.put(Key('/a/2'), Uint8List.fromList([2]));

      final order = KeyOrder();
      final results = await ds
          .query(Query(prefix: '/a', orders: [order]))
          .toList();
      expect(results.length, equals(3));
      expect(results[0].key.toString(), contains('/a/1'));
      expect(results[1].key.toString(), contains('/a/2'));
      expect(results[2].key.toString(), contains('/a/3'));
    });
  });
}
