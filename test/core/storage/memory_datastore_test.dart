import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';

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
  });
}
