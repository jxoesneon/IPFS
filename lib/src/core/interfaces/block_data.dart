import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';

abstract class BlockData {
  Uint8List get data;
  CID get cid;

  int get size => data.length;

  Uint8List toBytes() {
    final bytes = BytesBuilder();
    final cidBytes = EncodingUtils.cidToBytes(cid);
    bytes.addByte(cidBytes.length);
    bytes.add(cidBytes);
    bytes.add(data);
    return bytes.toBytes();
  }
}
