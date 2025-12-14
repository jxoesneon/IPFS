import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_proto;

// lib/src/core/data_structures/link.dart

/// A directed link between nodes in the IPFS Merkle DAG.
///
/// Links are the edges in IPFS's content-addressed graph structure,
/// connecting parent nodes to their children. Each link contains:
/// - A [name] identifying the link within its parent
/// - A [cid] pointing to the target node's content
/// - A [size] representing the cumulative size of the linked subgraph
///
/// This class strictly follows the IPFS PBLink protobuf specification.
/// Note that metadata like timestamps or directory flags must be resolved
/// by fetching the target node.
///
/// Example:
/// ```dart
/// final link = Link(
///   name: 'readme.md',
///   cid: fileCid,
///   size: 1024,
/// );
///
/// // Links in a directory listing
/// for (final link in node.links) {
///   print('${link.name}: ${link.cid}');
/// }
/// ```
///
/// See also:
/// - [MerkleDAGNode] for the node structure containing links
/// - [CID] for content identifiers
class Link {
  /// The name of this link within its parent node.
  ///
  /// For UnixFS directories, this is the filename or subdirectory name.
  final String name;

  /// The content identifier of the linked target node.
  final CID cid;

  /// The cumulative size of the linked subgraph in bytes.
  ///
  /// For files, this is the file size. For directories, this includes
  /// all descendant nodes recursively.
  final fixnum.Int64 size;

  // Standard IPFS Link does not carry metadata, timestamp, or explicit isDirectory flags.
  // These must be resolved by fetching the target node.
  // We keep the class simple to match the spec.

  /// Creates a new link with the given [name], [cid], and [size].
  Link({
    required this.name,
    required this.cid,
    required int size,
  }) : size = fixnum.Int64(size);

  /// Creates a Link from a standard PBLink proto.
  factory Link.fromProto(dag_proto.PBLink proto) {
    // Hash in PBLink is strictly a CID (multihash or multibase bytes)
    CID cid;
    try {
      cid = CID.fromBytes(Uint8List.fromList(proto.hash));
    } catch (_) {
      // Fallback for empty or invalid hashes
      cid = CID.v0(Uint8List(32));
    }

    return Link(
      name: proto.name,
      cid: cid,
      size: proto.size.toInt(),
    );
  }

  dag_proto.PBLink toProto() {
    return dag_proto.PBLink()
      ..name = name
      ..hash = cid.toBytes() // Assuming CID has toBytes()
      ..size = size;
  }
}
