import 'dart:typed_data';
import 'package:multibase/multibase.dart'; // Import multibase for decoding
import 'package:dart_multihash/dart_multihash.dart'; // Import multihash for decoding
import '/../src/proto/dht/block.pb.dart';  // Correct path for BlockProto
import 'cid.dart';  // Import for handling CIDs

/// Represents a Block in the IPFS network.
/// A block consists of raw binary data and a corresponding CID (Content Identifier).
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

  /// Factory constructor to create a Block from raw bytes.
  factory Block.fromBytes(Uint8List bytes) {
    try {
      // Assume that the first part of bytes contains the CID in multibase format
      final cidLength = bytes[0]; // Example: first byte indicates length of CID
      final cidBytes = bytes.sublist(1, cidLength + 1);
      
      // Decode the CID using multibase and multihash libraries
      final decodedCid = Multibase.decode(Uint8List.fromList(cidBytes));
      final multihash = Multihash.fromBytes(decodedCid);

      // Create a CID instance from decoded multihash
      final cid = CID.fromBytes(multihash.digest, 'dag-pb');

      // Extract block data after CID
      final blockData = bytes.sublist(cidLength + 1);

      return Block(blockData, cid);
    } catch (e) {
      throw Exception('CIDExtractionException: Failed to extract CID from bytes');
    }
  }

  /// Serializes the Block to a Protobuf message for transmission or storage.
  BlockProto toProto() {
    final blockProto = BlockProto()
      ..data = data
      ..cid = cid.toProto();  // Serializes CID to its Protobuf representation
    return blockProto;
  }

  /// Deserializes a Block from a Protobuf message.
  factory Block.fromProto(BlockProto proto) {
    final cid = CID.fromProto(proto.cid);  // Deserializes CID from Protobuf
    return Block(Uint8List.fromList(proto.data), cid);  // Convert data
  }

  /// Returns the size of the block's data in bytes.
  int size() => data.length;

  @override
  String toString() {
    return 'Block{cid: $cid, size: ${size()} bytes}';
  }
}