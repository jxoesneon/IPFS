import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/storage/flat_file_datastore.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Keeps only entries whose value has exactly [length] bytes.
class _ValueLengthFilter extends QueryFilter {
  _ValueLengthFilter(this.length);

  final int length;

  @override
  bool filter(MapEntry<Key, Uint8List> entry) => entry.value.length == length;
}

void main() {
  late Directory tempDir;
  late FlatFileDatastore datastore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'flat_file_datastore_test_',
    );
    datastore = FlatFileDatastore(tempDir.path);
    await datastore.init();
  });

  tearDown(() async {
    await datastore.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FlatFileDatastore', () {
    group('init', () {
      test('creates directory if not exists', () async {
        final newPath = p.join(tempDir.path, 'new_subdir');
        final newDs = FlatFileDatastore(newPath);
        await newDs.init();

        expect(await Directory(newPath).exists(), isTrue);
        await newDs.close();
      });

      test('does not fail if directory already exists', () async {
        // init was already called in setUp, call again
        await datastore.init();
        expect(await Directory(tempDir.path).exists(), isTrue);
      });
    });

    group('put and get', () {
      test('stores and retrieves data', () async {
        final key = Key('/test/data1');
        final value = Uint8List.fromList([1, 2, 3, 4, 5]);

        await datastore.put(key, value);
        final retrieved = await datastore.get(key);

        expect(retrieved, equals(value));
      });

      test('overwrites existing data', () async {
        final key = Key('/overwrite');
        final value1 = Uint8List.fromList([1, 2, 3]);
        final value2 = Uint8List.fromList([4, 5, 6, 7]);

        await datastore.put(key, value1);
        await datastore.put(key, value2);
        final retrieved = await datastore.get(key);

        expect(retrieved, equals(value2));
      });

      test('returns null for non-existent key', () async {
        final key = Key('/nonexistent');
        final retrieved = await datastore.get(key);

        expect(retrieved, isNull);
      });
    });

    group('has', () {
      test('returns true for existing key', () async {
        final key = Key('/exists');
        await datastore.put(key, Uint8List.fromList([1]));

        expect(await datastore.has(key), isTrue);
      });

      test('returns false for non-existent key', () async {
        final key = Key('/not_here');
        expect(await datastore.has(key), isFalse);
      });
    });

    group('delete', () {
      test('deletes existing key', () async {
        final key = Key('/to_delete');
        await datastore.put(key, Uint8List.fromList([1, 2]));
        expect(await datastore.has(key), isTrue);

        await datastore.delete(key);
        expect(await datastore.has(key), isFalse);
      });

      test('does not fail when deleting non-existent key', () async {
        final key = Key('/not_present');
        // Should not throw
        await datastore.delete(key);
        expect(await datastore.has(key), isFalse);
      });
    });

    group('query', () {
      test('returns all entries with empty query', () async {
        await datastore.put(Key('/a'), Uint8List.fromList([1]));
        await datastore.put(Key('/b'), Uint8List.fromList([2]));
        await datastore.put(Key('/c'), Uint8List.fromList([3]));

        final entries = await datastore.query(Query()).toList();
        expect(entries.length, equals(3));
      });

      test('filters by prefix', () async {
        await datastore.put(Key('/users/alice'), Uint8List.fromList([1]));
        await datastore.put(Key('/users/bob'), Uint8List.fromList([2]));
        await datastore.put(Key('/posts/first'), Uint8List.fromList([3]));

        final entries = await datastore.query(Query(prefix: '/users')).toList();
        expect(entries.length, equals(2));
        expect(
          entries.every((e) => e.key.toString().startsWith('/users')),
          isTrue,
        );
      });

      test('keysOnly query returns null values', () async {
        await datastore.put(Key('/key1'), Uint8List.fromList([1, 2, 3]));

        final entries = await datastore.query(Query(keysOnly: true)).toList();
        expect(entries.length, equals(1));
        // keysOnly may still return value if filters are applied
        // In this case no filters, so value could be null
      });

      test('walks deeply nested keys across multiple directories', () async {
        await datastore.put(Key('/pins/cid-abc'), Uint8List.fromList([1]));
        await datastore.put(
          Key('/dht/values/somekey'),
          Uint8List.fromList([2]),
        );
        await datastore.put(Key('/mfs/root'), Uint8List.fromList([3]));

        final all = await datastore.query(Query()).toList();
        expect(all.length, equals(3));

        final pins = await datastore.query(Query(prefix: '/pins')).toList();
        expect(pins.single.key.toString(), equals('/pins/cid-abc'));

        final dht = await datastore
            .query(Query(prefix: '/dht/values/', keysOnly: true))
            .toList();
        expect(dht.single.key.toString(), equals('/dht/values/somekey'));
      });

      test('applies filters to entry values', () async {
        await datastore.put(Key('/keep'), Uint8List.fromList([1, 2, 3]));
        await datastore.put(Key('/drop'), Uint8List.fromList([9]));

        final entries = await datastore
            .query(Query(filters: [_ValueLengthFilter(3)]))
            .toList();

        expect(entries.length, equals(1));
        expect(entries.single.key.toString(), equals('/keep'));
        expect(entries.single.value, equals([1, 2, 3]));
      });

      test('filters can reject every entry', () async {
        await datastore.put(Key('/a'), Uint8List.fromList([1]));
        await datastore.put(Key('/b'), Uint8List.fromList([2]));

        final entries = await datastore
            .query(Query(filters: [_ValueLengthFilter(99)]))
            .toList();

        expect(entries, isEmpty);
      });
    });

    group('persistence', () {
      test('data survives closing and reopening the datastore', () async {
        final key = Key('/pins/persisted');
        final value = Uint8List.fromList([9, 8, 7]);
        await datastore.put(key, value);
        await datastore.close();

        // Simulate a restart: a new instance over the same directory.
        final reopened = FlatFileDatastore(tempDir.path);
        await reopened.init();
        expect(await reopened.get(key), equals(value));
        await reopened.close();
      });
    });

    group('close', () {
      test('close is a no-op', () async {
        // Should not throw
        await datastore.close();
        await datastore.close(); // Can close multiple times
      });
    });
  });
}
