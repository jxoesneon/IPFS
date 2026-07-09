// src/core/unixfs/unixfs_directory.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_errors.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';

/// An entry in a UnixFS directory, carrying the child CID and its cumulative
/// serialized DAG size (Tsize).
class UnixFSDirectoryEntry {
  /// Creates a new directory entry.
  UnixFSDirectoryEntry({
    required this.name,
    required this.cid,
    required this.tsize,
  });

  /// The file or directory name (path segment, no slash).
  final String name;

  /// The CID of the child node.
  final CID cid;

  /// The cumulative serialized size of the child subtree, including the child
  /// block and all descendants.
  final int tsize;

  /// Converts this entry to a DAG-PB link.
  dag_pb.PBLink toLink() {
    return dag_pb.PBLink(
      hash: Uint8List.fromList(cid.toBytes()),
      name: name,
      size: Int64(tsize),
    );
  }
}

/// Builds a UnixFS directory node with correctly-computed cumulative Tsize
/// values and stores it in the block store.
class UnixFSDirectoryBuilder {
  /// Creates a builder with the requested [cidVersion] and [hashType].
  UnixFSDirectoryBuilder({
    this.cidVersion = 0,
    this.hashType = 'sha2-256',
    this.shardThreshold = 0,
  });

  /// CID version to use for the resulting directory block.
  final int cidVersion;

  /// Multihash function to use for the directory block.
  final String hashType;

  /// Threshold at which the directory should be sharded.
  final int shardThreshold;

  /// Builds a directory from the provided [entries].
  ///
  /// Entries are sorted by name for deterministic CID generation. The caller
  /// is responsible for providing accurate [UnixFSDirectoryEntry.tsize] values;
  /// use [computeTsize] to compute them from a block store.
  Future<UnixFSNode> build(
    IBlockStore store,
    List<UnixFSDirectoryEntry> entries,
  ) async {
    final sorted = List<UnixFSDirectoryEntry>.from(entries)
      ..sort((a, b) => a.name.compareTo(b.name));

    final links = <dag_pb.PBLink>[];
    for (final entry in sorted) {
      links.add(entry.toLink());
    }

    final unixFsData = unixfs_pb.Data(type: unixfs_pb.Data_DataType.Directory);
    final pbNode = dag_pb.PBNode(
      data: unixFsData.writeToBuffer(),
      links: links,
    );
    final bytes = pbNode.writeToBuffer();
    final cid = await CID.fromContent(
      bytes,
      codec: 'dag-pb',
      hashType: hashType,
      version: cidVersion,
    );
    final block = Block(cid: cid, data: bytes, format: 'dag-pb');
    await unixfsPutBlock(store, block);
    return UnixFSNode.fromBlock(block);
  }

  /// Builds a directory, automatically sharding when the number of [entries]
  /// exceeds [shardThreshold].
  ///
  /// If [shardThreshold] is zero or the entry count is below the threshold,
  /// a plain directory is returned. Otherwise a HAMT-sharded directory is
  /// built using fanout 256 and the murmur3-x64-64 hash function.
  Future<UnixFSNode> buildAutoSharded(
    IBlockStore store,
    List<UnixFSDirectoryEntry> entries,
  ) async {
    if (shardThreshold <= 0 || entries.length <= shardThreshold) {
      return build(store, entries);
    }
    return UnixFSHAMTBuilder(
      fanout: 256,
      shardThreshold: shardThreshold,
      cidVersion: cidVersion,
      hashType: hashType,
    ).build(store, entries);
  }
}

/// Computes the cumulative serialized size of the UnixFS DAG rooted at [root].
///
/// The size is the sum of the serialized sizes of every block reachable from
/// [root]. Cycles are detected using the current recursion path and reported
/// as [DAGCycleError].
Future<int> computeTsize(
  IBlockStore store,
  CID root, {
  int maxDepth = 100,
  int maxNodes = 100000,
}) async {
  final path = <CID>{};
  var visitedCount = 0;

  Future<int> recurse(CID current, int depth) async {
    if (depth > maxDepth) {
      throw DAGCycleError('Max depth exceeded at CID $current');
    }
    if (path.contains(current)) {
      throw DAGCycleError('DAG cycle detected at CID $current');
    }
    if (visitedCount >= maxNodes) {
      throw DAGCycleError('Max node budget exceeded while computing Tsize');
    }
    visitedCount++;
    path.add(current);

    try {
      final node = await unixfsGetNode(store, current);
      if (node == null) {
        throw PathResolutionError(
          'Block not found while computing Tsize: $current',
        );
      }
      var total = node.serializedSize;
      for (final link in node.pbNode.links) {
        final childCid = CID.fromBytes(Uint8List.fromList(link.hash));
        total += await recurse(childCid, depth + 1);
      }
      return total;
    } finally {
      path.remove(current);
    }
  }

  return recurse(root, 0);
}

/// Creates a UnixFS symlink node pointing to [target] and stores it in the
/// block store.
///
/// The symlink target is stored as UTF-8 bytes in the UnixFS [Data] field with
/// type [Symlink]. Symlink nodes have no links.
Future<UnixFSNode> createSymlink(
  IBlockStore store,
  String target, {
  int cidVersion = 0,
  String hashType = 'sha2-256',
}) async {
  if (target.isEmpty) {
    throw ArgumentError('Symlink target must not be empty');
  }
  final unixFsData = unixfs_pb.Data(
    type: unixfs_pb.Data_DataType.Symlink,
    data: Uint8List.fromList(target.codeUnits),
  );
  final pbNode = dag_pb.PBNode(data: unixFsData.writeToBuffer());
  final bytes = pbNode.writeToBuffer();
  final cid = await CID.fromContent(
    bytes,
    codec: 'dag-pb',
    hashType: hashType,
    version: cidVersion,
  );
  final block = Block(cid: cid, data: bytes, format: 'dag-pb');
  await unixfsPutBlock(store, block);
  return UnixFSNode.fromBlock(block);
}

/// Creates a UnixFS directory from child [entries] with correct cumulative Tsize
/// values computed from the block store.
///
/// This is a convenience helper that calls [computeTsize] for each child,
/// then builds and stores the directory node.
Future<UnixFSNode> createDirectory(
  IBlockStore store,
  List<UnixFSDirectoryEntry> entries, {
  int cidVersion = 0,
  String hashType = 'sha2-256',
  int shardThreshold = 0,
}) async {
  final sizedEntries = <UnixFSDirectoryEntry>[];
  for (final entry in entries) {
    final tsize = await computeTsize(store, entry.cid);
    sizedEntries.add(
      UnixFSDirectoryEntry(name: entry.name, cid: entry.cid, tsize: tsize),
    );
  }
  return UnixFSDirectoryBuilder(
    cidVersion: cidVersion,
    hashType: hashType,
    shardThreshold: shardThreshold,
  ).buildAutoSharded(store, sizedEntries);
}

/// Adds or replaces a child named [name] in the directory identified by
/// [dirCid] and returns the new directory [UnixFSNode].
///
/// The original directory is not mutated; a new directory block is created and
/// stored. The new child's Tsize is computed from the block store.
Future<UnixFSNode> addChildToDirectory(
  IBlockStore store,
  CID dirCid,
  String name,
  CID childCid, {
  int? childTsize,
  int cidVersion = 0,
  String hashType = 'sha2-256',
  int shardThreshold = 0,
}) async {
  if (name.contains('/')) {
    throw ArgumentError('Directory entry name must not contain "/": $name');
  }
  final dirNode = await unixfsGetNode(store, dirCid);
  if (dirNode == null) {
    throw PathResolutionError('Directory block not found: $dirCid');
  }
  if (!dirNode.isDirectoryLike) {
    throw PathResolutionError('CID is not a directory: $dirCid');
  }

  final tsize = childTsize ?? await computeTsize(store, childCid);
  final newEntry = UnixFSDirectoryEntry(
    name: name,
    cid: childCid,
    tsize: tsize,
  );

  final entries = <UnixFSDirectoryEntry>[newEntry];
  for (final link in dirNode.pbNode.links) {
    if (link.name == name) continue;
    entries.add(
      UnixFSDirectoryEntry(
        name: link.name,
        cid: CID.fromBytes(Uint8List.fromList(link.hash)),
        tsize: link.size.toInt(),
      ),
    );
  }

  return UnixFSDirectoryBuilder(
    cidVersion: cidVersion,
    hashType: hashType,
    shardThreshold: shardThreshold,
  ).buildAutoSharded(store, entries);
}
