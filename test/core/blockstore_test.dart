import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:test/test.dart';

void main() {
  group('Block Tests', () {
    test('should create from data', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);

      expect(block.data, equals(data));
      expect(block.size, 4);
      expect(block.cid, isNotNull);
      expect(block.format, 'raw');
    });

    test('should serialize to/from proto', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);

      final proto = block.toProto();
      expect(proto.data, equals(data));
      expect(proto.format, 'raw');

      final reconstructed = Block.fromProto(proto);
      expect(reconstructed.data, equals(data));
      // CID equality check might need comparing encoded strings or hash bytes
      expect(reconstructed.cid.toString(), equals(block.cid.toString()));
    });

    test('should serialize to/from bitswap proto', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);

      final bsProto = block.toBitswapProto();
      expect(bsProto.data, equals(data));

      // Note: fromBitswapProto is async and might re-compute CID
      final reconstructed = await Block.fromBitswapProto(bsProto);
      expect(reconstructed.data, equals(data));
    });
  });

  group('BlockStore Tests', () {
    late BlockStore store;

    setUp(() {
      store = BlockStore(path: '/tmp/test_defs'); // Path irrelevant for in-memory map
    });

    test('should start and stop', () async {
      await store.start();
      await store.stop();
    });

    test('should put and get block', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);

      // Put
      final addResp = await store.putBlock(block);
      expect(addResp.success, isTrue);

      // Get
      final getResp = await store.getBlock(block.cid.toString());
      expect(getResp.found, isTrue);
      // getBlock returns BlockProto in the response?
      // Checking BlockResponseFactory usage in BlockStore
      // It returns GetBlockResponse which has `block` field of type BlockProto
      expect(getResp.block.data, equals(data));

      // Has
      expect(await store.hasBlock(block.cid.toString()), isTrue);
    });

    test('should fail to get non-existent block', () async {
      final resp = await store.getBlock('non-existent');
      expect(resp.found, isFalse);
    });

    test('should remove block', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);
      await store.putBlock(block);

      final removeResp = await store.removeBlock(block.cid.toString());
      expect(removeResp.success, isTrue);

      expect(await store.hasBlock(block.cid.toString()), isFalse);
    });

    test('should get all blocks', () async {
      final block1 = await Block.fromData(Uint8List.fromList([1]));
      final block2 = await Block.fromData(Uint8List.fromList([2]));

      await store.putBlock(block1);
      await store.putBlock(block2);

      final all = await store.getAllBlocks();
      expect(all.length, 2);
    });

    test('should get status', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2]));
      await store.putBlock(block);

      final status = await store.getStatus();
      expect(status['total_blocks'], 1);
      expect(status['total_size'], 2);
    });
  });
}
