import 'dart:typed_data';
import 'package:base58/base58.dart';
import '../core/data_structures/cid.dart';
import '../proto/generated/core/cid.pb.dart';

class EncodingUtils {
  static final Base58 _base58 = Base58();

  /// Encode bytes to Base58 string
  static String toBase58(Uint8List data) {
    return _base58.encode(data);
  }

  /// Decode Base58 string to bytes
  static Uint8List fromBase58(String encoded) {
    return _base58.decode(encoded);
  }

  /// Convert CID to bytes representation
  static Uint8List cidToBytes(CID cid) {
    final bytes = BytesBuilder();
    bytes.addByte(_cidVersionToIndex(cid.version));
    bytes.add(cid.multihash);
    return bytes.toBytes();
  }

  /// Convert version enum to index
  static int _cidVersionToIndex(CIDVersion version) {
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

  /// Validate CID bytes
  static bool isValidCIDBytes(Uint8List bytes) {
    if (bytes.length < 2) return false;

    try {
      final version = bytes[0];
      if (version > 2) return false;

      final multihashLength = bytes[1];
      if (bytes.length < multihashLength + 2) return false;

      // Validate multihash format
      if (multihashLength < 2) return false;
      final hashFunction = bytes[2];
      final hashLength = bytes[3];
      if (hashLength != multihashLength - 2) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert CID version index to enum
  static CIDVersion indexToCidVersion(int index) {
    switch (index) {
      case 0:
        return CIDVersion.CID_VERSION_UNSPECIFIED;
      case 1:
        return CIDVersion.CID_VERSION_0;
      case 2:
        return CIDVersion.CID_VERSION_1;
      default:
        throw UnsupportedError('Unsupported CID version index: $index');
    }
  }

  /// Convert CID version to string representation
  static String cidVersionToString(CIDVersion version) {
    switch (version) {
      case CIDVersion.CID_VERSION_0:
        return 'CIDv0';
      case CIDVersion.CID_VERSION_1:
        return 'CIDv1';
      default:
        return 'Unknown';
    }
  }
}
