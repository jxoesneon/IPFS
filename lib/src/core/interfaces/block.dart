import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap_pb;

abstract class IBlock {
  Uint8List get data;
  CID get cid;
  int get size;

  BlockProto toProto();
  bitswap_pb.Message_Block toBitswapProto();
  Uint8List toBytes();
  bool validate();
}

abstract class IBlockFactory<T extends IBlock> {
  T fromProto(BlockProto proto);
  T fromBitswapProto(bitswap_pb.Message_Block proto);
  T fromBytes(Uint8List bytes);
  T fromData(Uint8List data, CID cid);
}
