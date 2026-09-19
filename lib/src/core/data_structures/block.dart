// src/core/data_structures/block.dart
//
// The canonical [Block] implementation lives in package:dart_ipfs_core and is
// re-exported here so existing `dart_ipfs` imports keep working. This library
// additionally provides the protobuf conversions that cannot live in the core
// package because they depend on dart_ipfs's generated protos.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' show Block;

export 'package:dart_ipfs_core/dart_ipfs_core.dart' show Block;

/// Protobuf serialization helpers for [Block].
extension BlockProtoConversion on Block {
  /// Converts the block to its protobuf representation.
  BlockProto toProto() {
    return BlockProto()
      ..cid = cid.toProto()
      ..data = data
      ..format = format;
  }

  /// Converts the block to its Bitswap protobuf representation.
  proto.Message_Block toBitswapProto() {
    return proto.Message_Block()
      ..data = data
      ..prefix = cid.toBytes();
  }
}

/// Conversion from the protobuf representation to [Block].
extension BlockProtoToBlock on BlockProto {
  /// Creates a [Block] from its protobuf representation.
  Block toBlock() {
    return Block(
      cid: cid.toCID(),
      data: Uint8List.fromList(data),
      format: format,
    );
  }
}

/// Conversion from the Bitswap protobuf representation to [Block].
extension BitswapBlockProtoToBlock on proto.Message_Block {
  /// Creates a [Block] from its Bitswap protobuf representation.
  ///
  /// The CID is recomputed from the block data, matching the historical
  /// behavior of `Block.fromBitswapProto`.
  Future<Block> toBlock() {
    return Block.fromData(Uint8List.fromList(data));
  }
}
