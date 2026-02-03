// src/core/interfaces/i_block_store.dart
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_storage_system.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Interface for content-addressed block storage operations.
///
/// This interface defines the contract for storing and retrieving
/// content-addressed blocks in IPFS. Implementations may use various
/// backends such as in-memory storage, filesystem, or databases.
///
/// All block operations are asynchronous and return response objects
/// that include success/failure status and relevant data.
///
/// See also:
/// - [BlockStore] for the default implementation
/// - [IStorageSystem] for the parent interface
/// - [Block] for the block data structure
abstract class IBlockStore extends IStorageSystem {
  /// Initializes the block store.
  @override
  Future<void> start();

  /// Shuts down the block store gracefully.
  @override
  Future<void> stop();

  /// Retrieves a block by its CID.
  ///
  /// Returns a [GetBlockResponse] containing the block if found.
  @override
  Future<GetBlockResponse> getBlock(String cid);

  /// Stores a block in the block store.
  ///
  /// Returns an [AddBlockResponse] indicating success or failure.
  @override
  Future<AddBlockResponse> putBlock(Block block);

  /// Removes a block from the block store.
  ///
  /// Returns a [RemoveBlockResponse] indicating success or failure.
  @override
  Future<RemoveBlockResponse> removeBlock(String cid);

  /// Returns all blocks in the store.
  Future<List<Block>> getAllBlocks();

  /// Returns statistics about the block store.
  @override
  Future<Map<String, dynamic>> getStatus();
}

