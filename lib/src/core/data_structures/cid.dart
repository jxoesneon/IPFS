import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'; // Import the generated CID from Protobuf

// lib/src/core/data_structures/cid.dart

/// A protobuf-backed Content Identifier (CID) for storage operations.
///
/// This class wraps an [IPFSCIDProto] to provide a Dart-friendly API
/// for working with CIDs in storage contexts. It supports CIDv1 format
/// with various IPLD codecs.
///
/// Unlike the core [CID] class which handles encoding/decoding,
/// [StorageCID] is optimized for serialization and storage operations.
///
/// Supported codecs:
/// - `raw` (0x55): Raw binary data
/// - `dag-pb` (0x70): DAG-PB (Protocol Buffers)
/// - `dag-cbor` (0x71): DAG-CBOR
/// - `dag-json` (0x129): DAG-JSON
///
/// Example:
/// ```dart
/// final multihash = Uint8List.fromList([...]);
/// final storageCid = StorageCID.fromBytes(multihash, 'dag-pb');
/// final proto = storageCid.toProto();  // For serialization
/// ```
///
/// See also:
/// - [CID] for the main CID implementation
/// - [IPFSCIDProto] for the underlying protobuf message
class StorageCID {
  final IPFSCIDProto _proto;

  /// Creates a StorageCID wrapping the given protobuf message.
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
