// test/mocks/mock_block_store.dart
import 'dart:async';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/block_store_operations.dart';

/// Mock implementation of IBlockStore for testing.
///
/// Provides simple in-memory block storage with call tracking.
class MockBlockStore implements IBlockStore {
  final Map<String, Block> _blocks = {};
  final List<String> _calls = [];

  @override
  Future<Block?> getBlock(CID cid) async {
    _recordCall('getBlock:${cid.toString()}');
    return _blocks[cid.toString()];
  }

  @override
  Future<void> putBlock(Block block) async {
    _recordCall('putBlock:${block.cid.toString()}');
    _blocks[block.cid.toString()] = block;
  }

  @override
  Future<bool> hasBlock(CID cid) async {
    _recordCall('hasBlock:${cid.toString()}');
    return _blocks.containsKey(cid.toString());
  }

  @override
  Future<void> deleteBlock(CID cid) async {
    _recordCall('deleteBlock:${cid.toString()}');
    _blocks.remove(cid.toString());
  }

  @override
  Future<List<CID>> getAllBlocks() async {
    _recordCall('getAllBlocks');
    return _blocks.keys.map((k) => CID.decode(k)).toList();
  }

  // ===== Test Configuration Methods =====

  /// Set up a block for testing
  void setupBlock(CID cid, Block block) {
    _blocks[cid.toString()] = block;
  }

  /// Check if a method was called
  bool wasCalled(String method) {
    return _calls.any((c) => c.startsWith(method));
  }

  /// Get all recorded calls
  List<String> getCalls() => List.unmodifiable(_calls);

  /// Get call count
  int getCallCount(String method) {
    return _calls.where((c) => c.startsWith(method)).length;
  }

  /// Reset all state
  void reset() {
    _blocks.clear();
    _calls.clear();
  }

  void _recordCall(String call) {
    _calls.add(call);
  }
}
