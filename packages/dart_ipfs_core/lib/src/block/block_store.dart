// lib/src/block/block_store.dart
import 'dart:async';

import '../cid/cid.dart';

import 'block.dart';

/// A generic result returned by block store operations.
///
/// [succeeded] indicates whether the operation completed as expected. [value]
/// holds the payload, and [message] provides a human-readable description.
class BlockStoreResult<T> {
  /// Creates a result.
  const BlockStoreResult({
    required this.succeeded,
    required this.value,
    this.message,
  });

  /// Creates a successful result.
  factory BlockStoreResult.success(T value, {String? message}) =>
      BlockStoreResult<T>(succeeded: true, value: value, message: message);

  /// Creates a failed result.
  factory BlockStoreResult.failure(T value, {String? message}) =>
      BlockStoreResult<T>(succeeded: false, value: value, message: message);

  /// Whether the operation succeeded.
  final bool succeeded;

  /// The operation payload.
  final T value;

  /// Optional human-readable message.
  final String? message;
}

/// Interface for block storage operations.
abstract class IBlockStore {
  /// Starts the block store.
  Future<void> start();

  /// Stops the block store and releases resources.
  Future<void> stop();

  /// Retrieves a block by its CID.
  Future<BlockStoreResult<Block?>> getBlock(CID cid);

  /// Stores a block.
  Future<BlockStoreResult<void>> putBlock(Block block);

  /// Removes a block by its CID.
  Future<BlockStoreResult<bool>> removeBlock(CID cid);

  /// Returns true if the block exists.
  Future<bool> hasBlock(CID cid);

  /// Returns all stored blocks.
  Future<List<Block>> getAllBlocks();
}
