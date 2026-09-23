// src/core/unixfs/unixfs_reader.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';

/// Fetches the block addressed by [cid], or returns `null` when it is not
/// available from the backing store.
///
/// Callers wrap whatever storage they own (datastore, block store, Bitswap)
/// behind this signature so [unixfsReadFile] stays storage-agnostic.
typedef UnixFSBlockFetcher = Future<Block?> Function(CID cid);

/// Default maximum link depth for a single [unixfsReadFile] call.
///
/// Matches the gateway CAR export traversal bound; a balanced UnixFS chunk
/// tree is only a few levels deep even for very large files.
const int unixfsReadDefaultMaxDepth = 32;

/// Default maximum number of nodes visited by a single [unixfsReadFile] call.
///
/// Matches the gateway CAR export block-count bound.
const int unixfsReadDefaultMaxNodes = 10000;

/// Default maximum payload size, in bytes, that a single [unixfsReadFile]
/// call will buffer before failing (512 MiB).
///
/// Without a byte cap a large chunked file would be buffered into memory in
/// full by callers such as the gateway's file handler and RPC `cat`. The
/// value is a safety ceiling, not a quota — callers may pass a smaller
/// [unixfsReadFile.maxBytes] to enforce their own limit.
const int unixfsReadDefaultMaxBytes = 512 * 1024 * 1024;

/// Default ceiling on total payload bytes in a generated CAR archive.
///
/// CAR writers buffer the archive in memory, so a byte bound (not just a
/// block-count or depth cap) keeps a large DAG from consuming unbounded
/// memory per request. Shared by the gateway's trustless CAR handler and
/// RPC `dag/export`; callers may pass a smaller limit.
const int carExportDefaultMaxBytes = 1024 * 1024 * 1024;

/// Prefix of the [StateError.message] thrown when a [unixfsReadFile] call
/// exceeds its `maxBytes` budget.
///
/// Exposed so callers can distinguish the byte-budget failure from other
/// traversal [StateError]s (missing blocks, depth/node limits) without
/// relying on the exact wording.
const String unixfsReadByteBudgetExceededPrefix =
    'UnixFS traversal exceeded maximum byte budget';

/// Reassembles the user-visible payload stored under [root].
///
/// - Raw blocks return their payload directly.
/// - UnixFS file nodes are reassembled from their inline `Data.data` plus
///   every linked child block, traversed in link order.
/// - Anything else (directories, HAMT shards, non-UnixFS DAG-PB, unparseable
///   data) returns the serialized [root] block bytes, matching the previous
///   "return the stored bytes" behavior for non-file content.
///
/// Linked blocks are fetched through [fetchBlock]. Throws [StateError] when a
/// linked block is missing or when the traversal exceeds [maxDepth],
/// [maxNodes], or the [maxBytes] payload budget.
Future<Uint8List> unixfsReadFile(
  Block root,
  UnixFSBlockFetcher fetchBlock, {
  int maxDepth = unixfsReadDefaultMaxDepth,
  int maxNodes = unixfsReadDefaultMaxNodes,
  int maxBytes = unixfsReadDefaultMaxBytes,
}) async {
  if (root.cid.codec == 'raw') {
    return root.data;
  }

  final UnixFSNode node;
  try {
    node = UnixFSNode.fromBlock(root);
  } catch (_) {
    return root.data;
  }
  if (!node.isFile) {
    return root.data;
  }

  final out = BytesBuilder();
  final budget = _TraversalBudget(
    maxDepth: maxDepth,
    maxNodes: maxNodes,
    maxBytes: maxBytes,
  );
  await _collectFileData(node, fetchBlock, out, budget, depth: 0);
  return out.takeBytes();
}

class _TraversalBudget {
  _TraversalBudget({
    required this.maxDepth,
    required this.maxNodes,
    required this.maxBytes,
  });

  final int maxDepth;
  final int maxNodes;
  final int maxBytes;
  int visited = 0;
}

/// Appends the file payload of [node] — its inline UnixFS data plus every
/// linked child block in order — to [out].
Future<void> _collectFileData(
  UnixFSNode node,
  UnixFSBlockFetcher fetchBlock,
  BytesBuilder out,
  _TraversalBudget budget, {
  required int depth,
}) async {
  if (depth > budget.maxDepth) {
    throw StateError(
      'UnixFS traversal exceeded maximum depth ${budget.maxDepth}',
    );
  }
  if (++budget.visited > budget.maxNodes) {
    throw StateError(
      'UnixFS traversal exceeded maximum node count ${budget.maxNodes}',
    );
  }

  if (node.cid.codec == 'raw') {
    out.add(node.data);
    _checkByteBudget(out, budget);
    return;
  }

  final inner = node.unixfsData;
  if (inner != null && inner.data.isNotEmpty) {
    out.add(inner.data);
    _checkByteBudget(out, budget);
  }

  for (final link in node.pbNode.links) {
    // Lenient decode tolerates zero-length identity digests; malformed
    // link targets still surface the strict decoder's error.
    final childCid = tryDecodeCidBytesLenient(link.hash) ??
        CID.fromBytes(Uint8List.fromList(link.hash));
    final childBlock = await fetchBlock(childCid);
    if (childBlock == null) {
      throw StateError('Missing linked block ${childCid.encode()}');
    }
    await _collectFileData(
      UnixFSNode.fromBlock(childBlock),
      fetchBlock,
      out,
      budget,
      depth: depth + 1,
    );
  }
}

/// Throws a [StateError] carrying [unixfsReadByteBudgetExceededPrefix] when
/// the buffered payload in [out] has grown past [budget]'s byte cap.
void _checkByteBudget(BytesBuilder out, _TraversalBudget budget) {
  if (out.length > budget.maxBytes) {
    throw StateError('$unixfsReadByteBudgetExceededPrefix ${budget.maxBytes}');
  }
}
