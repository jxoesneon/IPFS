import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';

/// Builds a UnixFS DAG from a stream of bytes.
class UnixFSBuilder {
  /// Default chunk size (256KB).
  static const int defaultChunkSize = 256 * 1024;

  /// Chunks a stream of bytes and yields Blocks for leaf nodes.
  Stream<Block> build(Stream<List<int>> stream) async* {
    final buffer = <int>[];
    final links = <dag_pb.PBLink>[];
    final logicalBlockSizes = <Int64>[];
    var totalSize = 0;

    await for (final chunk in stream) {
      buffer.addAll(chunk);

      while (buffer.length >= defaultChunkSize) {
        final leafData = Uint8List.fromList(
          buffer.take(defaultChunkSize).toList(),
        );
        buffer.removeRange(0, defaultChunkSize);

        final block = await _createLeaf(leafData);
        yield block;

        links.add(
          dag_pb.PBLink(
            hash: block.cid.toBytes(),
            size: Int64(block.data.length),
            name: '', // Empty for unnamed links in file
          ),
        );
        logicalBlockSizes.add(Int64(leafData.length));
        totalSize += leafData.length;
      }
    }

    // Process remaining buffer
    if (buffer.isNotEmpty) {
      final leafData = Uint8List.fromList(buffer);
      final block = await _createLeaf(leafData);
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
    }

    // Create Root Node (linking to all chunks)

    final unixFs = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.File,
      filesize: Int64(totalSize),
      blocksizes: logicalBlockSizes,
    );

    final outerNode = dag_pb.PBNode(data: unixFs.writeToBuffer(), links: links);

    final rootData = outerNode.writeToBuffer();
    // Use proper codec/hash for DAG-PB
    final rootCid = await CID.fromContent(
      rootData,
      codec: 'dag-pb',
      hashType: 'sha2-256',
      version: 0,
    );

    yield Block(cid: rootCid, data: rootData);
  }

  Future<Block> _createLeaf(Uint8List data) async {
    // Leaf node: UnixFS Data of type File
    final unixFs = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.File,
      data: data,
      filesize: Int64(data.length),
    );

    final node = dag_pb.PBNode(data: unixFs.writeToBuffer());

    final encoded = node.writeToBuffer();
    final cid = await CID.fromContent(
      encoded,
      codec: 'dag-pb',
      hashType: 'sha2-256',
      version: 0,
    );

    return Block(cid: cid, data: encoded);
  }
}
