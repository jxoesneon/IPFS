// lib/src/core/data_structures/block.dart
import 'dart:typed_data';
import 'package:multibase/multibase.dart'; // Import multibase for decoding
import 'package:dart_multihash/dart_multihash.dart'; // Import multihash for decoding
import '../../proto/generated/core/block.pb.dart';  // Correct path for BlockProto
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
      // 1. Decode using multibaseDecode:
      final decodedCid = multibaseDecode(String.fromCharCodes(bytes));
      print(decodedCid);

      // 2. Create the MultihashInfo:
      final multihashInfo = Multihash.decode(decodedCid);

      // 3. Create the CID:
      final cid = CID.fromBytes(Uint8List.fromList(multihashInfo.digest), 'dag-pb'); // Convert to Uint8List

      // 4. Extract block data (after the encoded CID):
      final encodedCidLength = bytes.length; // Calculate length
      final blockData = bytes.sublist(encodedCidLength);

      return Block(blockData, cid);
    } catch (e) {
      throw Exception('CIDExtractionException: Failed to extract CID from bytes: $e');
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