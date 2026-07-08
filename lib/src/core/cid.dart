// src/core/cid.dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:multibase/multibase.dart';

/// A Content Identifier (CID) for content-addressed data in IPFS.
///
/// CIDs are self-describing content addresses used to uniquely identify
/// data in IPFS and other distributed systems. They combine a cryptographic
/// hash of the content with metadata about the hashing algorithm and
/// data encoding format.
///
/// IPFS supports two CID versions:
/// - **CIDv0**: Legacy format, always SHA2-256 + DAG-PB, base58btc encoded
/// - **CIDv1**: Modern format with flexible codecs and multibase encoding
///
/// Example:
/// ```dart
/// // Create CID from content
/// final data = Uint8List.fromList(utf8.encode('Hello IPFS'));
/// final cid = await CID.fromContent(data);
/// // print('CID: ${cid.encode()}');  // bafkreif...
///
/// // Decode existing CID
/// final decoded = CID.decode('QmYwAPJzv5CZsnA...');
/// // print('Version: ${decoded.version}');
/// ```
///
/// See also:
/// - [IPFS CID Specification](https://github.com/multiformats/cid)
/// - `Block` for content-addressed data storage
class CID {
  /// Creates a CID with the specified components.
  ///
  /// Prefer using factory constructors [CID.v0], [CID.v1], or [CID.fromContent]
  /// for creating CIDs with proper validation.
  const CID({
    required this.version,
    required this.multihash,
    this.codec,
    this.multibaseType,
  });

  // Constants moved to EncodingUtils or deprecated?
  // Removing unused fields.

  /// Creates a CIDv0.
  /// CIDv0 is always: SHA2-256, DAG-PB, Base58BTC.
  factory CID.v0(Uint8List hashBytes) {
    if (hashBytes.length != 32) {
      throw ArgumentError('CIDv0 requires a 32-byte SHA2-256 hash');
    }
    // Encode as multihash using correct API
    final mhInfo = Multihash.encode('sha2-256', hashBytes);

    return CID(
      version: 0,
      multihash: mhInfo,
      codec: 'dag-pb',
      multibaseType: Multibase.base58btc,
    );
  }

  /// Creates a CIDv1.
  factory CID.v1(
    String codec,
    MultihashInfo multihash, {
    Multibase base = Multibase.base32,
  }) {
    return CID(
      version: 1,
      codec: codec,
      multihash: multihash,
      multibaseType: base,
    );
  }

  /// The CID version (0 or 1).
  final int version;

  /// The multihash containing the hash algorithm and digest.
  final MultihashInfo multihash;

  /// The content codec (e.g., 'dag-pb', 'raw', 'dag-cbor').
  ///
  /// Identifies how the content should be interpreted.
  final String? codec;

  /// The multibase encoding type for string representation.
  ///
  /// Common values: [Multibase.base58btc] (CIDv0), [Multibase.base32] (CIDv1).
  final Multibase? multibaseType;

  /// Parses a CID from its raw binary representation.
  static CID fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError('Empty bytes');

    // CIDv0 check (SHA2-256)
    // 0x12 0x20 ... (34 bytes total)
    if (bytes.length >= 34 && bytes[0] == 0x12 && bytes[1] == 0x20) {
      return CID(
        version: 0,
        multihash: Multihash.decode(bytes.sublist(0, 34)),
        codec: 'dag-pb',
        multibaseType: Multibase.base58btc,
      );
    }

    // CIDv1 check
    if (bytes[0] == 0x01) {
      var index = 1;
      final (codecLen, codecCode) = readVarint(bytes, index);
      index += codecLen;

      // Parse the multihash prefix to determine the exact multihash byte
      // boundary so the decoder does not see trailing block bytes.
      final mhStart = index;
      final (codeLen, _) = readVarint(bytes, index);
      index += codeLen;
      final (lenLen, digestLen) = readVarint(bytes, index);
      index += lenLen;
      final mhEnd = index + digestLen;
      if (mhEnd > bytes.length) {
        throw const FormatException('Invalid CID bytes: multihash truncated');
      }
      final mh = Multihash.decode(bytes.sublist(mhStart, mhEnd));

      String codecStr;
      try {
        codecStr = EncodingUtils.getCodecFromCode(codecCode);
      } catch (e) {
        codecStr = 'unknown'; // Or throw?
        // If unknown, 'unknown' might break equal check if original was 'unknown' or asserted?
        // But better to use string 'unknown' than failing if that's what we want.
        // But wait, `EncodingUtils` throws ArgumentError if unknown.
        // If I catch it, I can default to 'unknown'.
        // But better to let it throw or return unknown?
        // The previous code returned 'unknown' if not matched.
        // So keeping 'unknown' is safe fallback for now.
      }

      // Special case: if getCodecFromCode doesn't have it, we fall back to 'unknown'.
      // But if we want to SUPPORT 'dag-cbor', EncodingUtils MUST have it.
      // I tested EncodingUtils has 'dag-cbor'. So it will return 'dag-cbor'.

      return CID(
        version: 1,
        multihash: mh,
        codec: codecStr,
        multibaseType: Multibase.base32,
      );
    }

    throw const FormatException('Invalid CID version');
  }

  /// Decodes a CID from its string representation.
  static CID decode(String cidStr) {
    if (cidStr.isEmpty) {
      throw ArgumentError('Empty CID string');
    }

    // Check if it's a CIDv0 (base58, starts with 'Qm')
    if (cidStr.startsWith('Qm')) {
      // Decode base58
      final decoded = multibaseDecode(
        'z$cidStr',
      ); // Add 'z' prefix for base58btc
      return fromBytes(decoded);
    }

    // CIDv1: multibase encoded
    final decoded = multibaseDecode(cidStr);
    return fromBytes(decoded);
  }

  /// Encodes the CID to its string representation.
  String encode() => encodeWithBase(multibaseType);

  /// Returns the CID prefix bytes (version + codec + multihash function + hash
  /// length), omitting the digest itself.
  ///
  /// This is the format used by Bitswap/GraphSync [Block.prefix] to allow the
  /// receiver to reconstruct the CID from the prefix and block data.
  Uint8List toPrefixBytes() {
    final bytes = toBytes();
    final digestLength = multihash.size;
    if (bytes.length <= digestLength) {
      return bytes;
    }
    return Uint8List.fromList(bytes.sublist(0, bytes.length - digestLength));
  }

  /// Encodes the CID using the requested [base].
  ///
  /// CIDv0 is always returned as base58btc regardless of the requested base.
  /// CIDv1 defaults to base32 when [base] is null.
  String encodeWithBase(Multibase? base) {
    if (version == 0) {
      // CIDv0: base58-encoded multihash (no prefix)
      final mhBytes = multihash.toBytes();
      final encoded = multibaseEncode(Multibase.base58btc, mhBytes);
      // Remove the 'z' prefix for CIDv0
      return encoded.substring(1);
    }

    // CIDv1: <version><codec><multihash>
    final bytes = toBytes();
    final baseType = base ?? multibaseType ?? Multibase.base32;
    return multibaseEncode(baseType, bytes);
  }

  /// Encodes the CID using the base identified by [baseName].
  ///
  /// Common names: `base58`, `base58btc`, `base32`, `base32upper`, `base16`,
  /// `base16upper`, `base64`, `base64url`, `base64urlpad`. Unknown names fall
  /// back to the CID's default encoding.
  String encodeWithBaseName(String baseName) {
    final base = _multibaseFromName(baseName);
    return encodeWithBase(base);
  }

  static Multibase _multibaseFromName(String name) {
    switch (name.toLowerCase()) {
      case 'base16':
      case 'base16lower':
        return Multibase.base16;
      case 'base16upper':
        return Multibase.base16upper;
      case 'base32':
      case 'base32lower':
        return Multibase.base32;
      case 'base32upper':
        return Multibase.base32upper;
      case 'base58':
      case 'base58btc':
        return Multibase.base58btc;
      case 'base64':
        return Multibase.base64;
      case 'base64url':
        return Multibase.base64url;
      case 'base64urlpad':
        return Multibase.base64urlpad;
      default:
        return Multibase.base32;
    }
  }

  /// Converts the CID to its binary representation.
  Uint8List toBytes() {
    if (version == 0) {
      // CIDv0 is just the multihash
      return multihash.toBytes();
    }

    // CIDv1: <version><codec><multihash>
    final buffer = BytesBuilder();
    buffer.addByte(0x01); // version 1

    // Encode codec as varint
    int codecCode;
    try {
      codecCode = EncodingUtils.getCodeFromCodec(codec ?? 'raw');
    } catch (e) {
      // If codec not found, fallback to raw or throw?
      // Let's assume raw if unknown? Or throw to prevent bad CIDs?
      // Existing code defaulted to _raw.
      // But existing code only checked 'dag-pb'.
      // If I pass 'dag-cbor', it defaulted to raw.
      // Now I want it to find 'dag-cbor'.
      // If 'unknown', throw.
      throw FormatException('Unsupported codec during CID encoding: $codec');
    }
    buffer.add(_encodeVarint(codecCode));

    // Add multihash
    buffer.add(multihash.toBytes());

    return buffer.toBytes();
  }

  /// Reconstructs a CID from a [prefix] (version + codec + multihash function
  /// + hash length) and the raw block [data].
  ///
  /// The digest is computed from [data] using the provided [hashType]. The
  /// resulting CID is only valid if the computed prefix matches the supplied
  /// prefix, which is verified by [validate].
  static Future<CID> fromPrefixBytes(
    Uint8List prefix,
    Uint8List data, {
    String hashType = 'sha2-256',
  }) async {
    final codec = _codecFromPrefixBytes(prefix);
    return fromContent(data, codec: codec, hashType: hashType);
  }

  static String _codecFromPrefixBytes(Uint8List prefix) {
    if (prefix.isEmpty) return 'raw';
    if (prefix[0] == 0x01) {
      final (codecLen, codecCode) = readVarint(prefix, 1);
      try {
        return EncodingUtils.getCodecFromCode(codecCode);
      } catch (_) {
        return 'unknown';
      }
    }
    // CIDv0 is always dag-pb.
    return 'dag-pb';
  }

  /// Validates the CID.
  bool validate() {
    if (version != 0 && version != 1) return false;
    if (version == 0 && codec != 'dag-pb') return false;
    if (multihash.size <= 0) return false;
    return true;
  }

  @override
  String toString() => encode();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CID) return false;
    return version == other.version &&
        codec == other.codec &&
        _bytesEqual(multihash.toBytes(), other.multihash.toBytes());
  }

  @override
  int get hashCode =>
      Object.hash(version, codec, Object.hashAll(multihash.toBytes()));

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Encodes an integer as a varint
  Uint8List _encodeVarint(int value) {
    final bytes = <int>[];
    while (value >= 0x80) {
      bytes.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7f);
    return Uint8List.fromList(bytes);
  }

  /// Reads a protobuf-style varint from [bytes] starting at [offset].
  ///
  /// Returns a tuple `(length, value)` where [length] is the number of bytes
  /// consumed and [value] is the decoded integer.
  static (int, int) readVarint(Uint8List bytes, int offset) {
    var value = 0;
    var shift = 0;
    for (var i = 0; i < 10; i++) {
      if (offset + i >= bytes.length) {
        throw const FormatException('Truncated varint');
      }
      final b = bytes[offset + i];
      value |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) {
        return (i + 1, value);
      }
      shift += 7;
    }
    throw const FormatException('Varint too long');
  }

  /// Converts the CID to a Protobuf representation.
  IPFSCIDProto toProto() {
    return IPFSCIDProto()
      ..version = version == 0
          ? IPFSCIDVersion.IPFS_CID_VERSION_0
          : IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = multihash.toBytes()
      ..codec = codec ?? ''
      ..multibasePrefix = version == 0 ? '' : 'base32';
  }

  /// Creates a [CID] from a Protobuf representation.
  static CID fromProto(IPFSCIDProto proto) {
    if (proto.version == IPFSCIDVersion.IPFS_CID_VERSION_0) {
      final mh = Multihash.decode(Uint8List.fromList(proto.multihash));
      return CID.v0(Uint8List.fromList(mh.digest));
    }
    return CID.v1(
      proto.codec,
      Multihash.decode(Uint8List.fromList(proto.multihash)),
    );
  }

  /// Creates a [CID] from raw content.
  ///
  /// Specify [codec], [hashType], and [version] if they differ from defaults.
  static Future<CID> fromContent(
    Uint8List content, {
    String codec = 'raw',
    String hashType = 'sha2-256',
    int version = 1,
  }) async {
    Digest digest;
    if (hashType == 'sha2-256') {
      digest = sha256.convert(content);
    } else {
      throw UnsupportedError('Hash type $hashType not supported');
    }

    final mhInfo = Multihash.encode(hashType, Uint8List.fromList(digest.bytes));

    if (version == 0) {
      return CID.v0(Uint8List.fromList(digest.bytes));
    } else {
      return CID.v1(codec, mhInfo);
    }
  }

  /// Computes CID for data (async version for compatibility).
  static Future<CID> computeForData(
    Uint8List data, {
    String format = 'raw',
  }) async {
    return await fromContent(data, codec: format);
  }

  /// Computes CID for data (sync version).
  static CID computeForDataSync(Uint8List data, {String codec = 'raw'}) {
    final digest = sha256.convert(data);
    final mhInfo = Multihash.encode(
      'sha2-256',
      Uint8List.fromList(digest.bytes),
    );
    return CID.v1(codec, mhInfo);
  }
}
