import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_proto;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_proto;
import 'package:dart_ipfs/src/core/cid.dart';

// lib/src/core/data_structures/merkle_dag_node.dart

/// A node in the IPFS Merkle DAG (Directed Acyclic Graph).
///
/// The Merkle DAG is the fundamental data structure in IPFS, where each
/// node is identified by its content hash ([cid]) and can link to other
/// nodes via [links]. This enables:
/// - Content-addressable storage
/// - Deduplication across the network
/// - Cryptographic verification of data integrity
///
/// This class handles DAG-PB (protobuf) format with UnixFS data interpretation,
/// automatically detecting directories and extracting metadata.
///
/// Example:
/// ```dart
/// // Parse a node from bytes
/// final node = MerkleDAGNode.fromBytes(rawBytes);
/// print('Is directory: ${node.isDirectory}');
/// print('Has ${node.links.length} children');
///
/// // Access linked content
/// for (final link in node.links) {
///   print('  ${link.name}: ${link.cid}');
/// }
/// ```
///
/// See also:
/// - [Link] for the edge structure
/// - [CID] for content identifiers
/// - [UnixFS spec](https://github.com/ipfs/specs/blob/main/UNIXFS.md)
class MerkleDAGNode {
  /// The list of links (edges) to child nodes.
  final List<Link> links;

  /// The raw data payload of this node.
  ///
  /// For UnixFS nodes, this contains serialized UnixFS metadata.
  /// For raw nodes, this contains the actual file content.
  final Uint8List data;

  /// Whether this node represents a directory.
  ///
  /// Determined by parsing the UnixFS data type.
  final bool isDirectory;

  /// Unix modification time in seconds, if available.
  final int? mtime;

  /// Creates a new MerkleDAGNode with the given components.
  MerkleDAGNode({
    required this.links,
    required this.data,
    this.isDirectory = false,
    this.mtime,
  });

  /// The content identifier for this node.
  ///
  /// Computed from the DAG-PB serialized form of this node.
  CID get cid => CID.computeForDataSync(toBytes(), codec: 'dag-pb');

  /// Creates a [MerkleDAGNode] from its byte representation (DAG-PB).
  /// Automatically inspects inner data to determine if it's a UnixFS Directory.
  static MerkleDAGNode fromBytes(Uint8List bytes) {
    try {
      final pbNode = dag_proto.PBNode.fromBuffer(bytes);

      bool isDir = false;
      int? mtime;

      // Try parsing UnixFS Data
      if (pbNode.hasData()) {
        try {
          final unixData = unixfs_proto.Data.fromBuffer(pbNode.data);
          isDir = (unixData.type == unixfs_proto.Data_DataType.Directory ||
              unixData.type == unixfs_proto.Data_DataType.HAMTShard);
          if (unixData.hasMtime()) {
            mtime = unixData.mtime.toInt();
          }
        } catch (_) {
          // Not UnixFS or failed to parse, treat as raw DAG-PB
        }
      }

      return MerkleDAGNode(
        links: pbNode.links.map((link) => Link.fromProto(link)).toList(),
        data: Uint8List.fromList(pbNode.data),
        isDirectory: isDir,
        mtime: mtime,
      );
    } catch (e) {
      throw FormatException('Failed to parse MerkleDAGNode from bytes: $e');
    }
  }

  /// Converts the [MerkleDAGNode] to its byte representation.
  /// Note: This assumes `data` is already strictly formatted (e.g. valid UnixFS Data proto bytes).
  /// If you are building a node, ensure `data` is correct.
  Uint8List toBytes() {
    final pbNode = dag_proto.PBNode()..data = data;

    pbNode.links.addAll(links.map((link) => link.toProto()));

    return pbNode.writeToBuffer();
  }

  @override
  String toString() {
    return 'MerkleDAGNode(links: ${links.length}, len(data): ${data.length}, isDirectory: $isDirectory)';
  }
}
