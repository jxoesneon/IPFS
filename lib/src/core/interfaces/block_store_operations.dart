import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';

/// Interface for BlockStore CRUD operations.
///
/// Defines the standard operations for storing and retrieving blocks.
abstract class BlockStoreOperations {
  /// Adds a [block] to storage.
  Future<BlockOperationResponse<void>> addBlock(Block block);

  /// Retrieves a block by [cid].
  Future<BlockOperationResponse<Block>> getBlock(String cid);

  /// Removes a block by [cid].
  Future<BlockOperationResponse<void>> removeBlock(String cid);

  /// Returns all stored blocks.
  Future<BlockOperationResponse<List<Block>>> getAllBlocks();
}

