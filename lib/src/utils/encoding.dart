// src/utils/encoding.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'
    show IPFSCIDVersion;

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
      // Check multibase prefix
      final prefix = String.fromCharCode(bytes[0]);
      if (!isValidMultibasePrefix(prefix)) {
        return false;
      }

      // Skip multibase prefix for remaining validation
      final cidBytes = bytes.sublist(1);
      if (cidBytes.length < 2) return false;

      final version = cidBytes[0];
      if (version > 2) return false;

      // For CIDv0, validate specific format
      if (version == 0) {
        return _isValidCIDv0(cidBytes);
      }

      // For CIDv1, validate multicodec format
      final multihashLength = cidBytes[1];
      if (cidBytes.length < multihashLength + 2) return false;

      // Validate multihash format
      if (multihashLength < 2) return false;
      final hashFunction = cidBytes[2];
      if (!_isSupportedHashFunction(hashFunction)) return false;

      // Validate hash length matches the expected length for the hash function
      final hashLength = cidBytes[3];
      if (!_isValidHashLength(hashFunction, hashLength)) return false;
      if (hashLength != multihashLength - 2) return false;

      if (version == 2 && cidBytes.length < 4) {
        return false;
      }

      return true;
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
        .firstWhere((entry) => entry.value == prefix,
            orElse: () => const MapEntry('', ''))
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
              'Unsupported codec code: 0x${code.toRadixString(16)}'),
        )
        .key;
    return codec;
  }

  /// Add public getter
  static List<String> get supportedCodecs => _supportedCodecs.keys.toList();
}
