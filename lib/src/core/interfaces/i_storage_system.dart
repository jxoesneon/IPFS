// src/core/interfaces/i_storage_system.dart
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Interface for block storage subsystem operations.
///
/// Extends [ICoreSystem] with CRUD operations for content-addressed blocks.
abstract class IStorageSystem extends ICoreSystem {
  /// Stores a [block] and returns the operation response.
  Future<AddBlockResponse> putBlock(Block block);

  /// Retrieves a block by its [cid].
  Future<GetBlockResponse> getBlock(String cid);

  /// Removes a block by its [cid].
  Future<RemoveBlockResponse> removeBlock(String cid);

  /// Returns true if a block with [cid] exists.
  Future<bool> hasBlock(String cid);
}
