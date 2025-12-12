// src/core/cid.dart
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:multibase/multibase.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';

/// Represents a Content Identifier (CID).
///
/// Follows the IPFS CID specification: https://github.com/multiformats/cid
class CID {
  final int version;
  final MultihashInfo multihash;
  final String? codec; // Codec name or identifier (e.g. 'dag-pb', 'raw')
  final Multibase? multibaseType; // e.g. Multibase.base58btc, Multibase.base32

  const CID({
    required this.version,
    required this.multihash,
    this.codec,
    this.multibaseType,
  });

  /// 0x12 is sha2-256
  /// 0x70 is dag-pb
  static const int _dag_pb = 0x70;
  /// 0x55 is raw
  static const int _raw = 0x55;

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
  factory CID.v1(String codec, MultihashInfo multihash, {Multibase base = Multibase.base32}) {
    return CID(
      version: 1,
      codec: codec,
      multihash: multihash,
      multibaseType: base,
    );
  }

  /// Parses a CID from its raw binary representation.
  static CID fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError('Empty bytes');
    
    // CIDv0 check (SHA2-256)
    // 0x12 0x20 ... (34 bytes total)
    if (bytes.length == 34 && bytes[0] == 0x12 && bytes[1] == 0x20) {
      return CID(
        version: 0,
        multihash: Multihash.decode(bytes),
        codec: 'dag-pb',
        multibaseType: Multibase.base58btc,
      );
    }
    
    // CIDv1 check
    if (bytes[0] == 0x01) {
       int index = 1;
       int codecCode = 0;
       int shift = 0;
       while (true) {
         if (index >= bytes.length) throw FormatException('Invalid CID bytes');
         int byte = bytes[index++];
         codecCode |= (byte & 0x7f) << shift;
         if ((byte & 0x80) == 0) break;
         shift += 7;
       }
       
       final mh = Multihash.decode(bytes.sublist(index));
       
       String codecStr = 'unknown';
       if (codecCode == _dag_pb) codecStr = 'dag-pb';
       if (codecCode == _raw) codecStr = 'raw';
       
       return CID(
         version: 1,
         multihash: mh,
         codec: codecStr,
         multibaseType: Multibase.base32, 
       );
    }
    
    throw FormatException('Invalid CID version');
  }

  /// Decodes a CID from its string representation.
  static CID decode(String cidStr) {
    if (cidStr.isEmpty) {
      throw ArgumentError('Empty CID string');
    }

    // Check if it's a CIDv0 (base58, starts with 'Qm')
   if (cidStr.startsWith('Qm')) {
      // Decode base58
      final decoded = multibaseDecode('z$cidStr'); // Add 'z' prefix for base58btc
      return fromBytes(decoded);
    }

    // CIDv1: multibase encoded
    final decoded = multibaseDecode(cidStr);
    return fromBytes(decoded);
  }

  /// Encodes the CID to its string representation.
  String encode() {
    if (version == 0) {
      // CIDv0: base58-encoded multihash (no prefix)
      final mhBytes = multihash.toBytes();
      final encoded = multibaseEncode(Multibase.base58btc, mhBytes);
      // Remove the 'z' prefix for CIDv0
      return encoded.substring(1);
    }

    // CIDv1: <version><codec><multihash>
    final bytes = toBytes();
    final baseType = multibaseType ?? Multibase.base32;
    return multibaseEncode(baseType, bytes);
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
    int codecCode = _raw; // default
    if (codec == 'dag-pb') codecCode = _dag_pb;
    buffer.add(_encodeVarint(codecCode));
    
    // Add multihash
    buffer.add(multihash.toBytes());
    
    return buffer.toBytes();
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
      version.hashCode ^ codec.hashCode ^ multihash.toBytes().hashCode;

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
  IPFSCIDProto toProto() {
    return IPFSCIDProto()
      ..version = version == 0 ? IPFSCIDVersion.IPFS_CID_VERSION_0 : IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = multihash.toBytes()
      ..codec = codec ?? ''
      ..multibasePrefix = version == 0 ? '' : 'base32';
  }

  static CID fromProto(IPFSCIDProto proto) {
    if (proto.version == IPFSCIDVersion.IPFS_CID_VERSION_0) {
      return CID.v0(Uint8List.fromList(proto.multihash));
    }
    return CID.v1(
      proto.codec,
      Multihash.decode(Uint8List.fromList(proto.multihash)),
    );
  }
  static Future<CID> fromContent(Uint8List content, {
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
  static Future<CID> computeForData(Uint8List data, {String format = 'raw'}) async {
    return await fromContent(data, codec: format);
  }

  /// Computes CID for data (sync version).
  static CID computeForDataSync(Uint8List data, {String codec = 'raw'}) {
    final digest = sha256.convert(data);
    final mhInfo = Multihash.encode('sha2-256', Uint8List.fromList(digest.bytes));
    return CID.v1(codec, mhInfo);
  }


}
