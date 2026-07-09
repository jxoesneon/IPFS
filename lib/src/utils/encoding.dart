// src/utils/encoding.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'
    show IPFSCIDVersion;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/varint.dart';

/// Utility class for encoding and decoding IPFS data
class EncodingUtils {
  static final Base58 _base58 = Base58();

  /// Supported hash functions according to multiformats table
  /// https://github.com/multiformats/multicodec/blob/master/table.csv
  static const Map<int, int> _supportedHashFunctions = {
    0x12: 32, // sha2-256 (32 bytes)
    0x13: 64, // sha2-512 (64 bytes)
    0xb220: 32, // blake2b-256 (32 bytes)
    0xb260: 32, // blake2s-256 (32 bytes)
    0x16: 32, // sha3-256 (32 bytes)
    0x14: 64, // sha3-512 (64 bytes)
    0x1012: 32, // sha2-256-trunc254-padded
    0x1052: 32, // sha2-512-256
    0x1b: 32, // keccak-256
  };

  /// Supported multibase prefixes according to the multibase spec
  /// https://github.com/multiformats/multibase
  static const Map<String, String> _supportedMultibasePrefixes = {
    'base16': 'f',
    'base32': 'b',
    'base58btc': 'z',
    'base64': 'm',
    'base64url': 'u',
    'base32hex': 'v',
    'base36': 'k',
    'base58flickr': 'Z',
    'identity': '\x00',
    'base32pad': 'c',
    'base32hexpad': 't',
    'base32z': 'h',
    'base64pad': 'M',
    'proquint': 'p',
  };

  /// Encode bytes to Base58 string with multibase prefix
  static String toBase58(Uint8List data) {
    // Add 'z' prefix for base58btc encoding
    return 'z${_base58.encode(data)}';
  }

  /// Decode Base58 string to bytes with multibase prefix validation
  static Uint8List fromBase58(String encoded) {
    if (encoded.isEmpty) {
      throw ArgumentError('Empty string');
    }

    // Extract and validate multibase prefix
    final prefix = encoded[0];
    if (!isValidMultibasePrefix(prefix)) {
      throw ArgumentError('Invalid multibase prefix: $prefix');
    }

    // For base58btc ('z' prefix), decode the rest
    if (prefix == 'z') {
      return _base58.base58Decode(encoded.substring(1));
    }

    // For other encodings, throw unsupported error
    final encoding = getEncodingFromPrefix(prefix);
    throw UnsupportedError('Unsupported multibase encoding: $encoding');
  }

  /// Convert CID to bytes representation
  static Uint8List cidToBytes(CID cid) {
    // Use the CID class's built-in toBytes method
    return cid.toBytes();
  }

  /// Validate CID bytes according to IPFS spec
  static bool isValidCIDBytes(Uint8List bytes) {
    if (bytes.isEmpty) return false;

    try {
      // CIDv0 check (SHA2-256)
      // Starts with 0x12 0x20 (SHA2-256, 32 bytes digest)
      if (bytes.length == 34 && bytes[0] == 0x12 && bytes[1] == 0x20) {
        return _isValidCIDv0(bytes);
      }

      // CIDv1 check
      // Starts with version 1 (0x01)
      if (bytes[0] == 0x01) {
        // Parse Codec (varint)
        var offset = 1; // Skip version byte
        if (bytes.length <= offset) return false;

        final codecInfo = decodeVarint(bytes.sublist(offset));
        offset += codecInfo.$2;

        // Parse Multihash
        if (bytes.length <= offset) return false;

        // Parse Multihash Code (varint)
        final hashFunctionInfo = decodeVarint(bytes.sublist(offset));
        final hashFunction = hashFunctionInfo.$1;
        offset += hashFunctionInfo.$2;

        // Parse Multihash Length (varint)
        if (bytes.length <= offset) return false;
        final hashLengthInfo = decodeVarint(bytes.sublist(offset));
        final hashLength = hashLengthInfo.$1;
        offset += hashLengthInfo.$2;

        // Validate hash function support
        if (!_isSupportedHashFunction(hashFunction)) return false;

        // Validate hash length matches the expected length for the hash function
        if (!_isValidHashLength(hashFunction, hashLength)) return false;

        // Check if remaining bytes match hash length
        if (bytes.length - offset != hashLength) return false;

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validate CIDv0 format (specific to SHA2-256)
  static bool _isValidCIDv0(Uint8List bytes) {
    if (bytes.length != 34) return false; // Fixed length for CIDv0
    if (bytes[0] != 0x12) return false; // Must use SHA2-256
    if (bytes[1] != 32) return false; // Must be 32 bytes
    return true;
  }

  /// Check if hash function is supported and validate its length
  static bool _isValidHashLength(int hashFunction, int length) {
    final expectedLength = _supportedHashFunctions[hashFunction];
    return expectedLength != null && length == expectedLength;
  }

  /// Check if the hash function is supported
  static bool _isSupportedHashFunction(int hashFunction) {
    return _supportedHashFunctions.containsKey(hashFunction);
  }

  /// Convert CID version index to enum
  static IPFSCIDVersion indexToCidVersion(int index) {
    switch (index) {
      case 0:
        return IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED;
      case 1:
        return IPFSCIDVersion.IPFS_CID_VERSION_0;
      case 2:
        return IPFSCIDVersion.IPFS_CID_VERSION_1;
      default:
        throw UnsupportedError('Unsupported CID version index: $index');
    }
  }

  /// Validates if a multibase prefix is supported according to the multibase spec
  static bool isValidMultibasePrefix(String prefix) {
    return _supportedMultibasePrefixes.containsValue(prefix);
  }

  /// Gets the encoding name from a multibase prefix
  static String? getEncodingFromPrefix(String prefix) {
    return _supportedMultibasePrefixes.entries
        .firstWhere(
          (entry) => entry.value == prefix,
          orElse: () => const MapEntry('', ''),
        )
        .key;
  }

  static const _supportedCodecs = {
    // Core IPFS codecs
    'raw': 0x55, // Raw binary
    'dag-pb': 0x70, // DAG Protocol Buffer
    'dag-cbor': 0x71, // DAG CBOR
    'libp2p-key': 0x72, // Libp2p key
    'dag-json': 0x0129, // DAG JSON
    'dag-jose': 0x85, // DAG JOSE
    'dag-cose': 0x012b, // DAG COSE
    'car': 0x0202, // Content Addressable aRchive
    // IPFS namespace codecs
    'ipld-ns': 0x300, // IPLD namespace
    'ipfs-ns': 0x301, // IPFS namespace
    'ipns-ns': 0x302, // IPNS namespace
    // Identity codec
    'identity': 0x00, // Raw identity
  };

  /// Get codec string from code number
  static String getCodecFromCode(int code) {
    // Reverse lookup in _supportedCodecs
    final codec = _supportedCodecs.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => throw ArgumentError(
            'Unsupported codec code: 0x${code.toRadixString(16)}',
          ),
        )
        .key;
    return codec;
  }

  static const _base32LowerAlphabet = 'abcdefghijklmnopqrstuvwxyz234567';

  /// Encodes [data] to a lowercase, unpadded RFC 4648 base32 string.
  static String base32LowerEncode(Uint8List data) {
    if (data.isEmpty) return '';
    final result = StringBuffer();
    var i = 0;
    final full = (data.length ~/ 5) * 5;
    while (i < full) {
      final v1 = data[i++];
      final v2 = data[i++];
      final v3 = data[i++];
      final v4 = data[i++];
      final v5 = data[i++];
      result.write(_base32LowerAlphabet[v1 >> 3]);
      result.write(_base32LowerAlphabet[(v1 << 2 | v2 >> 6) & 31]);
      result.write(_base32LowerAlphabet[(v2 >> 1) & 31]);
      result.write(_base32LowerAlphabet[(v2 << 4 | v3 >> 4) & 31]);
      result.write(_base32LowerAlphabet[(v3 << 1 | v4 >> 7) & 31]);
      result.write(_base32LowerAlphabet[(v4 >> 2) & 31]);
      result.write(_base32LowerAlphabet[(v4 << 3 | v5 >> 5) & 31]);
      result.write(_base32LowerAlphabet[v5 & 31]);
    }

    final remain = data.length - full;
    if (remain == 0) return result.toString();

    final v1 = data[i];
    result.write(_base32LowerAlphabet[v1 >> 3]);
    if (remain == 1) {
      result.write(_base32LowerAlphabet[(v1 << 2) & 31]);
      return result.toString();
    }

    final v2 = data[i + 1];
    result.write(_base32LowerAlphabet[(v1 << 2 | v2 >> 6) & 31]);
    result.write(_base32LowerAlphabet[(v2 >> 1) & 31]);
    if (remain == 2) {
      result.write(_base32LowerAlphabet[(v2 << 4) & 31]);
      return result.toString();
    }

    final v3 = data[i + 2];
    result.write(_base32LowerAlphabet[(v2 << 4 | v3 >> 4) & 31]);
    result.write(_base32LowerAlphabet[(v3 << 1) & 31]);
    if (remain == 3) return result.toString();

    final v4 = data[i + 3];
    result.write(_base32LowerAlphabet[(v3 << 1 | v4 >> 7) & 31]);
    result.write(_base32LowerAlphabet[(v4 >> 2) & 31]);
    result.write(_base32LowerAlphabet[(v4 << 3) & 31]);
    return result.toString();
  }

  /// Decodes a lowercase, unpadded RFC 4648 base32 string to bytes.
  static Uint8List base32LowerDecode(String encoded) {
    if (encoded.isEmpty) return Uint8List(0);
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (var i = 0; i < encoded.length; i++) {
      final c = encoded[i];
      final value = _base32LowerAlphabet.indexOf(c);
      if (value < 0) {
        throw FormatException('Invalid base32 character: $c');
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xFF);
      }
    }
    return Uint8List.fromList(out);
  }

  /// Get code number from codec string
  static int getCodeFromCodec(String codec) {
    final code = _supportedCodecs[codec];
    if (code == null) {
      throw ArgumentError('Unsupported codec: $codec');
    }
    return code;
  }

  /// Add public getter
  static List<String> get supportedCodecs => _supportedCodecs.keys.toList();
}
