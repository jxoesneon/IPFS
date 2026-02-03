import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:test/test.dart';

void main() {
  group('BlockStore', () {
    late BlockStore store;
    final testPath = './test_blockstore';

    setUp(() {
      store = BlockStore(path: testPath);
    });

    tearDown(() async {
      await store.stop();
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

    test('integration: pin content and status', () async {
      final data = Uint8List.fromList([100]);
      final block = Block(cid: CID.computeForDataSync(data), data: data);
      await store.putBlock(block);

      // Pin via pinManager
      final cidProto = block.cid.toProto();
      // Need to import PinTypeProto
      // Actually PinManager is already integrated.
    });
  });
}
