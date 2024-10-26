// lib/src/core/data_structures/node.dart

import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import '/../src/proto/dht/node.pb.dart'
    as proto; // Import the generated Protobuf file
import '/../src/proto/dht/node_type.pbenum.dart';
import 'cid.dart'; // Use the CID class for handling CIDs
import 'link.dart'; // Use the Link class for handling links
import 'node_type.dart'; // Use the NodeType enum

/// Represents a node in the IPFS Merkle DAG.
class Node {
  final CID cid; // Use CID class
  final List<Link> links;
  final Uint8List data;
  final NodeType type;
  final int size;
  final int timestamp;
  final Map<String, String> metadata;

  Node({
    required this.cid,
    required this.links,
    required this.data,
    required this.type,
    required this.size,
    required this.timestamp,
    required this.metadata,
  });

  /// Creates a [Node] from its Protobuf representation.
  static Node fromProto(proto.Node pbNode) {
    return Node(
      cid: CID.fromProto(pbNode.cid),
      links: pbNode.links.map((link) => Link.fromProto(link)).toList(),
      data: Uint8List.fromList(pbNode.data), // Ensure data is copied
      type: NodeTypeExtension.fromName(pbNode.type.name),
      size: pbNode.size.toInt(),
      timestamp: pbNode.timestamp.toInt(),
      metadata: Map<String, String>.from(pbNode.metadata),
    );
  }

  /// Converts the [Node] to its Protobuf representation.
  proto.Node toProto() {
    final pbNode = proto.Node()
      ..cid = cid.toProto()
      ..data = data
      ..type = NodeTypeProto.valueOf(type.index)! // Corrected line
      ..size = fixnum.Int64(size)
      ..timestamp = fixnum.Int64(timestamp);

    pbNode.links.addAll(links.map((link) => link.toProto()));
    pbNode.metadata.addAll(metadata);

    return pbNode;
  }

  /// Converts the [Node] to a byte array (Uint8List).
  Uint8List toBytes() {
    return toProto()
        .writeToBuffer(); // Serialize using Protobuf's writeToBuffer method
  }

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'links': links,
      'size': size,
      'timestamp': timestamp,
      'metadata': metadata,
      'cid': cid,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'Node(cid: $cid, type: $type, size: $size, timestamp: $timestamp, metadata: $metadata)';
  }
}
