import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_proto;

// lib/src/core/data_structures/link.dart

/// Represents a link to another node in the IPFS Merkle DAG.
/// Strictly follows the standard IPFS PBLink structure: Name, Hash (CID), Size (Tsize).
class Link {
  final String name;
  final CID cid; 
  final fixnum.Int64 size;
  
  // Standard IPFS Link does not carry metadata, timestamp, or explicit isDirectory flags.
  // These must be resolved by fetching the target node.
  // We keep the class simple to match the spec.

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
