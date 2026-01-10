// test/mocks/in_memory_datastore_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:test/test.dart';

import 'in_memory_datastore.dart';
import 'test_helpers.dart';

void main() {
  group('InMemoryDatastore', () {
    late InMemoryDatastore datastore;

    setUp(() async {
      datastore = InMemoryDatastore();
      await datastore.init();
    });

    tearDown(() async {
      await datastore.close();
    });

    test('initializes and closes correctly', () async {
      expect(datastore.isOpen, isTrue);
      await datastore.close();
      expect(datastore.isOpen, isFalse);
    });

    test('stores and retrieves data', () async {
      final block = await createTestBlock('test data');
      final cidStr = block.cid.toString();
      final key = Key('/blocks/$cidStr');

      await datastore.put(key, block.data);
      final retrieved = await datastore.get(key);

      expect(retrieved, isNotNull);
      expect(retrieved, equals(block.data));
    });

    test('has() returns correct existence status', () async {
      final block = await createTestBlock('test');
      final key = Key('/blocks/${block.cid.toString()}');

      expect(await datastore.has(key), isFalse);

      await datastore.put(key, block.data);
      expect(await datastore.has(key), isTrue);
    });

    test('deletes data', () async {
      final block = await createTestBlock('test');
      final key = Key('/blocks/${block.cid.toString()}');

      await datastore.put(key, block.data);
      expect(await datastore.has(key), isTrue);

      await datastore.delete(key);
      expect(await datastore.has(key), isFalse);
    });

    test('query() returns matching entries', () async {
      final blocks = await createTestBlocks(3);

      for (final block in blocks) {
        final key = Key('/blocks/${block.cid.toString()}');
        await datastore.put(key, block.data);
      }

      int count = 0;
      await for (final _ in datastore.query(Query(prefix: '/blocks/', keysOnly: true))) {
        count++;
      }
      expect(count, equals(3));
    });

    test('query with keysOnly returns null values', () async {
      final block = await createTestBlock('test');
      final key = Key('/blocks/${block.cid.toString()}');
      await datastore.put(key, block.data);

      await for (final entry in datastore.query(Query(prefix: '/blocks/', keysOnly: true))) {
        expect(entry.value, isNull);
        expect(entry.key.toString(), startsWith('/blocks/'));
      }
    });

    test('query without keysOnly returns values', () async {
      final block = await createTestBlock('test');
      final key = Key('/blocks/${block.cid.toString()}');
      await datastore.put(key, block.data);

      await for (final entry in datastore.query(Query(prefix: '/blocks/', keysOnly: false))) {
        expect(entry.value, isNotNull);
        expect(entry.value, equals(block.data));
      }
    });

    test('throws error when operating on closed datastore', () async {
      await datastore.close();
      final key = Key('/test');

      expect(
        () async => await datastore.put(key, Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('get() on non-existent key returns null', () async {
      final key = Key('/non-existent');
      expect(await datastore.get(key), isNull);
    });

    test('put() with same key overwrites', () async {
      final key = Key('/test/item');
      await datastore.put(key, Uint8List.fromList([1]));
      await datastore.put(key, Uint8List.fromList([2]));

      final retrieved = await datastore.get(key);
      expect(retrieved, equals(Uint8List.fromList([2])));
    });

    test('handles long keys', () async {
      final longKey = Key('/${'a' * 200}');
      final data = Uint8List.fromList([1, 2, 3]);

      await datastore.put(longKey, data);
      expect(await datastore.get(longKey), equals(data));
    });

    test('handles special characters in keys', () async {
      // Note: Keys with special chars should be cleaned by Key class
      final key = Key('/cid-with-special-chars');
      final data = Uint8List.fromList([4, 5, 6]);

      await datastore.put(key, data);
      expect(await datastore.get(key), isNotNull);
    });

    test('prefix filtering works correctly', () async {
      await datastore.put(Key('/blocks/qm1'), Uint8List.fromList([1]));
      await datastore.put(Key('/blocks/qm2'), Uint8List.fromList([2]));
      await datastore.put(Key('/pins/qm1'), Uint8List.fromList([1]));

      int blockCount = 0;
      await for (final _ in datastore.query(Query(prefix: '/blocks/'))) {
        blockCount++;
      }
      expect(blockCount, equals(2));

      int pinCount = 0;
      await for (final _ in datastore.query(Query(prefix: '/pins/'))) {
        pinCount++;
      }
      expect(pinCount, equals(1));
    });
  });
}
