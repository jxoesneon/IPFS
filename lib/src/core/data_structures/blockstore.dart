// lib/src/core/data_structures/blockstore.dart
import '/../src/proto/dht/blockstore.pb.dart'; // Import the generated BlockStoreProto
import '/../src/proto/dht/block.pb.dart';       // Import the generated BlockProto
import '/../src/proto/dht/cid.pb.dart';         // Import the generated CIDProto

/// Represents a block store that manages blocks.
class BlockStore {
  final List<BlockProto> _blocks = []; // Internal list to store blocks

  /// Adds a block to the store.
  AddBlockResponse addBlock(BlockProto block) {
    if (_blocks.any((b) => b.cid == block.cid)) {
      return AddBlockResponse()
        ..success = false
        ..message = "Block already exists.";
    }

    _blocks.add(block);
    return AddBlockResponse()
      ..success = true
      ..message = "Block added successfully.";
  }

  /// Retrieves a block by its CID.
  GetBlockResponse getBlock(CIDProto cid) {
    final block = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => BlockProto(),
    );

    return GetBlockResponse()
      ..block = block
      ..found = _blocks.contains(block); // Check if block is in the list
  }

  /// Removes a block from the store by its CID.
  RemoveBlockResponse removeBlock(CIDProto cid) {
    final blockToRemove = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => BlockProto(),
    );

    if (_blocks.contains(blockToRemove)) { // Check if block is in the list
      _blocks.remove(blockToRemove);
      return RemoveBlockResponse()
        ..success = true
        ..message = "Block removed successfully.";
    } else {
      return RemoveBlockResponse()
        ..success = false
        ..message = "Block not found.";
    }
  }

  /// Retrieves all blocks in the store.
  List<BlockProto> getAllBlocks() {
    return List.unmodifiable(_blocks);
  }
}
