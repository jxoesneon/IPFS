import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('Block', () {
    test('creates block from data and computes CID', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);
      expect(block.data, equals(data));
      expect(block.size, equals(4));
      expect(block.format, equals('raw'));
      expect(block.cid.encode(), startsWith('b'));
    });

    test('validates matching CID', () async {
      final data = Uint8List.fromList([5, 6, 7, 8]);
      final block = await Block.fromData(data);
      expect(await block.validate(), isTrue);
    });

    test('validation fails for tampered data', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final block = await Block.fromData(data);
      final tampered = Block(
        cid: block.cid,
        data: Uint8List.fromList([1, 2, 4]),
      );
      expect(await tampered.validate(), isFalse);
    });

    test('validateSync is structural', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final block = await Block.fromData(data);
      expect(block.validateSync(), isTrue);

      final empty = Block(cid: block.cid, data: Uint8List(0));
      expect(empty.validateSync(), isFalse);
    });

    test('toBytes returns data', () async {
      final data = Uint8List.fromList([9, 10, 11]);
      final block = await Block.fromData(data);
      expect(block.toBytes(), equals(data));
    });
  });

  group('InMemoryBlockStore', () {
    test('stores and retrieves block', () async {
      final store = InMemoryBlockStore();
      await store.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final block = await Block.fromData(data);

      final putResult = await store.putBlock(block);
      expect(putResult.succeeded, isTrue);

      final getResult = await store.getBlock(block.cid);
      expect(getResult.succeeded, isTrue);
      expect(getResult.value, isNotNull);
      expect(getResult.value!.cid, equals(block.cid));

      await store.stop();
    });

    test('reports missing block', () async {
      final store = InMemoryBlockStore();
      await store.start();
      final cid = await CID.fromContent(Uint8List.fromList([99]));
      final result = await store.getBlock(cid);
      expect(result.succeeded, isFalse);
      expect(result.value, isNull);
      await store.stop();
    });

    test('removes block', () async {
      final store = InMemoryBlockStore();
      await store.start();
      final block = await Block.fromData(Uint8List.fromList([4, 5, 6]));
      await store.putBlock(block);
      expect(await store.hasBlock(block.cid), isTrue);

      final result = await store.removeBlock(block.cid);
      expect(result.succeeded, isTrue);
      expect(result.value, isTrue);
      expect(await store.hasBlock(block.cid), isFalse);
      await store.stop();
    });

    test('returns all blocks', () async {
      final store = InMemoryBlockStore();
      await store.start();
      final a = await Block.fromData(Uint8List.fromList([1]));
      final b = await Block.fromData(Uint8List.fromList([2]));
      await store.putBlock(a);
      await store.putBlock(b);

      final all = await store.getAllBlocks();
      expect(all.length, equals(2));
      await store.stop();
    });
  });
}
