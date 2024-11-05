import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../../proto/generated/unixfs/unixfs.pbenum.dart';
import '../../proto/generated/unixfs/unixfs.pb.dart' as proto;
// lib/src/core/data_structures/unixfs.dart


/// Represents a UnixFS node in IPFS.
class UnixFS {
  final UnixFSTypeProto type;
  final Uint8List data;
  final int blockSize;
  final int fileSize;
  final List<int> blocksizes;

  UnixFS({
    required this.type,
    required this.data,
    required this.blockSize,
    required this.fileSize,
    required this.blocksizes,
  });

  /// Creates a [UnixFS] from its Protobuf representation.
  factory UnixFS.fromProto(proto.UnixFSProto pbUnixFS) {
    return UnixFS(
      type: pbUnixFS.type,
      data: Uint8List.fromList(pbUnixFS.data),
      blockSize: pbUnixFS.blockSize.toInt(),
      fileSize: pbUnixFS.fileSize.toInt(),
      blocksizes: List<int>.from(pbUnixFS.blocksizes),
    );
  }

  /// Converts the [UnixFS] to its Protobuf representation.
  proto.UnixFSProto toProto() {
    return proto.UnixFSProto()
      ..type = type
      ..data = data
      ..blockSize = fixnum.Int64(blockSize)
      ..fileSize = fixnum.Int64(fileSize)
      ..blocksizes.addAll(blocksizes);
  }

  @override
  String toString() {
    return 'UnixFS(type: $type, blockSize: $blockSize, fileSize: $fileSize, blocksizes: $blocksizes)';
  }
}
