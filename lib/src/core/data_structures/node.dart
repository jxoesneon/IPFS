import 'cid.dart';
import 'link.dart';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import '../../proto/generated/core/node.pb.dart';
import '../../proto/generated/core/node_type.pbenum.dart';

/// Represents a node in the IPFS Merkle DAG.
class Node {
  /// The content identifier of the node
  final CID cid;
  
  /// Links to other nodes
  final List<Link> links;
  
  /// Raw data stored in the node
  final Uint8List data;
  
  /// Type of the node
  final NodeTypeProto type;
  
  /// Size of the node in bytes
  final Int64 size;
  
  /// Timestamp of the node's last modification
  final Int64 timestamp;
  
  /// Additional metadata associated with the node
  final Map<String, String> metadata;

  /// Creates a new [Node] instance.
  Node({
    required this.cid,
    this.links = const [],
    Uint8List? data,
    this.type = NodeTypeProto.NODE_TYPE_UNSPECIFIED,
    Int64? size,
    Int64? timestamp,
    this.metadata = const {},
  })  : data = data ?? Uint8List(0),
        size = size ?? Int64(0),
        timestamp = timestamp ?? Int64(DateTime.now().millisecondsSinceEpoch);

  /// Creates a [Node] from its Protobuf representation.
  factory Node.fromProto(NodeProto proto) {
    return Node(
      cid: CID.fromProto(proto.cid),
      links: proto.links.map((link) => Link.fromProto(link)).toList(),
      data: Uint8List.fromList(proto.data),
      type: proto.type,
      size: proto.size,
      timestamp: proto.timestamp,
      metadata: Map<String, String>.from(proto.metadata),
    );
  }

  /// Converts the [Node] to its Protobuf representation.
  NodeProto toProto() => NodeProto()
    ..cid = cid.toProto()
    ..links.addAll(links.map((link) => link.toProto()))
    ..data = data
    ..type = type
    ..size = size
    ..timestamp = timestamp
    ..metadata.addAll(metadata);

  /// Creates a file node with the given [cid], [data], and [metadata].
  factory Node.file({
    required CID cid,
    required Uint8List data,
    Map<String, String> metadata = const {},
  }) {
    return Node(
      cid: cid,
      data: data,
      type: NodeTypeProto.NODE_TYPE_FILE,
      metadata: metadata,
      size: Int64(data.length),
    );
  }

  /// Creates a directory node with the given [cid], [links], and [metadata].
  factory Node.directory({
    required CID cid,
    required List<Link> links,
    Map<String, String> metadata = const {},
  }) {
    return Node(
      cid: cid,
      links: links,
      type: NodeTypeProto.NODE_TYPE_DIRECTORY,
      metadata: metadata,
      size: Int64(links.fold(0, (sum, link) => sum + link.size.toInt())),
    );
  }

  /// Adds a [link] to the node if it's a directory node.
  /// 
  /// Throws a [StateError] if the node is not a directory.
  Node addLink(Link link) {
    if (type != NodeTypeProto.NODE_TYPE_DIRECTORY) {
      throw StateError('Can only add links to directory nodes');
    }

    return Node(
      cid: cid,
      links: [...links, link],
      type: type,
      metadata: metadata,
      size: size + link.size,
      timestamp: timestamp,
    );
  }

  /// Removes a link with the given [name] from the node if it's a directory node.
  /// 
  /// Throws a [StateError] if the node is not a directory.
  /// Throws an [ArgumentError] if the link is not found.
  Node removeLink(String name) {
    if (type != NodeTypeProto.NODE_TYPE_DIRECTORY) {
      throw StateError('Can only remove links from directory nodes');
    }

    final linkToRemove = links.firstWhere(
      (link) => link.name == name,
      orElse: () => throw ArgumentError('Link not found: $name'),
    );

    return Node(
      cid: cid,
      links: links.where((link) => link.name != name).toList(),
      type: type,
      metadata: metadata,
      size: size - linkToRemove.size,
      timestamp: timestamp,
    );
  }

  /// Gets a link by [name].
  /// 
  /// Returns null if the link is not found.
  Link? getLink(String name) {
    try {
      return links.firstWhere((link) => link.name == name);
    } on StateError {
      return null;
    }
  }

  /// Updates the node's metadata with [newMetadata].
  Node updateMetadata(Map<String, String> newMetadata) {
    return Node(
      cid: cid,
      links: links,
      data: data,
      type: type,
      size: size,
      timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
      metadata: {...metadata, ...newMetadata},
    );
  }

  @override
  String toString() => 'Node(cid: $cid, type: $type, size: $size, links: ${links.length})';
}
