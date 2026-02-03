import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';

/// Abstract interface for block data access.
///
/// Provides common properties and serialization for block types.
abstract class BlockData {
  /// The raw binary content of this block.
  Uint8List get data;

  /// The content identifier for this block.
  CID get cid;

  /// The size of the data in bytes.
  int get size => data.length;

  /// Serializes the block to a byte array.
  Uint8List toBytes() {
    final bytes = BytesBuilder();
    final cidBytes = EncodingUtils.cidToBytes(cid);
    bytes.addByte(cidBytes.length);
    bytes.add(cidBytes);
    bytes.add(data);
    return bytes.toBytes();
  }
}

