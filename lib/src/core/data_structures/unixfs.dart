import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:protobuf/protobuf.dart';
import '/../src/proto/unixfs/unixfs.pb.dart' as unixfs;

/// Represents a UnixFS data structure in IPFS.
class UnixFSData {
  final unixfs.DataType type;
  final Uint8List data;
  final int filesize;
  final List<int> blocksizes;
  final int hashType;
  final int fanout;
  final int mode;
  final UnixTime mtime;

  /// Creates a new [UnixFSData] instance.
  UnixFSData({
    required this.type,
    required this.data,
    required this.filesize,
    required this.blocksizes,
    required this.hashType,
    required this.fanout,
    required this.mode,
    required this.mtime,
  });

  /// Creates a [UnixFSData] from its byte representation.
  static UnixFSData fromBytes(Uint8List bytes) {
    try {
      // Deserialize the Protobuf data
      final pbData = unixfs.Data.fromBuffer(bytes);
      return UnixFSData(
        type: pbData.type,
        data: pbData.data,
        filesize: pbData.filesize.toInt(),
        blocksizes: pbData.blocksizes.map((e) => e.toInt()).toList(),
        hashType: pbData.hashType.toInt(),
        fanout: pbData.fanout.toInt(),
        mode: pbData.mode.toInt(),
        mtime: UnixTime.fromProto(pbData.mtime),
      );
    } catch (e) {
      throw FormatException('Failed to parse UnixFSData from bytes: $e');
    }
  }

  /// Converts the [UnixFSData] to its byte representation.
  Uint8List toBytes() {
    // Create a Protobuf Data object
    final pbData = unixfs.Data()
      ..type = type
      ..data = data
      ..filesize = fixnum.Int64(filesize)
      ..blocksizes.addAll(blocksizes.map((e) => fixnum.Int64(e)))
      ..hashType = fixnum.Int64(hashType)
      ..fanout = fixnum.Int64(fanout)
      ..mode = mode
      ..mtime = mtime.toProto();

    return pbData.writeToBuffer();
  }

  @override
  String toString() {
    return 'UnixFSData(type: $type, filesize: $filesize, blocksizes: $blocksizes, hashType: $hashType, fanout: $fanout, mode: $mode, mtime: $mtime)';
  }
}

/// Represents a Unix timestamp with optional fractional nanoseconds.
class UnixTime {
  final int seconds;
  final int fractionalNanoseconds;

  /// Creates a new [UnixTime] instance.
  UnixTime({
    required this.seconds,
    required this.fractionalNanoseconds,
  });

  /// Creates a [UnixTime] from its Protobuf representation.
  static UnixTime fromProto(unixfs.UnixTime proto) {
    return UnixTime(
      seconds: proto.seconds.toInt(),
      fractionalNanoseconds: proto.fractionalNanoseconds,
    );
  }

  /// Converts the [UnixTime] to its Protobuf representation.
  unixfs.UnixTime toProto() {
    return unixfs.UnixTime()
      ..seconds = fixnum.Int64(seconds)
      ..fractionalNanoseconds = fractionalNanoseconds;
  }

  @override
  String toString() {
    return 'UnixTime(seconds: $seconds, fractionalNanoseconds: $fractionalNanoseconds)';
  }
}
