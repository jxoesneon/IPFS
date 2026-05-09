@TestOn("vm")
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('HiveDatastore', () {
    late Directory tempDir;
    late HiveDatastore datastore;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_ds_');
      datastore = HiveDatastore(tempDir.path);
      await datastore.init();
    });

    tearDown(() async {
      await datastore.close();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('throws StateError when used before init', () async {
      final fresh = HiveDatastore(
        Directory.systemTemp.createTempSync('hive_ds2_').path,
      );
      expect(() => fresh.put(Key('/x'), Uint8List(0)), throwsStateError);
    });

    test('init is idempotent', () async {
      // Calling init again must not throw or reopen boxes.
      await datastore.init();
    });

    test('put/get/has/delete round-trips for blocks prefix', () async {
      final key = Key('/blocks/abc');
      final value = Uint8List.fromList([1, 2, 3]);

      expect(await datastore.has(key), isFalse);
      await datastore.put(key, value);
      expect(await datastore.has(key), isTrue);
      expect(await datastore.get(key), equals(value));
      await datastore.delete(key);
      expect(await datastore.has(key), isFalse);
      expect(await datastore.get(key), isNull);
    });

    test('routes pins/dht/default prefixes into separate boxes', () async {
      await datastore.put(Key('/pins/p1'), Uint8List.fromList([1]));
      await datastore.put(Key('/dht/d1'), Uint8List.fromList([2]));
      await datastore.put(Key('/other/o1'), Uint8List.fromList([3]));

      expect(await datastore.get(Key('/pins/p1')), equals([1]));
      expect(await datastore.get(Key('/dht/d1')), equals([2]));
      expect(await datastore.get(Key('/other/o1')), equals([3]));
    });

    test('query without prefix iterates all boxes', () async {
      await datastore.put(Key('/blocks/b'), Uint8List.fromList([10]));
      await datastore.put(Key('/pins/p'), Uint8List.fromList([20]));
      await datastore.put(Key('/dht/d'), Uint8List.fromList([30]));

      final entries = await datastore.query(Query()).toList();
      expect(entries.length, greaterThanOrEqualTo(3));
    });

    test('query with prefix filters to its target box', () async {
      await datastore.put(Key('/blocks/b1'), Uint8List.fromList([1]));
      await datastore.put(Key('/blocks/b2'), Uint8List.fromList([2]));
      await datastore.put(Key('/pins/p1'), Uint8List.fromList([3]));

      final entries = await datastore.query(Query(prefix: '/blocks/')).toList();
      expect(entries.length, equals(2));
      expect(
        entries.every((e) => e.key.toString().startsWith('/blocks/')),
        isTrue,
      );
    });

    test('query keysOnly skips loading values', () async {
      await datastore.put(Key('/blocks/b1'), Uint8List.fromList([1]));
      final entries = await datastore
          .query(Query(prefix: '/blocks/', keysOnly: true))
          .toList();
      expect(entries.single.value, isNull);
    });

    test('query honours custom filters', () async {
      await datastore.put(Key('/blocks/short'), Uint8List.fromList([1]));
      await datastore.put(
        Key('/blocks/long'),
        Uint8List.fromList([1, 2, 3, 4]),
      );

      final entries = await datastore
          .query(Query(prefix: '/blocks/', filters: [_MinLengthFilter(4)]))
          .toList();
      expect(entries, hasLength(1));
    });
  });
}

class _MinLengthFilter implements QueryFilter {
  _MinLengthFilter(this.minLength);
  final int minLength;
  @override
  bool filter(MapEntry<Key, Uint8List> entry) =>
      entry.value.length >= minLength;
}
