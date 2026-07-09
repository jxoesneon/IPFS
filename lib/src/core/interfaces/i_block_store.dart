// src/core/interfaces/i_block_store.dart
import '../../proto/generated/core/blockstore.pb.dart';
import '../data_structures/block.dart';
import 'i_lifecycle.dart';

/// Interface for block storage operations.
abstract class IBlockStore implements ILifecycle {
  /// Retrieves a block by its CID.
  Future<GetBlockResponse> getBlock(String cid);

  /// Stores a block.
  Future<AddBlockResponse> putBlock(Block block);

  /// Removes a block by its CID.
  Future<RemoveBlockResponse> removeBlock(String cid);

  /// Returns true if the block exists.
  Future<bool> hasBlock(String cid);

  /// Returns all stored blocks.
  Future<List<Block>> getAllBlocks();

  /// Returns status of the blockstore.
  Future<Map<String, dynamic>> getStatus();

  /// Performs garbage collection by removing unpinned blocks.
  /// Returns the number of blocks removed.
  Future<int> gc();
}
