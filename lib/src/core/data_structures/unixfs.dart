// lib/src/core/data_structures/unixfs.dart

import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../../proto/generated/unixfs/unixfs.pb.dart' as proto;

/// Represents a UnixFS node in IPFS.
class UnixFS {
  final UnixFSType type;
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
  factory UnixFS.fromProto(proto.UnixFS pbUnixFS) {
    return UnixFS(
      type: _unixFSTypeFromProto(pbUnixFS.type),
      data: Uint8List.fromList(pbUnixFS.data),
      blockSize: pbUnixFS.blockSize.toInt(),
      fileSize: pbUnixFS.fileSize.toInt(),
      blocksizes: List<int>.from(pbUnixFS.blocksizes),
    );
  }

  /// Converts the [UnixFS] to its Protobuf representation.
  proto.UnixFS toProto() {
    return proto.UnixFS()
      ..type = _unixFSTypeToProto(type)
      ..data = data
      ..blockSize = fixnum.Int64(blockSize)
      ..fileSize = fixnum.Int64(fileSize)
      ..blocksizes.addAll(blocksizes);
  }

  @override
  String toString() {
    return 'UnixFS(type: $type, blockSize: $blockSize, fileSize: $fileSize, blocksizes: $blocksizes)';
  }

  /// Converts a [proto.UnixFSTypeProto] to a [UnixFSType].
  static UnixFSType _unixFSTypeFromProto(proto.UnixFSTypeProto protoType) {
    switch (protoType) {
      case proto.UnixFSTypeProto.FILE:
        return UnixFSType.FILE;
      case proto.UnixFSTypeProto.DIRECTORY:
        return UnixFSType.DIRECTORY;
      default:
        throw ArgumentError('Unknown UnixFS type in protobuf: $protoType');
    }
  }

  /// Converts a [UnixFSType] to a [proto.UnixFSTypeProto].
  static proto.UnixFSTypeProto _unixFSTypeToProto(UnixFSType type) {
    switch (type) {
      case UnixFSType.FILE:
        return proto.UnixFSTypeProto.FILE;
      case UnixFSType.DIRECTORY:
        return proto.UnixFSTypeProto.DIRECTORY;
      default:
        throw ArgumentError('Unknown UnixFS type: $type');
    }
  }
}

/// Enum representing the different types of UnixFS nodes.
enum UnixFSType {
  FILE,
  DIRECTORY,
}