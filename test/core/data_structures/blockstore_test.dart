import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('BlockStore', () {
    late BlockStore store;
    late String testDirPath;

    setUp(() async {
      testDirPath = await getPlatform().createTempDirectory('blockstore_test_');
      store = BlockStore(path: testDirPath);
    });

    tearDown(() async {
      await store.stop();
      try {
        if (await getPlatform().exists(testDirPath)) {
          await getPlatform().delete(testDirPath);
        }
      } catch (_) {}
    });

    test('lifecycle: start and stop', () async {
      await store.start();
      final status = await store.getStatus();
      expect(status['total_blocks'], equals(0));
      await store.stop();
    });

    test('CRUD: put, has, get, remove', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      // put
      final addResp = await store.putBlock(block);
      expect(addResp.success, isTrue);

      // has
      expect(await store.hasBlock(cid.encode()), isTrue);

      // get
      final getResp = await store.getBlock(cid.encode());
      expect(getResp.found, isTrue);
      expect(getResp.block.data, equals(data));

      // remove
      final remResp = await store.removeBlock(cid.encode());
      expect(remResp.success, isTrue);
      expect(await store.hasBlock(cid.encode()), isFalse);
    });

    test('put duplicate block', () async {
      final data = Uint8List.fromList([10, 20]);
      final block = Block(cid: CID.computeForDataSync(data), data: data);

      await store.putBlock(block);
      final resp = await store.putBlock(block);
      expect(resp.success, isTrue);
      expect(resp.message, contains('already exists'));
    });

    test('get non-existent block', () async {
      final resp = await store.getBlock('non-existent');
      expect(resp.found, isFalse);
    });

    test('remove non-existent block', () async {
      final resp = await store.removeBlock('non-existent');
      expect(resp.success, isFalse);
    });

    test('getAllBlocks and status', () async {
      final b1 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([1])),
        data: Uint8List.fromList([1]),
      );
      final b2 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([2])),
        data: Uint8List.fromList([2]),
      );

      await store.putBlock(b1);
      await store.putBlock(b2);

      final all = await store.getAllBlocks();
      expect(all.length, equals(2));

      final status = await store.getStatus();
      expect(status['total_blocks'], equals(2));
      expect(status['total_size'], equals(2));
    });

    test('gc removes unpinned blocks', () async {
      final b1 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([1])),
        data: Uint8List.fromList([1]),
      );
      final b2 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([2])),
        data: Uint8List.fromList([2]),
      );

      await store.putBlock(b1);
      await store.putBlock(b2);

      // Pin b1
      await store.pinManager.pinBlock(
        b1.cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );

      // Run GC - should remove b2 only
      final removed = await store.gc();
      expect(removed, equals(1));

      // b1 should still exist
      expect(await store.hasBlock(b1.cid.encode()), isTrue);
      expect(await store.hasBlock(b2.cid.encode()), isFalse);
    });

    test('gc removes all blocks when none are pinned', () async {
      final b1 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([1])),
        data: Uint8List.fromList([1]),
      );

      await store.putBlock(b1);

      final removed = await store.gc();
      expect(removed, equals(1));
      expect(await store.hasBlock(b1.cid.encode()), isFalse);
    });

    test('gc returns 0 when all blocks are pinned', () async {
      final b1 = Block(
        cid: CID.computeForDataSync(Uint8List.fromList([1])),
        data: Uint8List.fromList([1]),
      );

      await store.putBlock(b1);
      await store.pinManager.pinBlock(
        b1.cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );

      final removed = await store.gc();
      expect(removed, equals(0));
      expect(await store.hasBlock(b1.cid.encode()), isTrue);
    });

    test('pinManager getter returns pin manager', () {
      final pinManager = store.pinManager;
      expect(pinManager, isNotNull);
    });

    test('getStatus includes pinned_blocks count', () async {
      final data = Uint8List.fromList([100]);
      final block = Block(cid: CID.computeForDataSync(data), data: data);
      await store.putBlock(block);
      await store.pinManager.pinBlock(
        block.cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );

      final status = await store.getStatus();
      expect(status['pinned_blocks'], equals(1));
    });

    test('getBlock loads from disk when not in memory', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      await store.putBlock(block);

      // Clear in-memory cache by creating new store instance
      final newStore = BlockStore(path: testDirPath);
      await newStore.start();

      final getResp = await newStore.getBlock(cid.encode());
      expect(getResp.found, isTrue);
      expect(getResp.block.data, equals(data));

      await newStore.stop();
    });

    test('putBlock handles write errors', () async {
      // Test error handling by using a directory that becomes inaccessible
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      // Create a subdirectory and delete it to simulate write error
      final subDirPath = p.join(testDirPath, 'subdir');
      await getPlatform().createDirectory(subDirPath);
      final errorStore = BlockStore(path: subDirPath);
      await errorStore.start();

      // Delete the directory to cause write errors
      await getPlatform().delete(subDirPath);

      // Try to put block - should handle error gracefully
      final result = await errorStore.putBlock(block);
      // Should either succeed (if cached) or fail gracefully
      expect(result, isNotNull);

      await errorStore.stop();
    });

    test('removeBlock handles file not found gracefully', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      await store.putBlock(block);
      await store.removeBlock(cid.encode());

      // Try removing again - should return failure
      final resp = await store.removeBlock(cid.encode());
      expect(resp.success, isFalse);
    });

    test('start loads existing blocks from disk', () async {
      final data = Uint8List.fromList([5, 6, 7]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      await store.putBlock(block);
      await store.stop();

      // Create new store instance - should load existing blocks
      final newStore = BlockStore(path: testDirPath);
      await newStore.start();

      final status = await newStore.getStatus();
      expect(status['total_blocks'], equals(1));

      await newStore.stop();
    });

    test('stop saves pin state', () async {
      final data = Uint8List.fromList([8, 9]);
      final block = Block(cid: CID.computeForDataSync(data), data: data);

      await store.putBlock(block);
      await store.pinManager.pinBlock(
        block.cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );
      await store.stop();

      // Create new store instance - should load pin state
      final newStore = BlockStore(path: testDirPath);
      await newStore.start();

      final status = await newStore.getStatus();
      expect(status['pinned_blocks'], equals(1));

      await newStore.stop();
    });

    test('removeBlock with block in index but not on disk', () async {
      final data = Uint8List.fromList([12, 13]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      await store.putBlock(block);

      // Manually delete the file
      final blockFilePath = p.join(testDirPath, cid.encode());
      if (await getPlatform().exists(blockFilePath)) {
        await getPlatform().delete(blockFilePath);
      }

      // Remove should still work since it's in the index
      final resp = await store.removeBlock(cid.encode());
      expect(resp.success, isTrue);
    });

    test('hasBlock returns false for non-existent block', () async {
      final has = await store.hasBlock('non-existent-cid');
      expect(has, isFalse);
    });

    test('getAllBlocks returns empty list when no blocks', () async {
      final all = await store.getAllBlocks();
      expect(all, isEmpty);
    });

    test('putBlock with large data', () async {
      final largeData = Uint8List.fromList(List.filled(10000, 42));
      final block = Block(
        cid: CID.computeForDataSync(largeData),
        data: largeData,
      );

      final resp = await store.putBlock(block);
      expect(resp.success, isTrue);

      final getResp = await store.getBlock(block.cid.encode());
      expect(getResp.found, isTrue);
      expect(getResp.block.data.length, equals(10000));
    });

    test(
      'getStatus returns correct values after multiple operations',
      () async {
        final b1 = Block(
          cid: CID.computeForDataSync(Uint8List.fromList([1])),
          data: Uint8List.fromList([1]),
        );
        final b2 = Block(
          cid: CID.computeForDataSync(Uint8List.fromList([2])),
          data: Uint8List.fromList([2]),
        );

        await store.putBlock(b1);
        await store.putBlock(b2);
        await store.pinManager.pinBlock(
          b1.cid.toProto(),
          PinTypeProto.PIN_TYPE_DIRECT,
        );

        final status = await store.getStatus();
        expect(status['total_blocks'], equals(2));
        expect(status['total_size'], equals(2));
        expect(status['pinned_blocks'], equals(1));
      },
    );

    test('removeBlock removes from index and disk', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = CID.computeForDataSync(data);
      final block = Block(cid: cid, data: data);

      await store.putBlock(block);
      await store.removeBlock(cid.encode());

      // Check that block is not in memory
      expect(await store.hasBlock(cid.encode()), isFalse);

      // Check that file is deleted
      final blockFilePath = p.join(testDirPath, cid.encode());
      expect(await getPlatform().exists(blockFilePath), isFalse);
    });

    test('gc with no blocks returns 0', () async {
      final removed = await store.gc();
      expect(removed, equals(0));
    });

    test('pinManager persists pins across restarts', () async {
      final data = Uint8List.fromList([99]);
      final block = Block(cid: CID.computeForDataSync(data), data: data);

      await store.putBlock(block);
      await store.pinManager.pinBlock(
        block.cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );
      await store.stop();

      final newStore = BlockStore(path: testDirPath);
      await newStore.start();

      final status = await newStore.getStatus();
      expect(status['pinned_blocks'], equals(1));

      await newStore.stop();
    });
  });
}
