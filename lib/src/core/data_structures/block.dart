import 'dart:typed_data';
import 'base_block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/interfaces/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;

/// Represents a block of data in IPFS
class Block extends BaseBlock implements IBlock {
  final String format;

  const Block._({
    required CID cid,
    required Uint8List data,
    required this.format,
  }) : super(data, cid);

  /// Creates a new block from raw data
  static Future<Block> fromData(Uint8List data, {String format = 'raw'}) async {
    final cid = await CID.computeForData(data, codec: format);
    return Block._(
      cid: cid,
      data: data,
      format: format,
    );
  }

  /// Creates a block from bytes using BaseBlock's fromBytes method
  static Block fromBytes(Uint8List bytes) {
    return BaseBlock.fromBytes<Block>(
      bytes,
      (data, cid) => Block._(
        data: data,
        cid: cid,
        format: 'dag-pb', // Default format for fromBytes
      ),
    );
  }

  @override
  int get size => data.length;

  /// Converts the block to its protobuf representation
  @override
  BlockProto toProto() {
    return BlockProto()
      ..cid = cid.toProto()
      ..data = data
      ..format = format;
  }

  /// Creates a block from its protobuf representation
  static Block fromProto(BlockProto proto) {
    return Block._(
      cid: CID.fromProto(proto.cid),
      data: Uint8List.fromList(proto.data),
      format: proto.format,
    );
  }

  /// Creates a block from its Bitswap protobuf representation
  static Block fromProtoBlock(proto.Block protoBlock) {
    return Block._(
        cid: CID.fromBytes(Uint8List.fromList(protoBlock.prefix), 'raw'),
        data: Uint8List.fromList(protoBlock.data),
        format: 'raw');
  }

  /// Validates the block's data against its CID
  @override
  bool validate() {
    final computedCid = CID.computeForDataSync(data, codec: format);
    return computedCid == cid;
  }

  static Block fromBitswapProto(proto.Block protoBlock) {
    return Block._(
        cid: CID.fromBytes(Uint8List.fromList(protoBlock.prefix), 'raw'),
        data: Uint8List.fromList(protoBlock.data),
        format: 'raw');
  }

  @override
  proto.Block toBitswapProto() {
    return proto.Block()
      ..prefix = cid.toBytes()
      ..data = data;
  }
}
