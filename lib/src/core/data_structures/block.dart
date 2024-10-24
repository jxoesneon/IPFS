import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';
import '/../src/proto/dht/block.pb.dart';
import 'cid.dart'; // Import for handling CIDs

/// Represents a Block in the IPFS network.
/// A block consists of raw binary data and a corresponding CID.
class Block {
  // The binary data of the block
  final Uint8List data;

  // The CID (Content Identifier) for the block, generated using the data
  final CID cid;

  // Constructor to initialize the Block with its data and CID
  Block(this.data, this.cid);

  /// Creates a Block from raw data. The CID will be generated from the data.
  factory Block.fromData(Uint8List data, CID cid) {
    return Block(data, cid);
  }

  /// Serializes the Block to a .proto message.
  BlockProto toProto() {
    final blockProto = BlockProto();
    blockProto.data = data;
    blockProto.cid = cid.toProto(); // Assuming CID has a toProto() method.
    return blockProto;
  }

  /// Deserializes a Block from a .proto message.
  factory Block.fromProto(BlockProto proto) {
    final cid = CID.fromProto(proto.cid); // Assuming CID can be deserialized.
    return Block(proto.data, cid);
  }

  /// Returns the size of the block's data in bytes.
  int size() {
    return data.length;
  }

  @override
  String toString() {
    return 'Block{cid: $cid, size: ${size()} bytes}';
  }
}
