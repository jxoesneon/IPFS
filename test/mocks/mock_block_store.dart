// test/mocks/mock_block_store.dart
import 'dart:async';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Mock implementation of IBlockStore for testing.
///
/// Provides simple in-memory block storage with call tracking.
/// Fully implements IBlockStore interface with protobuf responses.
class MockBlockStore implements IBlockStore {
  final Map<String, Block> _blocks = {};
  final List<String> _calls = [];
  bool _started = false;

  @override
  Future<void> start() async {
    _recordCall('start');
    _started = true;
  }

  @override
  Future<void> stop() async {
    _recordCall('stop');
    _started = false;
  }

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    _recordCall('getBlock:$cid');

    if (!_started) {
      return BlockResponseFactory.notFound();
    }

    final block = _blocks[cid];
    if (block == null) {
      return BlockResponseFactory.notFound();
    }

    return BlockResponseFactory.successGet(block.toProto());
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    final cid = block.cid.toString();
    _recordCall('putBlock:$cid');

    if (!_started) {
      return BlockResponseFactory.failureAdd('BlockStore not started');
    }

    _blocks[cid] = block;
    return BlockResponseFactory.successAdd('Block added successfully');
  }

  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    _recordCall('removeBlock:$cid');

    if (!_started) {
      return BlockResponseFactory.failureRemove('BlockStore not started');
    }

    final removed = _blocks.remove(cid);
    if (removed == null) {
      return BlockResponseFactory.failureRemove('Block not found');
    }

    return BlockResponseFactory.successRemove('Block removed successfully');
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    _recordCall('getAllBlocks');
    return _blocks.values.toList();
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    _recordCall('getStatus');
    return {'started': _started, 'blockCount': _blocks.length, 'cids': _blocks.keys.toList()};
  }

  // ===== Test Helper Methods =====

  /// Set up a block for testing
  void setupBlock(String cid, Block block) {
    _blocks[cid] = block;
  }

  /// Check if a block exists (without recording call)
  @override
  Future<bool> hasBlock(String cid) async {
    return _blocks.containsKey(cid);
  }

  /// Get block count
  int get blockCount => _blocks.length;

  /// Check if started
  bool get isStarted => _started;

  /// Check if a method was called
  bool wasCalled(String method) {
    return _calls.any((c) => c.startsWith(method));
  }

  /// Get all recorded calls
  List<String> getCalls() => List.unmodifiable(_calls);

  /// Get call count for a specific method
  int getCallCount(String method) {
    return _calls.where((c) => c.startsWith(method)).length;
  }

  /// Reset all state
  void reset() {
    _blocks.clear();
    _calls.clear();
    _started = false;
  }

  void _recordCall(String call) {
    _calls.add(call);
  }
}
