import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap_pb;
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

/// Interface for content-addressed data blocks.
///
/// A block is the fundamental unit of data in IPFS, identified by its CID.
/// Implementations must provide data access, serialization, and validation.
abstract class IBlock {
  /// The raw binary data of this block.
  Uint8List get data;

  /// The content identifier for this block.
  CID get cid;

  /// The size of this block in bytes.
  int get size;

  /// Converts to protobuf format for storage.
  BlockProto toProto();

  /// Converts to Bitswap protocol format.
  bitswap_pb.Message_Block toBitswapProto();

  /// Serializes the block to bytes.
  Uint8List toBytes();

  /// Validates the block's content hash matches its CID.
  ///
  /// This is an async operation as it may require computing the cryptographic hash.
  /// Returns `true` if the hash matches, `false` otherwise.
  Future<bool> validate();
}

/// Factory interface for creating blocks from various sources.
abstract class IBlockFactory<T extends IBlock> {
  /// Creates a block from protobuf format.
  T fromProto(BlockProto proto);

  /// Creates a block from Bitswap protocol format.
  T fromBitswapProto(bitswap_pb.Message_Block proto);

  /// Creates a block from serialized bytes.
  T fromBytes(Uint8List bytes);

  /// Creates a block from raw data and its CID.
  T fromData(Uint8List data, CID cid);
}

