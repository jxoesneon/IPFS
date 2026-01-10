import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('UnixFS File Sharding', () {
    test('should shard large file into multiple blocks', () async {
      // 1MB + 100KB file (Chunks are 256KB)
      // Expect 4 full chunks + 1 partial chunk = 5 chunks + 1 root = 6 blocks
      final totalSize = 1024 * 1024 + 100 * 1024;
      final data = Uint8List(totalSize);
      for (var i = 0; i < totalSize; i++) {
        data[i] = i % 256;
      }

      final stream = Stream.value(data.toList());
      final builder = UnixFSBuilder();
      
      final blocks = <Block>[];
      await for (final block in builder.build(stream)) {
        blocks.add(block);
      }

      print('DEBUG: Generated ${blocks.length} blocks for ${totalSize} bytes');

      // Verify block count
      // 1MB / 256KB = 4 chunks
      // 100KB is 5th chunk
      // Root is 6th block
      expect(blocks.length, equals(6));

      // Verify Root Node
      final rootBlock = blocks.last;
      expect(rootBlock.cid.codec, 'dag-pb');
      
      final rootNode = dag_pb.PBNode.fromBuffer(rootBlock.data);
      expect(rootNode.links.length, equals(5));

      // Verify UnixFS Data of Root
      final rootData = unixfs_pb.Data.fromBuffer(rootNode.data);
      expect(rootData.type, unixfs_pb.Data_DataType.File);
      expect(rootData.filesize.toInt(), equals(totalSize));
      expect(rootData.blocksizes.length, equals(5));

      // Verify total size from links match (should be greater due to PB overhead)
      var calculatedTotalSize = 0;
      for (final link in rootNode.links) {
        calculatedTotalSize += link.size.toInt();
      }
      expect(calculatedTotalSize, greaterThan(totalSize));

      // Verify logical block sizes sum
      var totalLogicalSize = 0;
      for (final size in rootData.blocksizes) {
        totalLogicalSize += size.toInt();
      }
      expect(totalLogicalSize, equals(totalSize));
    });

    test('should construct directory DAG', () async {
      // 1. Create a file block
      final fileData = Uint8List.fromList([1, 2, 3, 4]);
      final fileBuilder = UnixFSBuilder();
      final fileStream = Stream.value(fileData.toList());
      final fileBlocks = await fileBuilder.build(fileStream).toList();
      final fileRootBlock = fileBlocks.last;

      // 2. Create a subdirectory
      final subdirManager = IPFSDirectoryManager();
      subdirManager.addEntry(IPFSDirectoryEntry(
        name: 'file.txt',
        hash: fileRootBlock.cid.multihash.toBytes(),
        size: Int64(fileRootBlock.data.length),
        isDirectory: false,
      ));
      final subdirNode = subdirManager.build();
      final subdirData = subdirNode.writeToBuffer();
      final subdirCid = await CID.fromContent(subdirData, codec: 'dag-pb');

      // 3. Create root directory
      final rootManager = IPFSDirectoryManager();
      rootManager.addEntry(IPFSDirectoryEntry(
        name: 'subdir',
        hash: subdirCid.multihash.toBytes(),
        size: Int64(subdirData.length),
        isDirectory: true,
      ));
      rootManager.addEntry(IPFSDirectoryEntry(
        name: 'root_file.txt',
        hash: fileRootBlock.cid.multihash.toBytes(),
        size: Int64(fileRootBlock.data.length),
        isDirectory: false,
      ));

      final rootNode = rootManager.build();
      
      // Verify Root
      expect(rootNode.links.length, equals(2));
      // Links should be sorted by name: 'root_file.txt' vs 'subdir'
      // 'r' < 's', so root_file.txt first?
      expect(rootNode.links[0].name, equals('root_file.txt'));
      expect(rootNode.links[1].name, equals('subdir'));

      final rootUnixFs = unixfs_pb.Data.fromBuffer(rootNode.data);
      expect(rootUnixFs.type, unixfs_pb.Data_DataType.Directory);
    });
  });
}
