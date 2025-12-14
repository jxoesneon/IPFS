// test/mocks/in_memory_datastore_test.dart
import 'package:test/test.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
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

    test('stores and retrieves blocks', () async {
      final block = await createTestBlock('test data');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      final retrieved = await datastore.get(cid);

      expect(retrieved, isNotNull);
      expect(retrieved!.cid.toString(), equals(cid));
    });

    test('has() returns correct existence status', () async {
      final block = await createTestBlock('test');
      final cid = block.cid.toString();

      expect(await datastore.has(cid), isFalse);

      await datastore.put(cid, block);
      expect(await datastore.has(cid), isTrue);
    });

    test('deletes blocks', () async {
      final block = await createTestBlock('test');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      expect(await datastore.has(cid), isTrue);

      await datastore.delete(cid);
      expect(await datastore.has(cid), isFalse);
    });

    test('pin() prevents deletion', () async {
      final block = await createTestBlock('pinned');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      await datastore.pin(cid);

      expect(
        () async => await datastore.delete(cid),
        throwsA(isA<DatastoreError>()),
      );
    });

    test('unpin() allows deletion after pinning', () async {
      final block = await createTestBlock('unpinned');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      await datastore.pin(cid);
      await datastore.unpin(cid);

      await datastore.delete(cid);
      expect(await datastore.has(cid), isFalse);
    });

    test('isPinned() returns correct status', () async {
      final block = await createTestBlock('check pin');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      expect(await datastore.isPinned(cid), isFalse);

      await datastore.pin(cid);
      expect(await datastore.isPinned(cid), isTrue);
    });

    test('getAllKeys() returns all stored CIDs', () async {
      final blocks = await createTestBlocks(3);

      for (final block in blocks) {
        await datastore.put(block.cid.toString(), block);
      }

      final keys = await datastore.getAllKeys();
      expect(keys.length, equals(3));
    });

    test('size property returns correct count', () async {
      expect(datastore.numBlocks, equals(0));

      final blocks = await createTestBlocks(5);
      for (final block in blocks) {
        await datastore.put(block.cid.toString(), block);
      }

      expect(datastore.numBlocks, equals(5));
    });

    test('loadPinnedCIDs() and persistPinnedCIDs() work correctly', () async {
      final blocks = await createTestBlocks(2);
      final cid1 = blocks[0].cid.toString();
      final cid2 = blocks[1].cid.toString();

      await datastore.put(cid1, blocks[0]);
      await datastore.put(cid2, blocks[1]);
      await datastore.pin(cid1);
      await datastore.pin(cid2);

      final pinned = await datastore.loadPinnedCIDs();
      expect(pinned.length, equals(2));
      expect(pinned.contains(cid1), isTrue);
      expect(pinned.contains(cid2), isTrue);
    });

    test('throws error when operating on closed datastore', () async {
      await datastore.close();

      expect(
        () async => await datastore.put('cid', await createTestBlock('test')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
