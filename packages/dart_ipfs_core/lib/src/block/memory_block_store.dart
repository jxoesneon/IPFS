// lib/src/block/memory_block_store.dart
import 'dart:async';

import '../cid/cid.dart';

import 'block.dart';
import 'block_store.dart';

/// A simple in-memory block store implementation.
///
/// This is intended for testing, ephemeral caching, and lightweight
/// applications. It does not persist data across process restarts.
class InMemoryBlockStore implements IBlockStore {
  /// Creates an empty in-memory block store.
  InMemoryBlockStore();

  final Map<String, Block> _blocks = {};

  @override
  Future<void> start() async {
    // No-op for in-memory store.
  }

  @override
  Future<void> stop() async {
    _blocks.clear();
  }

  @override
  Future<BlockStoreResult<Block?>> getBlock(CID cid) async {
    final block = _blocks[cid.toString()];
    if (block == null) {
      return BlockStoreResult<Block?>.failure(
        null,
        message: 'Block not found: ${cid.toString()}',
      );
    }
    return BlockStoreResult<Block?>.success(block, message: 'Block found');
  }

  @override
  Future<BlockStoreResult<void>> putBlock(Block block) async {
    final cidStr = block.cid.toString();
    _blocks[cidStr] = block;
    return BlockStoreResult<void>.success(
      null,
      message: 'Block stored: $cidStr',
    );
  }

  @override
  Future<BlockStoreResult<bool>> removeBlock(CID cid) async {
    final cidStr = cid.toString();
    final removed = _blocks.remove(cidStr) != null;
    return BlockStoreResult<bool>.success(
      removed,
      message: removed ? 'Block removed: $cidStr' : 'Block not found: $cidStr',
    );
  }

  @override
  Future<bool> hasBlock(CID cid) async => _blocks.containsKey(cid.toString());

  @override
  Future<List<Block>> getAllBlocks() async => List.unmodifiable(_blocks.values);

  /// Returns the number of blocks currently in memory.
  int get length => _blocks.length;

  /// Clears all blocks from the store.
  void clear() => _blocks.clear();
}
