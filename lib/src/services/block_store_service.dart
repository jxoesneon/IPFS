// src/services/block_store_service.dart
import 'package:protobuf/protobuf.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pbserver.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/google/protobuf/empty.pb.dart';

class BlockStoreService extends BlockStoreServiceBase {
  final BlockStore _blockStore;

  BlockStoreService(this._blockStore);

  @override
  Future<AddBlockResponse> addBlock(
      ServerContext ctx, BlockProto request) async {
    final block = Block.fromProto(request);
    return _blockStore.putBlock(block);
  }

  @override
  Future<GetBlockResponse> getBlock(
      ServerContext ctx, IPFSCIDProto request) async {
    return _blockStore.getBlock(request.toString());
  }

  @override
  Future<RemoveBlockResponse> removeBlock(
      ServerContext ctx, IPFSCIDProto request) async {
    return _blockStore.removeBlock(request.toString());
  }

  @override
  Future<BlockProto> getAllBlocks(ServerContext ctx, Empty request) async {
    final blocks = await _blockStore.getAllBlocks();
    if (blocks.isEmpty) {
      return BlockProto();
    }
    return blocks.first.toProto();
  }
}
