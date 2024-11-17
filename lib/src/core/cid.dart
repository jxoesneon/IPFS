// src/core/cid.dart
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';

class CID {
  final IPFSCIDVersion version;
  final List<int> multihash;
  final String codec;
  final String multibasePrefix;

  const CID({
    required this.version,
    required this.multihash,
    required this.codec,
    required this.multibasePrefix,
  });

  IPFSCIDProto toProto() {
    return IPFSCIDProto()
      ..version = version
      ..multihash.addAll(multihash)
      ..codec = codec
      ..multibasePrefix = multibasePrefix;
  }

  static CID fromProto(IPFSCIDProto proto) {
    return CID(
      version: proto.version,
      multihash: proto.multihash,
      codec: proto.codec,
      multibasePrefix: proto.multibasePrefix,
    );
  }

  static CID fromBytes(Uint8List bytes, String codec) {
    // Implementation for converting bytes to CID
    return CID(
      version: IPFSCIDVersion.IPFS_CID_VERSION_1,
      multihash: bytes.toList(),
      codec: codec,
      multibasePrefix: 'base58btc',
    );
  }

  static CID fromContent(String codec, {required Uint8List content}) {
    return CID(
      version: IPFSCIDVersion.IPFS_CID_VERSION_1,
      multihash: content.toList(),
      codec: codec,
      multibasePrefix: 'base58btc',
    );
  }

  String encode() {
    final bytes = BytesBuilder();
    bytes.addByte(_versionToIndex(version));
    bytes.add(multihash);
    return EncodingUtils.toBase58(bytes.toBytes());
  }

  int _versionToIndex(IPFSCIDVersion version) {
    switch (version) {
      case IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED:
        return 0;
      case IPFSCIDVersion.IPFS_CID_VERSION_0:
        return 1;
      case IPFSCIDVersion.IPFS_CID_VERSION_1:
        return 2;
      default:
        throw UnsupportedError('Unsupported CID version: $version');
    }
  }

  /// Computes a CID for the given data using the specified codec
  static Future<CID> computeForData(Uint8List data,
      {String codec = 'raw'}) async {
    // Compute SHA-256 hash of the data
    final hash = sha256.convert(data);
    final multihash = [
      0x12,
      hash.bytes.length,
      ...hash.bytes
    ]; // 0x12 is SHA-256 identifier

    return CID(
      version: IPFSCIDVersion.IPFS_CID_VERSION_1,
      multihash: multihash,
      codec: codec,
      multibasePrefix: 'base58btc',
    );
  }

  /// Synchronous version of computeForData
  static CID computeForDataSync(Uint8List data, {String codec = 'raw'}) {
    final hash = sha256.convert(data);
    final multihash = [0x12, hash.bytes.length, ...hash.bytes];

    return CID(
      version: IPFSCIDVersion.IPFS_CID_VERSION_1,
      multihash: multihash,
      codec: codec,
      multibasePrefix: 'base58btc',
    );
  }

  /// Converts CID to bytes for network transmission
  Uint8List toBytes() {
    final bytes = BytesBuilder();
    bytes.addByte(_versionToIndex(version));
    bytes.add(multihash);
    return bytes.toBytes();
  }

  static CID decode(String cidStr) {
    // Convert the CID string to bytes using Base58 decoding
    final bytes = EncodingUtils.fromBase58(cidStr);

    // First byte is the version
    final versionIndex = bytes[0];
    IPFSCIDVersion version;
    switch (versionIndex) {
      case 0:
        version = IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED;
        break;
      case 1:
        version = IPFSCIDVersion.IPFS_CID_VERSION_0;
        break;
      case 2:
        version = IPFSCIDVersion.IPFS_CID_VERSION_1;
        break;
      default:
        throw ArgumentError('Invalid CID version index: $versionIndex');
    }

    // The rest of the bytes are the multihash
    final multihash = bytes.sublist(1);

    // Create and return a new CID
    return CID(
      version: version,
      multihash: multihash,
      codec: 'raw', // Default to raw codec
      multibasePrefix: 'base58btc',
    );
  }

  static CID fromString(String cidStr) {
    // Convert the CID string to bytes using Base58 decoding
    final bytes = EncodingUtils.fromBase58(cidStr);

    // First byte is the version
    final versionIndex = bytes[0];
    IPFSCIDVersion version;
    switch (versionIndex) {
      case 0:
        version = IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED;
        break;
      case 1:
        version = IPFSCIDVersion.IPFS_CID_VERSION_0;
        break;
      case 2:
        version = IPFSCIDVersion.IPFS_CID_VERSION_1;
        break;
      default:
        throw ArgumentError('Invalid CID version index: $versionIndex');
    }

    // The second byte is the codec type
    final codecType = bytes[1];
    final codec = EncodingUtils.getCodecFromCode(codecType);

    // The rest of the bytes are the multihash
    final multihash = bytes.sublist(2);

    return CID(
      version: version,
      multihash: multihash,
      codec: codec,
      multibasePrefix: 'base58btc',
    );
  }
}
