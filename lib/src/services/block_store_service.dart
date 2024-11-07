import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

class BlockStoreService extends BlockStoreServiceBase {
  final BlockStore _blockStore;

  BlockStoreService(this._blockStore);

  @override
  Future<AddBlockResponse> addBlock(
      ServerContext ctx, BlockProto request) async {
    final block = Block.fromProto(request);
    return _blockStore.addBlock(block);
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
  Stream<BlockProto> getAllBlocks(ServerContext ctx, Empty request) async* {
    final blocks = await _blockStore.getAllBlocks();
    for (final block in blocks) {
      yield block.toProto();
    }
  }
}
