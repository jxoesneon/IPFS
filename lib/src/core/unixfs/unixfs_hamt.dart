// src/core/unixfs/unixfs_hamt.dart
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

/// Multihash code for murmur3-x64-64, the only supported HAMT hash function.
const int kUnixFSHAMTHashType = 0x22;

/// Default HAMT fanout used by Kubo and Helia (256 buckets).
const int kUnixFSHAMTFanout = 256;

/// Computes the MurmurHash3 x64-128 digest of [bytes] and returns the first
/// 64 bits (h1) as the [murmur3-x64-64] hash value.
///
/// This is the hash function used by UnixFS HAMT directory sharding.
int murmur3X64Hash64(List<int> bytes, {int seed = 0}) {
  return _murmur3X64Hash128(bytes, seed: seed)[0];
}

/// Computes the MurmurHash3 x64-128 digest of [bytes] as a pair of unsigned
/// 64-bit values `[h1, h2]`.
///
/// The returned values are little-endian decoded from the raw 128-bit digest.
List<int> _murmur3X64Hash128(List<int> bytes, {int seed = 0}) {
  const c1 = 0x87c37b91114253d5;
  const c2 = 0x4cf5ad432745937f;

  var h1 = _mask64(seed);
  var h2 = _mask64(seed);

  final length = bytes.length;
  final nblocks = length ~/ 16;

  for (var i = 0; i < nblocks; i++) {
    final offset = i * 16;
    var k1 = _mask64(_getUint64LE(bytes, offset));
    var k2 = _mask64(_getUint64LE(bytes, offset + 8));

    k1 = _mask64(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask64(k1 * c2);
    h1 ^= k1;

    h1 = _rotl64(h1, 27);
    h1 = _mask64(h1 * 5 + 0x52dce729);

    k2 = _mask64(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask64(k2 * c1);
    h2 ^= k2;

    h2 = _rotl64(h2, 31);
    h2 = _mask64(h2 * 5 + 0x38495ab5);
  }

  var k1 = 0;
  var k2 = 0;
  final tail = length & 15;

  if (tail >= 15) k2 ^= (bytes[length - tail + 14] & 0xff) << 48;
  if (tail >= 14) k2 ^= (bytes[length - tail + 13] & 0xff) << 40;
  if (tail >= 13) k2 ^= (bytes[length - tail + 12] & 0xff) << 32;
  if (tail >= 12) k2 ^= (bytes[length - tail + 11] & 0xff) << 24;
  if (tail >= 11) k2 ^= (bytes[length - tail + 10] & 0xff) << 16;
  if (tail >= 10) k2 ^= (bytes[length - tail + 9] & 0xff) << 8;
  if (tail >= 9) {
    k2 ^= bytes[length - tail + 8] & 0xff;
    k2 = _mask64(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask64(k2 * c1);
    h2 ^= k2;
  }
  if (tail >= 8) k1 ^= (bytes[length - tail + 7] & 0xff) << 56;
  if (tail >= 7) k1 ^= (bytes[length - tail + 6] & 0xff) << 48;
  if (tail >= 6) k1 ^= (bytes[length - tail + 5] & 0xff) << 40;
  if (tail >= 5) k1 ^= (bytes[length - tail + 4] & 0xff) << 32;
  if (tail >= 4) k1 ^= (bytes[length - tail + 3] & 0xff) << 24;
  if (tail >= 3) k1 ^= (bytes[length - tail + 2] & 0xff) << 16;
  if (tail >= 2) k1 ^= (bytes[length - tail + 1] & 0xff) << 8;
  if (tail >= 1) {
    k1 ^= bytes[length - tail + 0] & 0xff;
    k1 = _mask64(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask64(k1 * c2);
    h1 ^= k1;
  }

  h1 ^= length;
  h2 ^= length;

  h1 = _mask64(h1 + h2);
  h2 = _mask64(h2 + h1);

  h1 = _fmix64(h1);
  h2 = _fmix64(h2);

  h1 = _mask64(h1 + h2);
  h2 = _mask64(h2 + h1);

  return <int>[h1, h2];
}

int _mask64(int value) => value & 0xFFFFFFFFFFFFFFFF;

int _rotl64(int x, int r) {
  final masked = _mask64(x);
  return _mask64((masked << r) | (masked >>> (64 - r)));
}

int _fmix64(int k) {
  var result = _mask64(k);
  result ^= result >>> 33;
  result = _mask64(result * 0xff51afd7ed558ccd);
  result ^= result >>> 33;
  result = _mask64(result * 0xc4ceb9fe1a85ec53);
  result ^= result >>> 33;
  return result;
}

int _getUint64LE(List<int> bytes, int offset) {
  var result = 0;
  for (var i = 0; i < 8; i++) {
    result |= (bytes[offset + i] & 0xff) << (i * 8);
  }
  return result;
}

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
    this.maxBucketSize = 10,
    this.cidVersion = 0,
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
    final hash = murmur3X64Hash64(name.codeUnits);
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
  final hash = murmur3X64Hash64(name.codeUnits);
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
