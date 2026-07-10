// src/core/unixfs/unixfs_hamt.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';

import 'murmur_hash.dart' if (dart.library.html) 'murmur_hash_web.dart' as murmur;

export 'murmur_hash.dart' if (dart.library.html) 'murmur_hash_web.dart'
    show murmur3X64Hash64;

/// Multihash code for murmur3-x64-64, the only supported HAMT hash function.
const int kUnixFSHAMTHashType = 0x22;

/// Default HAMT fanout used by Kubo and Helia (256 buckets).
const int kUnixFSHAMTFanout = 256;

/// A child entry of a HAMT shard while it is being built.
class _HAMTEntry {
  _HAMTEntry(this.name, this.cid, this.tsize);

  final String name;
  final CID cid;
  final int tsize;
}

/// Builds HAMT-sharded UnixFS directories compatible with Kubo/Helia layout.
///
/// The builder splits directories into shards when the number of entries exceeds
/// [shardThreshold]. Each shard uses [fanout] buckets and the murmur3-x64-64
/// hash function. Buckets with more than [maxBucketSize] entries are pushed
/// into child shards using the next bits of the name hash.
class UnixFSHAMTBuilder {
  /// Creates a HAMT builder with the requested fanout, thresholds, and hashing
  /// settings.
  UnixFSHAMTBuilder({
    this.fanout = kUnixFSHAMTFanout,
    this.shardThreshold = 256,
    this.maxBucketSize = 1,
    this.cidVersion = 1,
    this.hashType = 'sha2-256',
  }) {
    if (fanout <= 0 || (fanout & (fanout - 1)) != 0) {
      throw ArgumentError('fanout must be a power of two');
    }
    if (fanout % 8 != 0) {
      throw ArgumentError('fanout must be a multiple of 8');
    }
    if (fanout > 1024) {
      throw ArgumentError('fanout must be at most 1024');
    }
  }

  /// Number of buckets per shard (must be a power of two, multiple of 8).
  final int fanout;

  /// Number of entries above which a directory is encoded as a HAMT shard.
  final int shardThreshold;

  /// Maximum entries allowed in a single bucket before it is pushed into a
  /// child shard.
  final int maxBucketSize;

  /// CID version for generated shard blocks.
  final int cidVersion;

  /// Multihash function for generated shard blocks.
  final String hashType;

  int get _log2Fanout {
    var log2 = 0;
    var temp = fanout;
    while (temp > 1) {
      temp >>= 1;
      log2++;
    }
    return log2;
  }

  int get _prefixWidth => _log2Fanout ~/ 4;

  /// Builds a directory from [entries].
  ///
  /// If the entry count is at most [shardThreshold] a plain UnixFS directory is
  /// returned. Otherwise a HAMT-sharded directory is built and its root shard
  /// node is returned.
  Future<UnixFSNode> build(
    IBlockStore store,
    List<UnixFSDirectoryEntry> entries,
  ) async {
    if (entries.length <= shardThreshold) {
      return UnixFSDirectoryBuilder(
        cidVersion: cidVersion,
        hashType: hashType,
      ).build(store, entries);
    }
    final hamtEntries = <_HAMTEntry>[];
    for (final entry in entries) {
      final tsize = await computeTsize(store, entry.cid);
      hamtEntries.add(_HAMTEntry(entry.name, entry.cid, tsize));
    }
    return _buildShard(store, hamtEntries, 0);
  }

  Future<UnixFSNode> _buildShard(
    IBlockStore store,
    List<_HAMTEntry> entries,
    int level,
  ) async {
    final buckets = <int, List<_HAMTEntry>>{};
    for (final entry in entries) {
      final idx = _prefixIndex(entry.name, level);
      buckets.putIfAbsent(idx, () => <_HAMTEntry>[]).add(entry);
    }

    final links = <dag_pb.PBLink>[];
    final bitmap = Uint8List(fanout ~/ 8);
    final sortedKeys = buckets.keys.toList()..sort();

    for (final idx in sortedKeys) {
      final bucketEntries = buckets[idx]!;
      _setBitmapBit(bitmap, idx);

      if (bucketEntries.length <= maxBucketSize) {
        for (final entry in bucketEntries) {
          links.add(
            dag_pb.PBLink(
              hash: Uint8List.fromList(entry.cid.toBytes()),
              name: '${_prefixHex(idx)}${entry.name}',
              size: Int64(entry.tsize),
            ),
          );
        }
      } else {
        final child = await _buildShard(store, bucketEntries, level + 1);
        final childTsize = await computeTsize(store, child.cid);
        links.add(
          dag_pb.PBLink(
            hash: Uint8List.fromList(child.cid.toBytes()),
            name: _prefixHex(idx),
            size: Int64(childTsize),
          ),
        );
      }
    }

    return _createShardNodeFromLinks(store, links, bitmap);
  }

  Future<UnixFSNode> _createShardNodeFromLinks(
    IBlockStore store,
    List<dag_pb.PBLink> links,
    Uint8List bitmap,
  ) async {
    final unixFsData = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.HAMTShard,
      data: bitmap,
      hashType: Int64(kUnixFSHAMTHashType),
      fanout: Int64(fanout),
    );
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

  int _prefixIndex(String name, int level) {
    final hash = murmur.murmur3X64Hash64(utf8.encode(name));
    final shift = level * _log2Fanout;
    final mask = (1 << _log2Fanout) - 1;
    return (hash >>> shift) & mask;
  }

  String _prefixHex(int index) {
    return index.toRadixString(16).toUpperCase().padLeft(_prefixWidth, '0');
  }

  void _setBitmapBit(Uint8List bitmap, int index) {
    bitmap[index ~/ 8] |= 1 << (index % 8);
  }
}

/// Resolves a single path segment [name] within a HAMT shard [node].
///
/// Returns the matching link if the segment is found, or null if not found.
/// If the matching link is a sub-shard (its name is exactly the prefix), the
/// caller should recurse into the shard to continue resolving.
dag_pb.PBLink? resolveHAMTSegment(UnixFSNode node, String name, int level) {
  if (!node.isHAMTShard) return null;
  final log2Fanout = _log2(node.fanout);
  final prefixWidth = log2Fanout ~/ 4;
  final hash = murmur.murmur3X64Hash64(utf8.encode(name));
  final shift = level * log2Fanout;
  final mask = (1 << log2Fanout) - 1;
  final index = (hash >>> shift) & mask;
  final prefix = index
      .toRadixString(16)
      .toUpperCase()
      .padLeft(prefixWidth, '0');

  for (final link in node.pbNode.links) {
    if (link.name.startsWith(prefix)) {
      if (link.name == prefix) {
        return link; // sub-shard
      }
      if (link.name.length > prefix.length &&
          link.name.substring(prefix.length) == name) {
        return link;
      }
    }
  }
  return null;
}

/// Returns the width in characters of the hex-encoded HAMT prefix for a shard
/// with the given [fanout].
int hamtPrefixWidth(int fanout) {
  return _log2(fanout) ~/ 4;
}

int _log2(int value) {
  var log2 = 0;
  var temp = value;
  while (temp > 1) {
    temp >>= 1;
    log2++;
  }
  return log2;
}
