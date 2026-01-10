
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/storage/flat_file_datastore.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('Datastore Config', () {
    verifyDatastore('MemoryDatastore', () => MemoryDatastore());

    final tempDir = Directory.systemTemp.createTempSync('ipfs_datastore_test_');
    verifyDatastore('FlatFileDatastore', () => FlatFileDatastore(tempDir.path), teardown: () {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

void verifyDatastore(String name, Datastore Function() create, {void Function()? teardown}) {
  group(name, () {
    late Datastore ds;

    setUp(() async {
      ds = create();
      await ds.init();
    });

    tearDown(() async {
      await ds.close();
      if (teardown != null) teardown();
    });

    test('put and get', () async {
      final key = Key('/foo');
      final value = Uint8List.fromList(utf8.encode('bar'));
      await ds.put(key, value);

      final retrieved = await ds.get(key);
      expect(retrieved, equals(value));
    });

    test('has', () async {
      final key = Key('/exists');
      await ds.put(key, Uint8List(1));
      expect(await ds.has(key), isTrue);
      expect(await ds.has(Key('/missing')), isFalse);
    });

    test('delete', () async {
      final key = Key('/del');
      await ds.put(key, Uint8List(1));
      await ds.delete(key);
      expect(await ds.has(key), isFalse);
      expect(await ds.get(key), isNull);
    });

    test('query prefix', () async {
      await ds.put(Key('/a/1'), Uint8List.fromList([1]));
      await ds.put(Key('/a/2'), Uint8List.fromList([2]));
      await ds.put(Key('/b/1'), Uint8List.fromList([3]));

      final q = Query(prefix: '/a');
      final results = await ds.query(q).toList();
      expect(results.length, equals(2));
      expect(results.any((e) => e.key.toString() == '/a/1'), isTrue);
      expect(results.any((e) => e.key.toString() == '/a/2'), isTrue);
    });
    
    test('query keysOnly', () async {
       await ds.put(Key('/k/1'), Uint8List.fromList([1]));
       final q = Query(prefix: '/k', keysOnly: true);
       final results = await ds.query(q).toList();
       expect(results.length, equals(1));
       expect(results.first.value, isNull);
    });
  });
}
