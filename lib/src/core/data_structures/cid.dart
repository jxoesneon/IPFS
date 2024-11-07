import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'; // Import the generated CID from Protobuf

// lib/src/core/data_structures/cid.dart

/// Represents a Content Identifier (CID) in IPFS.
class StorageCID {
  final IPFSCIDProto _proto;

  StorageCID(this._proto);

  static const _supportedCodecs = {
    'raw': 0x55,
    'dag-pb': 0x70,
    'dag-cbor': 0x71,
    'dag-json': 0x129,
  };

  // Getters for accessing proto fields
  IPFSCIDVersion get version => _proto.version;
  List<int> get multihash => _proto.multihash;
  String get codec => _proto.codec;
  String get multibasePrefix => _proto.multibasePrefix;

  IPFSCIDProto toProto() => _proto;

  /// Creates a CID from the given multihash and codec.
  factory StorageCID.fromBytes(Uint8List multihash, String codec) {
    final codecCode = getCodecCode(codec);
    final proto = IPFSCIDProto()
      ..version = IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = multihash
      ..codec = codec
      ..codecType = codecCode
      ..multibasePrefix = 'base58btc';

    return StorageCID(proto);
  }

  factory StorageCID.fromProto(IPFSCIDProto proto) {
    return StorageCID(proto);
  }

  String hashedValue() {
    return hex.encode(multihash);
  }

  static int getCodecCode(String codec) {
    if (!_supportedCodecs.containsKey(codec)) {
      throw ArgumentError('Unsupported codec: $codec');
    }
    return _supportedCodecs[codec]!;
  }
}

extension IPFSCIDProtoExtension on IPFSCIDProto {
  static IPFSCIDProto fromString(String cidStr) {
    return IPFSCIDProto()
      ..multihash = Uint8List.fromList(cidStr.codeUnits)
      ..version = IPFSCIDVersion.IPFS_CID_VERSION_1; // or appropriate version
  }
}
