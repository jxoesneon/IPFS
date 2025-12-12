// src/services/block_store_service.dart
import 'package:grpc/grpc.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
// import 'package:dart_ipfs/src/proto/generated/core/block.pbgrpc.dart'; // File might not exist yet
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pbgrpc.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';

class BlockStoreService extends BlockStoreServiceBase {
  final BlockStore _blockStore;

  BlockStoreService(this._blockStore);

  @override
  Future<AddBlockResponse> addBlock(
      ServiceCall ctx, BlockProto request) async {
    final block = Block.fromProto(request);
    return _blockStore.putBlock(block);
  }

  @override
  Future<GetBlockResponse> getBlock(
      ServiceCall ctx, IPFSCIDProto request) async {
    return _blockStore.getBlock(request.toString());
  }

  @override
  Future<RemoveBlockResponse> removeBlock(
      ServiceCall ctx, IPFSCIDProto request) async {
    return _blockStore.removeBlock(request.toString());
  }

  @override
  Stream<BlockProto> getAllBlocks(ServiceCall call, Empty request) async* {
    final blocks = await _blockStore.getAllBlocks();
    for (final block in blocks) {
      yield block.toProto();
    }
  }
}
