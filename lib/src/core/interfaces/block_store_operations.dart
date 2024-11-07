import 'package:dart_ipfs/src/core/block.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';

abstract class BlockStoreOperations {
  Future<BlockOperationResponse<void>> addBlock(Block block);
  Future<BlockOperationResponse<Block>> getBlock(String cid);
  Future<BlockOperationResponse<void>> removeBlock(String cid);
  Future<BlockOperationResponse<List<Block>>> getAllBlocks();
}
