import 'package:dart_ipfs/src/core/cid.dart';
import 'package:fixnum/fixnum.dart';

enum IPFSNodeType { file, directory, symlink, unknown }

class IPFSNode {
  final CID cid;
  final List<NodeLink> links;
  final IPFSNodeType nodeType;
  final Map<String, String> metadata;
  final Int64 size;

  IPFSNode({
    required this.cid,
    required this.links,
    required this.nodeType,
    this.metadata = const {},
    required this.size,
  });

  /// Creates a directory node
  factory IPFSNode.directory({
    required CID cid,
    required List<NodeLink> links,
    Map<String, String> metadata = const {},
  }) {
    return IPFSNode(
      cid: cid,
      links: links,
      nodeType: IPFSNodeType.directory,
      metadata: metadata,
      size: Int64(links.fold(0, (sum, link) => sum + link.size.toInt())),
    );
  }
}

class NodeLink {
  final String name;
  final CID cid;
  final Int64 size;
  final Map<String, String> metadata;

  NodeLink({
    required this.name,
    required this.cid,
    required this.size,
    this.metadata = const {},
  });
}
