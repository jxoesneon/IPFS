import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';

class BlockStore {
  final Map<String, Block> _blocks = {};
  late final PinManager _pinManager;

  BlockStore() {
    _pinManager = PinManager(this);
  }

  Future<AddBlockResponse> addBlock(BlockProto block) async {
    try {
      final cidStr = block.cid.toString();
      if (_blocks.containsKey(cidStr)) {
        return BlockResponseFactory.failureAdd('Block already exists');
      }

      _blocks[cidStr] = Block.fromProto(block);
      return BlockResponseFactory.successAdd('Block added successfully');
    } catch (e) {
      return BlockResponseFactory.failureAdd('Failed to add block: $e');
    }
  }

  Future<GetBlockResponse> getBlock(String cid) async {
    try {
      final block = _blocks[cid];
      if (block == null) {
        return BlockResponseFactory.notFound();
      }
      return BlockResponseFactory.successGet(block.toProto());
    } catch (e) {
      return BlockResponseFactory.notFound();
    }
  }

  Future<RemoveBlockResponse> removeBlock(String cid) async {
    try {
      if (!_blocks.containsKey(cid)) {
        return BlockResponseFactory.failureRemove('Block not found');
      }

      final cidProto = _stringToIPFSCIDProto(cid);
      if (_pinManager.isBlockPinned(cidProto)) {
        return BlockResponseFactory.failureRemove('Cannot remove pinned block');
      }

      _blocks.remove(cid);
      return BlockResponseFactory.successRemove('Block removed successfully');
    } catch (e) {
      return BlockResponseFactory.failureRemove('Failed to remove block: $e');
    }
  }

  IPFSCIDProto _stringToIPFSCIDProto(String cidStr) {
    final proto = IPFSCIDProto()
      ..version = IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash.addAll(cidStr.codeUnits)
      ..codec = 'raw'
      ..multibasePrefix = 'base58btc';
    return proto;
  }
}
