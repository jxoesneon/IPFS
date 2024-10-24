import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';
import 'block.dart';
import 'cid.dart';
import 'proto/blockstore.pb.dart'; // Import the generated BlockStoreProto
import 'proto/block.pb.dart';       // Import the generated BlockProto
import 'proto/cid.pb.dart';         // Import the generated CIDProto

/// Represents a block store that manages blocks.
class BlockStore {
  final List<BlockProto> _blocks = []; // Internal list to store blocks

  /// Adds a block to the store.
  AddBlockResponse addBlock(BlockProto block) {
    _blocks.add(block);
    return AddBlockResponse()
      ..success = true
      ..message = "Block added successfully.";
  }

  /// Retrieves a block by its CID.
  GetBlockResponse getBlock(CIDProto cid) {
    final block = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => null,
    );

    if (block != null) {
      return GetBlockResponse()
        ..block = block
        ..found = true;
    } else {
      return GetBlockResponse()
        ..found = false;
    }
  }

  /// Removes a block from the store by its CID.
  RemoveBlockResponse removeBlock(CIDProto cid) {
    final blockToRemove = _blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => null,
    );

    if (blockToRemove != null) {
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
