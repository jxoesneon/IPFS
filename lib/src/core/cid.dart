// src/core/cid.dart
//
// The canonical [CID] implementation lives in package:dart_ipfs_core and is
// re-exported here so existing `dart_ipfs` imports keep working. This library
// additionally provides the protobuf conversions that cannot live in the core
// package because they depend on dart_ipfs's generated protos.
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart'
    show CID, MultibaseUtils, Multicodec, MultihashInfo;
import 'package:dart_multihash/dart_multihash.dart' hide MultihashInfo;

export 'package:dart_ipfs_core/dart_ipfs_core.dart' show CID;

/// Protobuf serialization helpers for [CID].
extension CIDProtoConversion on CID {
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
}

/// Conversion from the protobuf representation to [CID].
extension IPFSCIDProtoConversion on IPFSCIDProto {
  /// Creates a [CID] from its protobuf representation.
  CID toCID() {
    if (version == IPFSCIDVersion.IPFS_CID_VERSION_0) {
      final mh = Multihash.decode(Uint8List.fromList(multihash));
      return CID.v0(Uint8List.fromList(mh.digest));
    }
    return CID.v1(codec, Multihash.decode(Uint8List.fromList(multihash)));
  }
}

/// Decodes [cidStr], tolerating identity multihashes with an empty digest
/// (e.g. the `bafkqaaa` probe CID) which the standard multihash decoder
/// rejects. Returns `null` for invalid input.
CID? tryDecodeCidLenient(String cidStr) {
  try {
    return CID.decode(cidStr);
  } catch (_) {
    // Fall through to the lenient byte-level decode.
  }
  try {
    return tryDecodeCidBytesLenient(MultibaseUtils.decode(cidStr));
  } catch (_) {
    return null;
  }
}

/// Decodes raw CID [bytes] (e.g. a DAG-PB link target), tolerating the
/// zero-length identity multihash shape that [CID.fromBytes] rejects.
/// Returns `null` for invalid input.
CID? tryDecodeCidBytesLenient(List<int> bytes) {
  try {
    return CID.fromBytes(Uint8List.fromList(bytes));
  } catch (_) {
    // Fall through to the lenient identity decode.
  }

  // CIDv1 layout: 0x01 | <codec varint> | 0x00 (identity) | 0x00 (len 0)
  if (bytes.length < 4 || bytes[0] != 0x01) return null;
  var i = 1;
  var codecCode = 0;
  var shift = 0;
  while (true) {
    if (i >= bytes.length) return null;
    final b = bytes[i++];
    codecCode |= (b & 0x7f) << shift;
    if (b & 0x80 == 0) break;
    shift += 7;
    if (shift > 28) return null;
  }
  if (i + 2 != bytes.length) return null;
  if (bytes[i] != 0x00 || bytes[i + 1] != 0x00) return null;
  final codec = Multicodec.supportsByCode(codecCode)
      ? Multicodec.name(codecCode)
      : 'raw';
  return CID.v1(
    codec,
    MultihashInfo(
      code: 0x00,
      name: 'identity',
      digest: Uint8List(0),
      size: 0,
    ),
  );
}
