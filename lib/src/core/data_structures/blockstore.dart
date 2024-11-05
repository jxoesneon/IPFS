import 'pin.dart';
import 'dart:async';
import '../../proto/generated/core/cid.pb.dart';         // Import the generated CIDProto
import '../../proto/generated/core/block.pb.dart';       // Import the generated BlockProto
import '../../proto/generated/core/blockstore.pb.dart'; // Import the generated BlockStoreProto
// lib/src/core/data_structures/blockstore.dart

/// Represents a block store that manages blocks with IPFS datastore compliance.
class BlockStore {
  final List<BlockProto> _blocks = [];
  final Set<String> _pinnedBlocks = {};
  final Map<String, DateTime> _blockAccessTimes = {};
  final Duration _gcThreshold;
  Timer? _gcTimer;

  BlockStore({Duration gcInterval = const Duration(hours: 1)}) : _gcThreshold = gcInterval {
    _startGarbageCollection();
  }

  /// Adds a block to the store with optional pinning.
  Future<AddBlockResponse> addBlock(BlockProto block, {bool pin = false}) async {
    if (_blocks.any((b) => b.cid == block.cid)) {
      if (pin) {
        _pinnedBlocks.add(block.cid.toString());
      }
      return AddBlockResponse()
        ..success = false
        ..message = "Block already exists.";
    }

    _blocks.add(block);
    _blockAccessTimes[block.cid.toString()] = DateTime.now();
    
    if (pin) {
      _pinnedBlocks.add(block.cid.toString());
    }

    return AddBlockResponse()
      ..success = true
      ..message = "Block added successfully.";
  }

  /// Pins a block by its CID.
  Future<bool> pinBlock(CIDProto cid) async {
    final block = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => BlockProto(),
    );

    if (_blocks.contains(block)) {
      _pinnedBlocks.add(cid.toString());
      return true;
    }
    return false;
  }

  /// Unpins a block by its CID.
  Future<bool> unpinBlock(CIDProto cid) async {
    return _pinnedBlocks.remove(cid.toString());
  }

  /// Gets all pinned blocks.
  List<BlockProto> getPinnedBlocks() {
    return _blocks.where((b) => _pinnedBlocks.contains(b.cid.toString())).toList();
  }

  /// Retrieves a block by its CID and updates access time.
  GetBlockResponse getBlock(CIDProto cid) {
    final block = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => BlockProto(),
    );

    if (_blocks.contains(block)) {
      _blockAccessTimes[cid.toString()] = DateTime.now();
    }

    return GetBlockResponse()
      ..block = block
      ..found = _blocks.contains(block);
  }

  /// Starts the garbage collection timer.
  void _startGarbageCollection() {
    _gcTimer?.cancel();
    _gcTimer = Timer.periodic(_gcThreshold, (_) => _performGarbageCollection());
  }

  /// Performs garbage collection on unpinned and unused blocks.
  Future<void> _performGarbageCollection() async {
    final now = DateTime.now();
    final blocksToRemove = <BlockProto>[];

    for (final block in _blocks) {
      final cidStr = block.cid.toString();
      if (!_pinnedBlocks.contains(cidStr)) {
        final lastAccess = _blockAccessTimes[cidStr];
        if (lastAccess != null && 
            now.difference(lastAccess) > _gcThreshold) {
          blocksToRemove.add(block);
          _blockAccessTimes.remove(cidStr);
        }
      }
    }

    _blocks.removeWhere((b) => blocksToRemove.contains(b));
  }

  /// Forces immediate garbage collection.
  Future<void> forceGarbageCollection() async {
    await _performGarbageCollection();
  }

  /// Disposes of the BlockStore and stops garbage collection.
  void dispose() {
    _gcTimer?.cancel();
  }

  @override
  String toString() {
    return 'BlockStore(blocks: ${_blocks.length}, pinned: ${_pinnedBlocks.length})';
  }
}
