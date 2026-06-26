// src/core/unixfs/unixfs_node.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;

/// Represents a decoded UnixFS node, including its outer DAG-PB container and
/// the inner UnixFS [Data] message when applicable.
class UnixFSNode {
  UnixFSNode._({
    required this.cid,
    required this.data,
    required this.pbNode,
    this.unixfsData,
  });

  /// Decodes a [Block] into a [UnixFSNode].
  ///
  /// Raw blocks are treated as implicit single-block files. DAG-PB blocks are
  /// parsed and, when possible, their inner UnixFS [Data] message is decoded.
  factory UnixFSNode.fromBlock(Block block) {
    dag_pb.PBNode pbNode;
    unixfs_pb.Data? unixfsData;
    if (block.cid.codec == 'raw') {
      pbNode = dag_pb.PBNode();
    } else {
      pbNode = dag_pb.PBNode.fromBuffer(block.data);
      if (pbNode.data.isNotEmpty) {
        try {
          unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
        } catch (_) {
          // Not a valid UnixFS inner message; leave as null.
        }
      }
    }
    return UnixFSNode._(
      cid: block.cid,
      data: block.data,
      pbNode: pbNode,
      unixfsData: unixfsData,
    );
  }

  /// The CID that addresses this node.
  final CID cid;

  /// The serialized block bytes for this node.
  final Uint8List data;

  /// The outer DAG-PB node.
  final dag_pb.PBNode pbNode;

  /// The inner UnixFS [Data] message, or null for raw blocks / non-UnixFS data.
  final unixfs_pb.Data? unixfsData;

  /// True if this node is a file (explicit or raw block).
  bool get isFile =>
      unixfsData?.type == unixfs_pb.Data_DataType.File || cid.codec == 'raw';

  /// True if this node is a plain directory.
  bool get isDirectory => unixfsData?.type == unixfs_pb.Data_DataType.Directory;

  /// True if this node is a symlink.
  bool get isSymlink => unixfsData?.type == unixfs_pb.Data_DataType.Symlink;

  /// True if this node is a HAMT shard.
  bool get isHAMTShard => unixfsData?.type == unixfs_pb.Data_DataType.HAMTShard;

  /// True if this node behaves like a directory for path resolution.
  bool get isDirectoryLike => isDirectory || isHAMTShard;

  /// The serialized size of this node's block.
  int get serializedSize => data.length;

  /// For symlinks, the target path stored in the UnixFS data field.
  String? get symlinkTarget {
    if (!isSymlink) return null;
    return String.fromCharCodes(unixfsData!.data);
  }

  /// For files, the logical file size in bytes.
  int? get fileSize {
    if (!isFile) return null;
    if (cid.codec == 'raw') return data.length;
    return unixfsData?.filesize.toInt();
  }

  /// The HAMT fanout for HAMT shard nodes.
  int get fanout => unixfsData?.fanout.toInt() ?? 0;

  /// The HAMT hash type for HAMT shard nodes.
  int get hashType => unixfsData?.hashType.toInt() ?? 0;
}

/// Fetches a block from the block store by CID and decodes it into a
/// [UnixFSNode].
///
/// Returns null if the block is not found.
Future<UnixFSNode?> unixfsGetNode(IBlockStore store, CID cid) async {
  final response = await store.getBlock(cid.encode());
  if (!response.found) return null;
  final block = Block.fromProto(response.block);
  return UnixFSNode.fromBlock(block);
}

/// Stores a [Block] in the block store.
///
/// Throws a [StateError] if the store reports a failure.
Future<void> unixfsPutBlock(IBlockStore store, Block block) async {
  final response = await store.putBlock(block);
  if (!response.success) {
    throw StateError('Failed to store block ${block.cid}: ${response.message}');
  }
}

/// Returns the [dag_pb.PBLink] named [name] from [links], or null if not found.
dag_pb.PBLink? findLinkByName(List<dag_pb.PBLink> links, String name) {
  for (final link in links) {
    if (link.name == name) return link;
  }
  return null;
}
