import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/dag_marshal.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';

/// Builds a UnixFS DAG from a stream of bytes.
class UnixFSBuilder {
  /// Creates a builder with optional CID formatting.
  UnixFSBuilder({
    this.cidVersion = 0,
    this.rawLeaves = false,
    this.hashType = 'sha2-256',
  });

  /// Default chunk size (256KB).
  static const int defaultChunkSize = 256 * 1024;

  /// CID version to use for generated blocks (0 or 1).
  final int cidVersion;

  /// Whether to store leaf nodes as raw blocks instead of UnixFS file nodes.
  final bool rawLeaves;

  /// Multihash function to use (currently only `sha2-256` is supported).
  final String hashType;

  /// Chunks a stream of bytes and yields Blocks for leaf nodes followed by
  /// the DAG-PB root node (when a root is needed).
  ///
  /// Matches Kubo's `ipfs add` layout:
  /// - A single-chunk file is just the leaf itself — the leaf *is* the root
  ///   and no wrapper node is produced. (With [rawLeaves] the leaf is a raw
  ///   block, which cannot be a UnixFS root, so a wrapper is always emitted.)
  /// - An empty stream yields a single DAG-PB node containing
  ///   `Data{Type: File}` with no filesize field, matching Kubo's well-known
  ///   empty-file block.
  /// - Multi-chunk files yield all leaves, then a root node linking to them
  ///   in order with `filesize` and `blocksizes` set.
  Stream<Block> build(Stream<List<int>> stream) async* {
    final reader = ChunkedStreamReader(stream);
    final links = <dag_pb.PBLink>[];
    final logicalBlockSizes = <Int64>[];
    var totalSize = 0;
    var leafCount = 0;

    try {
      while (true) {
        final leafData = await reader.readChunk(defaultChunkSize);
        if (leafData.isEmpty) break;

        final block = await _createLeaf(Uint8List.fromList(leafData));
        leafCount++;
        yield block;

        links.add(
          dag_pb.PBLink(
            hash: block.cid.toBytes(),
            size: Int64(block.data.length),
            name: '',
          ),
        );
        logicalBlockSizes.add(Int64(leafData.length));
        totalSize += leafData.length;

        if (leafData.length < defaultChunkSize) break;
      }
    } finally {
      await reader.cancel();
    }

    if (leafCount == 1 && !rawLeaves) {
      // Kubo parity: a file that fits in one chunk is addressed by the leaf
      // node itself — the last block yielded is already the root.
      return;
    }

    // Create Root Node (linking to all chunks)
    final unixFs = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.File,
      // Kubo's empty-file block omits the filesize field entirely.
      filesize: totalSize > 0 ? Int64(totalSize) : null,
      blocksizes: logicalBlockSizes,
    );

    final outerNode = dag_pb.PBNode(data: unixFs.writeToBuffer(), links: links);
    final rootData = marshalDagPBNode(outerNode);

    final rootCid = await CID.fromContent(
      rootData,
      codec: 'dag-pb',
      hashType: hashType,
      version: cidVersion,
    );

    yield Block(cid: rootCid, data: rootData);
  }

  Future<Block> _createLeaf(Uint8List data) async {
    if (rawLeaves) {
      final cid = await CID.fromContent(
        data,
        codec: 'raw',
        hashType: hashType,
        version: cidVersion == 0 ? 1 : cidVersion,
      );
      return Block(cid: cid, data: data);
    }

    // Leaf node: UnixFS Data of type File
    final unixFs = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.File,
      data: data,
      filesize: Int64(data.length),
    );

    final node = dag_pb.PBNode(data: unixFs.writeToBuffer());
    final encoded = marshalDagPBNode(node);

    final cid = await CID.fromContent(
      encoded,
      codec: 'dag-pb',
      hashType: hashType,
      version: cidVersion,
    );

    return Block(cid: cid, data: encoded);
  }
}
