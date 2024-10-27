// lib/src/core/data_structures/cid.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_multihash/dart_multihash.dart';

import '../../proto/generated/core/cid.pb.dart'; // Import the generated CID from Protobuf
import 'package:multibase/multibase.dart'; // Multibase encoding package
import '/../src/utils/base58.dart'; // Base58 utility for CIDv0

/// Represents a Content Identifier (CID) in IPFS.
class CID {
  final CIDProto _cidProto;

  CID(this._cidProto);

  /// Creates a CID from the given multihash and codec.
  factory CID.fromBytes(Uint8List multihash, String codec,
      {CIDVersion version = CIDVersion.CID_VERSION_0}) {
    final cidProto = CIDProto()
      ..version = version
      ..multihash = multihash
      ..codec = codec;

    if (version == CIDVersion.CID_VERSION_1) {
      cidProto.multibasePrefix = 'b'; // Default to base32 for CIDv1
    }

    return CID(cidProto);
  }

  /// Creates a CID from the given content, codec, and hashing algorithm.
  /// Automatically generates the multihash from the content using the specified hash algorithm.
  factory CID.fromContent(String codec,
      {CIDVersion version = CIDVersion.CID_VERSION_0,
      String hashType = 'sha2-256', required Uint8List content}) {
    final multihash = _hashContent(content, hashType);
    return CID.fromBytes(multihash, codec, version: version);
  }

  /// Gets the version of the CID.
  CIDVersion get version => _cidProto.version;

  /// Gets the multihash of the CID.
  Uint8List get multihash => Uint8List.fromList(_cidProto.multihash);

  /// Gets the codec used for the CID.
  String get codec => _cidProto.codec;

  /// Gets the multibase prefix used (only applicable for CIDv1).
  String? get multibasePrefix =>
      version == CIDVersion.CID_VERSION_1 ? _cidProto.multibasePrefix : null;

  /// Encodes the CID to a string representation using multibase for CIDv1.
  String encode() {
    if (version == CIDVersion.CID_VERSION_0) {
      return _encodeCIDv0();
    } else if (version == CIDVersion.CID_VERSION_1) {
      return _encodeCIDv1();
    } else {
      throw UnsupportedError("Unsupported CID version: $version");
    }
  }

  /// Encodes CIDv0 to base58 (supports only SHA-256).
  String _encodeCIDv0() {
    final base58Codec = Base58();
    return base58Codec.encode(multihash);
  }

  /// Encodes CIDv1 to multibase (default base32).
  String _encodeCIDv1() {
    if (multibasePrefix == null || multibasePrefix != 'b') {
      throw UnsupportedError('Unsupported multibase prefix: $multibasePrefix');
    }

    // Combine version, multihash, and codec into a single Uint8List
    final cidBytes = Uint8List.fromList([
      _cidVersionToIndex(version),
      ...multihash,
      ...utf8.encode(codec),
    ]);

    return multibaseEncode(Multibase.base32, cidBytes);
  }

  /// Converts the CID to a string representation.
  @override
  String toString() {
    return 'CID(version: $version, multihash: ${base64Encode(multihash)}, codec: $codec, multibasePrefix: $multibasePrefix)';
  }

  /// Helper method to hash content using the specified hashing algorithm.
static Uint8List _hashContent(Uint8List content, String hashType) {
  // Hashing the content using the specified hashType
  MultihashInfo multihashInfo;

  // Specify the hash type that is supported
  String hashName;

  switch (hashType.toLowerCase()) {
    case 'sha2-256':
      hashName = 'sha2-256'; // Use the string directly for encoding
      break;
    case 'sha2-512':
      hashName = 'sha2-512'; // Use the string directly for encoding
      break;
    case 'sha3-256':
      hashName = 'sha3-256'; // Use the string directly for encoding
      break;
    // Add other supported hash types as needed
    default:
      throw UnsupportedError('Unsupported hash type: $hashType');
  }

  // Encode the content using the appropriate hash name
  multihashInfo = Multihash.encode(hashName, content);

  // Return the digest as Uint8List
  return Uint8List.fromList(multihashInfo.digest);
}

  /// Converts the CID instance to a CIDProto message (Protobuf).
  CIDProto toProto() {
    final cidProto = CIDProto()
      ..version = version
      ..multihash = Uint8List.fromList(multihash)
      ..codec = codec;

    if (version == CIDVersion.CID_VERSION_1 && multibasePrefix != null) {
      cidProto.multibasePrefix = multibasePrefix!;
    }

    return cidProto;
  }

  /// Converts a CID version enum to an index for Protobuf.
  int _cidVersionToIndex(CIDVersion version) {
    switch (version) {
      case CIDVersion.CID_VERSION_UNSPECIFIED:
        return 0;
      case CIDVersion.CID_VERSION_0:
        return 1;
      case CIDVersion.CID_VERSION_1:
        return 2;
      default:
        throw UnsupportedError('Unsupported CID version: $version');
    }
  }
  /// Creates a CID from its Protobuf representation.
factory CID.fromProto(CIDProto proto) {
  // Extract multihash from the protobuf and convert to Uint8List
  final Uint8List multihash = Uint8List.fromList(proto.multihash);
  
  // Create a new CIDProto instance with the extracted data
  final cid = CIDProto()
    ..version = proto.version
    ..multihash = multihash
    ..codec = proto.codec;

  // If it's a CIDv1, set the multibasePrefix if it's present
  if (proto.version == CIDVersion.CID_VERSION_1) {
    cid.multibasePrefix = proto.multibasePrefix;
  }

  return CID(cid);
}

}