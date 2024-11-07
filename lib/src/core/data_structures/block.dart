import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap_pb;
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/core/interfaces/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';

class Block implements IBlock {
  @override
  final Uint8List data;

  @override
  final CID cid;

  const Block(this.data, this.cid);

  factory Block.fromProto(BlockProto proto) {
    return Block(
      Uint8List.fromList(proto.data),
      CID.fromProto(proto.cid),
    );
  }

  factory Block.fromBitswapProto(bitswap_pb.Block proto) {
    return Block(
      Uint8List.fromList(proto.data),
      CID.fromBytes(Uint8List.fromList(proto.prefix), 'raw'),
    );
  }

  factory Block.fromBytes(Uint8List bytes) {
    final cidLength = bytes[0];
    final cidBytes = bytes.sublist(1, cidLength + 1);
    final data = bytes.sublist(cidLength + 1);
    final cid = CID.fromBytes(cidBytes, 'raw');
    return Block(data, cid);
  }

  factory Block.fromData(Uint8List data, CID cid) {
    return Block(data, cid);
  }

  @override
  int get size => data.length;

  @override
  BlockProto toProto() {
    return BlockProto()
      ..data = data
      ..cid = cid.toProto()
      ..format = 'raw';
  }

  @override
  bitswap_pb.Block toBitswapProto() {
    return bitswap_pb.Block()
      ..prefix = EncodingUtils.cidToBytes(cid)
      ..data = data;
  }

  @override
  Uint8List toBytes() {
    final bytes = BytesBuilder();
    final cidBytes = EncodingUtils.cidToBytes(cid);
    bytes.addByte(cidBytes.length);
    bytes.add(cidBytes);
    bytes.add(data);
    return bytes.toBytes();
  }

  @override
  bool validate() {
    try {
      // Verify that the block's CID matches its content
      final computedCid = CID.fromContent(
        'raw',
        content: data,
      );
      return computedCid.encode() == cid.encode();
    } catch (e) {
      print('Block validation error: $e');
      return false;
    }
  }
}

class BlockFactory implements IBlockFactory<Block> {
  @override
  Block fromProto(BlockProto proto) {
    return Block(
      Uint8List.fromList(proto.data),
      CID.fromProto(proto.cid),
    );
  }

  @override
  Block fromBitswapProto(bitswap_pb.Block proto) {
    return Block(
      Uint8List.fromList(proto.data),
      CID.fromBytes(Uint8List.fromList(proto.prefix), 'dag-pb'),
    );
  }

  @override
  Block fromBytes(Uint8List bytes) {
    if (bytes.length < 3) {
      throw FormatException('Invalid block bytes: too short');
    }

    final cidLength = bytes[0];
    if (bytes.length < cidLength + 2) {
      throw FormatException('Invalid block bytes: incomplete CID');
    }

    final cidBytes = bytes.sublist(1, cidLength + 1);
    final blockData = bytes.sublist(cidLength + 1);
    final cid = CID.fromBytes(cidBytes, 'dag-pb');

    return Block(blockData, cid);
  }

  @override
  Block fromData(Uint8List data, CID cid) {
    return Block(data, cid);
  }
}
