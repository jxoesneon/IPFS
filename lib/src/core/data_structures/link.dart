import 'dart:typed_data';
import 'package:multibase/multibase.dart';
import 'package:murmurhash/murmurhash.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_multihash/dart_multihash.dart';
import '../../proto/generated/core/link.pb.dart' as proto;
// lib/src/core/data_structures/link.dart

/// Represents a link to another node in the IPFS Merkle DAG with trickle-dag and HAMT support.
class Link {
  final String name;
  final Uint8List cid;
  final Uint8List hash;
  final fixnum.Int64 size;
  final Map<String, String>? metadata;
  final int timestamp;
  final bool isDirectory;
  final LinkType type;
  final int? bucketIndex;
  final int? depth;

  Link({
    required this.name,
    required this.cid,
    required Uint8List hash,
    required int size,
    this.metadata,
    int? timestamp,
    this.isDirectory = false,
    this.type = LinkType.DIRECT,
    this.bucketIndex,
    this.depth,
  })  : hash = hash,
        size = fixnum.Int64(size),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch {
    _validateCid(cid);
    _validateHash(hash);
    _validateSize(size);
    _validateHamtBucket();
    _validateTrickleDepth();
  }

  /// Creates a HAMT bucket link
  factory Link.hamtBucket({
    required String name,
    required Uint8List cid,
    required Uint8List hash,
    required int size,
    required int bucketIndex,
  }) {
    return Link(
      name: name,
      cid: cid,
      hash: hash,
      size: size,
      type: LinkType.HAMT,
      bucketIndex: bucketIndex,
    );
  }

  /// Creates a trickle-dag link
  factory Link.trickle({
    required String name,
    required Uint8List cid,
    required Uint8List hash,
    required int size,
    required int depth,
  }) {
    return Link(
      name: name,
      cid: cid,
      hash: hash,
      size: size,
      type: LinkType.TRICKLE,
      depth: depth,
    );
  }

  void _validateHamtBucket() {
    if (type == LinkType.HAMT && bucketIndex == null) {
      throw ArgumentError('HAMT links must have a bucket index');
    }
    if (bucketIndex != null && (bucketIndex! < 0 || bucketIndex! > 255)) {
      throw ArgumentError('HAMT bucket index must be between 0 and 255');
    }
  }

  void _validateTrickleDepth() {
    if (type == LinkType.TRICKLE && depth == null) {
      throw ArgumentError('Trickle-dag links must have a depth value');
    }
    if (depth != null && depth! < 0) {
      throw ArgumentError('Trickle-dag depth must be non-negative');
    }
  }

  void _validateCid(Uint8List cid) {
    if (cid.isEmpty) {
      throw ArgumentError('CID cannot be empty');
    }

    try {
      // Use the multibase package's decode function
      final decodedCid = multibaseDecode(String.fromCharCodes(cid));
      final multihashInfo = Multihash.decode(decodedCid);

      if (multihashInfo.digest.isEmpty) {
        throw ArgumentError('Invalid CID: empty multihash digest');
      }
    } catch (e) {
      throw ArgumentError('Invalid CID format: $e');
    }
  }

  void _validateSize(int size) {
    final int64Size = fixnum.Int64(size);
    if (int64Size.isNegative) {
      throw ArgumentError('Size cannot be negative');
    }
  }

  void _validateHash(Uint8List hash) {
    if (hash.isEmpty) {
      throw ArgumentError('Hash cannot be empty');
    }
    try {
      final multihashInfo = Multihash.decode(hash);
      if (multihashInfo.digest.isEmpty) {
        throw ArgumentError('Invalid hash: empty multihash digest');
      }
    } catch (e) {
      throw ArgumentError('Invalid hash format: $e');
    }
  }

  /// Computes HAMT bucket index for a given key
  static int computeHamtBucket(String key, {int bitWidth = 8}) {
    final hash = MurmurHash.v3(key, 0);
    return hash & ((1 << bitWidth) - 1);
  }

  /// Converts the Link to its Protobuf representation with HAMT and trickle-dag support
  proto.PBLink toProto() {
    final pbLink = proto.PBLink()
      ..name = name
      ..cid = Uint8List.fromList(cid)
      ..hash = Uint8List.fromList(hash)
      ..size = size
      ..metadata.addAll(metadata ?? {})
      ..timestamp = fixnum.Int64(timestamp)
      ..isDirectory = isDirectory
      ..type = _linkTypeToProto(type);

    if (bucketIndex != null) {
      pbLink.bucketIndex = bucketIndex!;
    }
    if (depth != null) {
      pbLink.depth = depth!;
    }

    return pbLink;
  }

  /// Creates a Link from its Protobuf representation
  factory Link.fromProto(proto.PBLink pbLink) {
    return Link(
      name: pbLink.name,
      cid: Uint8List.fromList(pbLink.cid),
      hash: Uint8List.fromList(pbLink.hash),
      size: pbLink.size.toInt(),
      metadata: pbLink.metadata.isEmpty
          ? null
          : Map<String, String>.from(pbLink.metadata),
      timestamp: pbLink.timestamp.toInt(),
      isDirectory: pbLink.isDirectory,
      type: _linkTypeFromProto(pbLink.type),
      bucketIndex: pbLink.hasBucketIndex() ? pbLink.bucketIndex : null,
      depth: pbLink.hasDepth() ? pbLink.depth : null,
    );
  }

  static proto.LinkType _linkTypeToProto(LinkType type) {
    switch (type) {
      case LinkType.UNSPECIFIED:
        return proto.LinkType.LINK_TYPE_UNSPECIFIED;
      case LinkType.DIRECT:
        return proto.LinkType.LINK_TYPE_DIRECT;
      case LinkType.HAMT:
        return proto.LinkType.LINK_TYPE_HAMT;
      case LinkType.TRICKLE:
        return proto.LinkType.LINK_TYPE_TRICKLE;
    }
  }

  static LinkType _linkTypeFromProto(proto.LinkType type) {
    switch (type) {
      case proto.LinkType.LINK_TYPE_UNSPECIFIED:
        return LinkType.UNSPECIFIED;
      case proto.LinkType.LINK_TYPE_DIRECT:
        return LinkType.DIRECT;
      case proto.LinkType.LINK_TYPE_HAMT:
        return LinkType.HAMT;
      case proto.LinkType.LINK_TYPE_TRICKLE:
        return LinkType.TRICKLE;
      default:
        throw ArgumentError('Unknown link type: $type');
    }
  }
}

enum LinkType {
  UNSPECIFIED, // Add unspecified type
  DIRECT, // Regular direct link
  HAMT, // HAMT bucket link
  TRICKLE, // Trickle-dag link
}
