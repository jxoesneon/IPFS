import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart'; // Adjust the import path as necessary
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart'; // Adjust the import path as necessary
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'; // Adjust the import path as necessary

void main() {
  print('Running blockstore tests...');
  group('BlockStore', () {
    print('Creating blockstore instance...');
    late BlockStore blockStore;
    late BlockProto block;
    late IPFSCIDProto cid;

    setUp(() {
      print('Setting up test environment...');
      blockStore = BlockStore();
      cid = IPFSCIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash.addAll([0x12, 0x20])
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';

      block = BlockProto()
        ..data.addAll([1, 2, 3])
        ..cid = cid;
    });

    test('addBlock adds a block successfully', () {
      print('Running addBlock adds a block successfully...');
      final response = blockStore.addBlock(block);

      expect(response.success, isTrue);
      expect(response.message, equals("Block added successfully."));
      expect(blockStore.getAllBlocks().length, equals(1));
    });

    test('addBlock does not add duplicate blocks', () {
      print('Running addBlock does not add duplicate blocks...');
      blockStore.addBlock(block);
      final response = blockStore.addBlock(block);

      expect(response.success, isFalse);
      expect(response.message, equals("Block already exists."));
      expect(blockStore.getAllBlocks().length, equals(1));
    });

    test('getBlock retrieves a block successfully', () {
      print('Running getBlock retrieves a block successfully...');
      blockStore.addBlock(block);
      final response = blockStore.getBlock(cid);

      expect(response.found, isTrue);
      expect(response.block.cid.version, equals(cid.version));
      expect(response.block.data, equals(block.data));
    });

    test('getBlock returns not found for non-existent block', () {
      print('Running getBlock returns not found for non-existent block...');
      final response = blockStore.getBlock(cid);

      expect(response.found, isFalse);
    });

    test('removeBlock removes a block successfully', () {
      print('Running removeBlock removes a block successfully...');
      blockStore.addBlock(block);
      final response = blockStore.removeBlock(cid);

      expect(response.success, isTrue);
      expect(response.message, equals("Block removed successfully."));
      expect(blockStore.getAllBlocks().length, equals(0));
    });

    test('removeBlock returns not found for non-existent block', () {
      print('Running removeBlock returns not found for non-existent block...');
      final response = blockStore.removeBlock(cid);

      expect(response.success, isFalse);
      expect(response.message, equals("Block not found."));
    });

    test('getAllBlocks retrieves all blocks', () {
      print('Running getAllBlocks retrieves all blocks...');

      final anotherCid = IPFSCIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash.addAll([0x34, 0x56])
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';

      final anotherBlock = BlockProto()
        ..data.addAll([4, 5, 6])
        ..cid = anotherCid;

      blockStore.addBlock(block);
      blockStore.addBlock(anotherBlock);

      final allBlocks = blockStore.getAllBlocks();

      expect(allBlocks.length, equals(2));
    });
  });
}
