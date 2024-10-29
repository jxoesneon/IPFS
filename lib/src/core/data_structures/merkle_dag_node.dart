// lib/src/core/data_structures/merkle_dag_node.dart

import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/core/link.pb.dart' as proto_l;
import '/../src/proto/generated/dht/merkle_dag_node.pb.dart' as proto_m;
import 'package:fixnum/fixnum.dart' as fixnum;
import 'link.dart';
import 'cid.dart';
/// Represents a Merkle DAG node in IPFS.
class MerkleDAGNode {
  final CID cid; // Use CID class
  final List<Link> links;
  final Uint8List data;
  final int size;
  final int timestamp;
  final Map<String, String> metadata;
  final bool isDirectory;
  final CID? parentCid; // Use CID class

  MerkleDAGNode({
    required this.cid,
    required this.links,
    required this.data,
    required this.size,
    required this.timestamp,
    required this.metadata,
    this.isDirectory = false,
    this.parentCid,
  });

  /// Creates a [MerkleDAGNode] from its byte representation.
  static MerkleDAGNode fromBytes(Uint8List bytes) {
    try {
      final pbNode = proto_m.MerkleDAGNode.fromBuffer(bytes);

      return MerkleDAGNode(
        cid: CID.fromProto(pbNode.cid),
        links: pbNode.links
            .whereType<proto_l.PBLink>() // Filter to only include PBLink objects
            .map((link) => Link.fromProto(link))
            .toList(),

        data: Uint8List.fromList(pbNode.data), // Ensure data is copied
        size: pbNode.size.toInt(),
        timestamp: pbNode.timestamp.toInt(),
        metadata: Map<String, String>.from(pbNode.metadata),
        isDirectory: pbNode.isDirectory,
        parentCid: pbNode.hasParentCid() ? CID.fromProto(pbNode.parentCid) : null,
      );
    } catch (e) {
      throw FormatException('Failed to parse MerkleDAGNode from bytes: $e');
    }
  }

  /// Converts the [MerkleDAGNode] to its byte representation.
  Uint8List toBytes() {
    final pbNode = proto_m.MerkleDAGNode()
      ..cid = cid.toProto()
      ..data = data
      ..size = fixnum.Int64(size)
      ..timestamp = fixnum.Int64(timestamp)
      ..isDirectory = isDirectory;

    if (parentCid != null) {
      pbNode.parentCid = parentCid!.toProto();
    }

    pbNode.links.addAll(links.map((link) => link.toProto()));
    pbNode.metadata.addAll(metadata);

    return pbNode.writeToBuffer();
  }

  @override
  String toString() {
    return 'MerkleDAGNode(cid: $cid, size: $size, timestamp: $timestamp, isDirectory: $isDirectory, metadata: $metadata)';
  }
}
