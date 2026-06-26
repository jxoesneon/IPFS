// src/core/unixfs/unixfs_resolver.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_errors.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;

/// Resolves UnixFS paths against a block store.
///
/// The resolver supports plain directories, HAMT-sharded directories, and
/// symlinks. It rejects relative path components in the input path and
/// normalizes relative components in symlink targets without allowing escape
/// above the resolution root.
class UnixFSPathResolver {
  /// Creates a resolver backed by [store].
  ///
  /// [maxDepth], [maxPathLength], and [maxNodes] provide resource limits for
  /// a single resolution request.
  UnixFSPathResolver({
    required IBlockStore store,
    this.maxDepth = 100,
    this.maxPathLength = 4096,
    this.maxNodes = 10000,
  }) : _store = store;

  /// Block store used to fetch nodes during resolution.
  final IBlockStore _store;

  /// Maximum recursion depth for a single resolution request.
  final int maxDepth;

  /// Maximum length of an input path string.
  final int maxPathLength;

  /// Maximum number of nodes traversed for a single resolution request.
  final int maxNodes;

  /// Resolves [path] under [root] and returns the CID of the final node.
  Future<CID> resolve(CID root, String path) async {
    final node = await resolveNode(root, path);
    return node.cid;
  }

  /// Resolves [path] under [root] and returns the final [UnixFSNode].
  Future<UnixFSNode> resolveNode(CID root, String path) async {
    if (path.length > maxPathLength) {
      throw PathResolutionError('Path exceeds maximum length ($maxPathLength)');
    }
    final segments = _parsePath(path);
    return _resolve(
      root,
      root,
      <String>[],
      segments,
      <CID>{},
      <CID>{},
      0,
      0,
      0,
    );
  }

  /// Splits a path into non-empty segments and rejects `.` and `..`.
  List<String> _parsePath(String path) {
    var normalized = path;
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.isEmpty) return <String>[];

    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    for (final part in parts) {
      if (part == '.' || part == '..') {
        throw PathResolutionError(
          'Relative path components are not allowed in input paths: $part',
        );
      }
    }
    return parts;
  }

  Future<UnixFSNode> _resolve(
    CID root,
    CID currentCid,
    List<String> currentPath,
    List<String> remaining,
    Set<CID> pathCids,
    Set<CID> symlinkCids,
    int depth,
    int nodeCount,
    int hamtLevel,
  ) async {
    if (depth > maxDepth) {
      throw PathResolutionError('Maximum resolution depth exceeded');
    }
    if (nodeCount > maxNodes) {
      throw PathResolutionError('Maximum node traversal budget exceeded');
    }
    if (pathCids.contains(currentCid)) {
      throw DAGCycleError('DAG cycle detected at CID $currentCid');
    }

    final node = await unixfsGetNode(_store, currentCid);
    if (node == null) {
      throw PathResolutionError('Block not found: $currentCid');
    }

    // Symlinks are always followed, even when the path ends at one.
    if (node.isSymlink) {
      if (symlinkCids.contains(currentCid)) {
        throw SymlinkCycleError('Symlink cycle detected at CID $currentCid');
      }
      final target = node.symlinkTarget;
      if (target == null || target.isEmpty) {
        throw PathResolutionError('Symlink with empty target at $currentCid');
      }
      final parentPath = currentPath.isEmpty
          ? <String>[]
          : currentPath.sublist(0, currentPath.length - 1);
      final normalizedTarget = _normalizeSymlinkTarget(target, parentPath);
      final newSymlinkCids = Set<CID>.from(symlinkCids)..add(currentCid);
      return _resolve(
        root,
        root,
        <String>[],
        <String>[...normalizedTarget, ...remaining],
        <CID>{},
        newSymlinkCids,
        depth + 1,
        nodeCount + 1,
        0,
      );
    }

    if (remaining.isEmpty) return node;

    pathCids.add(currentCid);
    try {
      final segment = remaining[0];
      final nextRemaining = remaining.sublist(1);

      if (node.isDirectory) {
        final link = findLinkByName(node.pbNode.links, segment);
        if (link == null) {
          throw PathResolutionError('Path not found: $segment');
        }
        return _resolve(
          root,
          CID.fromBytes(Uint8List.fromList(link.hash)),
          <String>[...currentPath, segment],
          nextRemaining,
          pathCids,
          symlinkCids,
          depth + 1,
          nodeCount + 1,
          0,
        );
      }

      if (node.isHAMTShard) {
        final link = resolveHAMTSegment(node, segment, hamtLevel);
        if (link == null) {
          throw PathResolutionError('Path not found in HAMT shard: $segment');
        }
        if (_isHAMTSubShardLink(node, link)) {
          return _resolve(
            root,
            CID.fromBytes(Uint8List.fromList(link.hash)),
            currentPath,
            remaining,
            pathCids,
            symlinkCids,
            depth + 1,
            nodeCount + 1,
            hamtLevel + 1,
          );
        }
        return _resolve(
          root,
          CID.fromBytes(Uint8List.fromList(link.hash)),
          <String>[...currentPath, segment],
          nextRemaining,
          pathCids,
          symlinkCids,
          depth + 1,
          nodeCount + 1,
          0,
        );
      }

      throw PathResolutionError(
        'Path not found: cannot traverse non-directory node',
      );
    } finally {
      pathCids.remove(currentCid);
    }
  }

  /// Normalizes a symlink target relative to [parentPath] and ensures it does
  /// not escape above the resolution root.
  List<String> _normalizeSymlinkTarget(String target, List<String> parentPath) {
    final parts = target.split('/').where((p) => p.isNotEmpty).toList();
    final stack = List<String>.from(parentPath);

    if (target.startsWith('/')) {
      stack.clear();
    }

    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..') {
        if (stack.isEmpty) {
          throw PathResolutionError('Symlink target escapes root');
        }
        stack.removeLast();
      } else {
        stack.add(part);
      }
    }

    return stack;
  }

  bool _isHAMTSubShardLink(UnixFSNode node, dag_pb.PBLink link) {
    if (!node.isHAMTShard) return false;
    final width = hamtPrefixWidth(node.fanout);
    return link.name.length == width;
  }
}
