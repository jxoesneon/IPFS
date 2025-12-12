import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_proto;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs_proto;
import 'package:dart_ipfs/src/core/cid.dart';

// lib/src/core/data_structures/merkle_dag_node.dart

/// Represents a Merkle DAG node in IPFS (DAG-PB + UnixFS).
/// This wrapper handles the serialization/deserialization of the standard Protobuf formats.
class MerkleDAGNode {
  final List<Link> links;
  final Uint8List data;
  final bool isDirectory;
  final int? mtime; // UnixFS modification time

  MerkleDAGNode({
    required this.links,
    required this.data,
    this.isDirectory = false,
    this.mtime,
  });

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
        links: pbNode.links
            .map((link) => Link.fromProto(link))
            .toList(),
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
    final pbNode = dag_proto.PBNode()
      ..data = data;
    
    pbNode.links.addAll(links.map((link) => link.toProto()));

    return pbNode.writeToBuffer();
  }

  @override
  String toString() {
    return 'MerkleDAGNode(links: ${links.length}, len(data): ${data.length}, isDirectory: $isDirectory)';
  }
}
