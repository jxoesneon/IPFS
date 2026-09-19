// src/core/cid.dart
//
// The canonical [CID] implementation lives in package:dart_ipfs_core and is
// re-exported here so existing `dart_ipfs` imports keep working. This library
// additionally provides the protobuf conversions that cannot live in the core
// package because they depend on dart_ipfs's generated protos.
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' show CID;
import 'package:dart_multihash/dart_multihash.dart';

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
