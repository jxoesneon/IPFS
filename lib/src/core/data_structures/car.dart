// lib/src/core/data_structures/car.dart

import 'dart:typed_data';
import '/../src/proto/dht/car.pb.dart'; // Import the generated Protobuf file
import '../data_structures/block.dart';

/// Represents a Content Addressable Archive (CAR).
class CAR {
  final List<Block> blocks;

  CAR(this.blocks);

  /// Serializes the CAR to bytes for storage or transmission.
  Uint8List toBytes() {
    final carProto = CarProto();
    for (var block in blocks) {
      carProto.blocks
          .add(block.toProto()); // Assuming Block has a toProto method
    }
    return carProto.writeToBuffer();
  }

  /// Deserializes a CAR from bytes.
  static CAR fromBytes(Uint8List data) {
    final carProto = CarProto.fromBuffer(data);
    final blocks =
        carProto.blocks.map((pbBlock) => Block.fromProto(pbBlock)).toList();
    return CAR(blocks);
  }

  /// Adds a block to the CAR.
  void addBlock(Block block) {
    blocks.add(block);
  }

  /// Retrieves a block by its CID.
  Block? getBlock(String cid) {
    for (var block in blocks) {
      if (block.cid.encode() == cid) {
        return block;
      }
    }
    return null;
  }
}
