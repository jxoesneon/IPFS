import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_errors.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_resolver.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '../../mocks/mock_block_store.dart';

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
      subdirManager.addEntry(
        IPFSDirectoryEntry(
          name: 'file.txt',
          hash: fileRootBlock.cid.multihash.toBytes(),
          size: Int64(fileRootBlock.data.length),
          isDirectory: false,
        ),
      );
      final subdirNode = subdirManager.build();
      final subdirData = subdirNode.writeToBuffer();
      final subdirCid = await CID.fromContent(subdirData, codec: 'dag-pb');

      // 3. Create root directory
      final rootManager = IPFSDirectoryManager();
      rootManager.addEntry(
        IPFSDirectoryEntry(
          name: 'subdir',
          hash: subdirCid.multihash.toBytes(),
          size: Int64(subdirData.length),
          isDirectory: true,
        ),
      );
      rootManager.addEntry(
        IPFSDirectoryEntry(
          name: 'root_file.txt',
          hash: fileRootBlock.cid.multihash.toBytes(),
          size: Int64(fileRootBlock.data.length),
          isDirectory: false,
        ),
      );

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

  group('UnixFS Directory Builder', () {
    late IBlockStore store;

    setUp(() async {
      store = MockBlockStore();
      await store.start();
    });

    Future<Block> createRawFile(List<int> data) async {
      final block = await Block.fromData(
        Uint8List.fromList(data),
        format: 'raw',
      );
      await store.putBlock(block);
      return block;
    }

    test('createDirectory computes correct cumulative Tsize', () async {
      final fileA = await createRawFile([1, 2, 3, 4]);
      final fileB = await createRawFile([5, 6, 7]);

      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'b', cid: fileB.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'a', cid: fileA.cid, tsize: 0),
      ]);

      expect(dir.isDirectory, isTrue);
      expect(dir.pbNode.links.length, 2);
      expect(dir.pbNode.links[0].name, 'a');
      expect(dir.pbNode.links[1].name, 'b');
      expect(dir.pbNode.links[0].size.toInt(), fileA.data.length);
      expect(dir.pbNode.links[1].size.toInt(), fileB.data.length);

      final expectedTsize =
          dir.data.length + fileA.data.length + fileB.data.length;
      final computed = await computeTsize(store, dir.cid);
      expect(computed, expectedTsize);
    });

    test('computeTsize for nested directory', () async {
      final file = await createRawFile([1, 2, 3]);
      final subdir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'file', cid: file.cid, tsize: 0),
      ]);
      final root = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'subdir', cid: subdir.cid, tsize: 0),
      ]);

      final expected = root.data.length + subdir.data.length + file.data.length;
      expect(await computeTsize(store, root.cid), expected);
    });

    test('computeTsize detects DAG cycles', () async {
      // Create a self-loop by storing a directory block under a CID that
      // points to itself. This exercises the cycle guard without requiring a
      // hash-collision fixed point.
      final nodeA0 = await createDirectory(store, <UnixFSDirectoryEntry>[]);
      final cyclicA = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'self', cid: nodeA0.cid, tsize: 0),
      ]);
      (store as MockBlockStore).setupBlock(
        nodeA0.cid.toString(),
        Block(cid: nodeA0.cid, data: cyclicA.data, format: 'dag-pb'),
      );

      expect(
        () => computeTsize(store, nodeA0.cid),
        throwsA(isA<DAGCycleError>()),
      );
    });

    test('addChildToDirectory replaces existing entry', () async {
      final file1 = await createRawFile([1]);
      final file2 = await createRawFile([2, 2]);
      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'x', cid: file1.cid, tsize: 0),
      ]);

      final updated = await addChildToDirectory(store, dir.cid, 'x', file2.cid);

      expect(updated.pbNode.links.length, 1);
      expect(updated.pbNode.links[0].name, 'x');
      expect(updated.pbNode.links[0].size.toInt(), file2.data.length);
    });
  });

  group('UnixFS Path Resolver', () {
    late IBlockStore store;
    late UnixFSPathResolver resolver;

    setUp(() async {
      store = MockBlockStore();
      await store.start();
      resolver = UnixFSPathResolver(store: store);
    });

    Future<Block> createRawFile(List<int> data) async {
      final block = await Block.fromData(
        Uint8List.fromList(data),
        format: 'raw',
      );
      await store.putBlock(block);
      return block;
    }

    Future<UnixFSNode> createDir(List<UnixFSDirectoryEntry> entries) async {
      return createDirectory(store, entries);
    }

    test('resolves a simple path', () async {
      final file = await createRawFile([10, 20, 30]);
      final root = await createDir([
        UnixFSDirectoryEntry(name: 'readme.txt', cid: file.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(root.cid, 'readme.txt');
      expect(resolved, file.cid);
    });

    test('resolves nested path', () async {
      final file = await createRawFile([1, 2, 3]);
      final subdir = await createDir([
        UnixFSDirectoryEntry(name: 'inner.txt', cid: file.cid, tsize: 0),
      ]);
      final root = await createDir([
        UnixFSDirectoryEntry(name: 'subdir', cid: subdir.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(root.cid, '/subdir/inner.txt');
      expect(resolved, file.cid);
    });

    test('rejects . segments', () async {
      final root = await createDir([]);
      expect(
        () => resolver.resolve(root.cid, 'a/./b'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('rejects .. segments', () async {
      final root = await createDir([]);
      expect(
        () => resolver.resolve(root.cid, '../a'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('ignores empty segments from consecutive slashes', () async {
      final file = await createRawFile([1]);
      final root = await createDir([
        UnixFSDirectoryEntry(name: 'a', cid: file.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(root.cid, '//a//');
      expect(resolved, file.cid);
    });

    test('throws on missing link', () async {
      final root = await createDir([]);
      expect(
        () => resolver.resolve(root.cid, 'missing'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('detects DAG cycle during resolution', () async {
      // Create a self-loop by storing a directory block under a CID that
      // points to itself.
      final nodeA0 = await createDir([]);
      final cyclicA = await createDir([
        UnixFSDirectoryEntry(name: 'self', cid: nodeA0.cid, tsize: 0),
      ]);
      (store as MockBlockStore).setupBlock(
        nodeA0.cid.toString(),
        Block(cid: nodeA0.cid, data: cyclicA.data, format: 'dag-pb'),
      );

      expect(
        () => resolver.resolve(nodeA0.cid, 'self/self'),
        throwsA(isA<DAGCycleError>()),
      );
    });
  });

  group('UnixFS Symlinks', () {
    late IBlockStore store;
    late UnixFSPathResolver resolver;

    setUp(() async {
      store = MockBlockStore();
      await store.start();
      resolver = UnixFSPathResolver(store: store);
    });

    Future<Block> createRawFile(List<int> data) async {
      final block = await Block.fromData(
        Uint8List.fromList(data),
        format: 'raw',
      );
      await store.putBlock(block);
      return block;
    }

    Future<UnixFSNode> createDir(List<UnixFSDirectoryEntry> entries) async {
      return createDirectory(store, entries);
    }

    test('creates a symlink node', () async {
      final link = await createSymlink(store, 'target/path');
      expect(link.isSymlink, isTrue);
      expect(link.symlinkTarget, 'target/path');
      expect(link.pbNode.links, isEmpty);
      final inner = unixfs_pb.Data.fromBuffer(link.pbNode.data);
      expect(inner.type, unixfs_pb.Data_DataType.Symlink);
    });

    test('resolves a relative symlink', () async {
      final file = await createRawFile([1, 2, 3]);
      final link = await createSymlink(store, 'file.txt');
      final dirWithLink = await createDir([
        UnixFSDirectoryEntry(name: 'file.txt', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'link', cid: link.cid, tsize: 0),
      ]);
      final rootWithDir = await createDir([
        UnixFSDirectoryEntry(name: 'dir', cid: dirWithLink.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(rootWithDir.cid, 'dir/link');
      expect(resolved, file.cid);
    });

    test('resolves an absolute symlink', () async {
      final file = await createRawFile([4, 5, 6]);
      final link = await createSymlink(store, '/file.txt');
      final dirWithLink = await createDir([
        UnixFSDirectoryEntry(name: 'link', cid: link.cid, tsize: 0),
      ]);
      final rootWithDir = await createDir([
        UnixFSDirectoryEntry(name: 'file.txt', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'dir', cid: dirWithLink.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(rootWithDir.cid, 'dir/link');
      expect(resolved, file.cid);
    });

    test('resolves symlink target containing ..', () async {
      final file = await createRawFile([7, 8, 9]);
      final link = await createSymlink(store, '../file.txt');
      final dirWithLink = await createDir([
        UnixFSDirectoryEntry(name: 'link', cid: link.cid, tsize: 0),
      ]);
      final rootWithDir = await createDir([
        UnixFSDirectoryEntry(name: 'file.txt', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'dir', cid: dirWithLink.cid, tsize: 0),
      ]);

      final resolved = await resolver.resolve(rootWithDir.cid, 'dir/link');
      expect(resolved, file.cid);
    });

    test('rejects symlink target that escapes root', () async {
      final link = await createSymlink(store, '../outside');
      final root = await createDir([
        UnixFSDirectoryEntry(name: 'link', cid: link.cid, tsize: 0),
      ]);

      expect(
        () => resolver.resolve(root.cid, 'link'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('detects symlink cycle', () async {
      final linkA = await createSymlink(store, 'b');
      final linkB = await createSymlink(store, 'a');
      final dir = await createDir([
        UnixFSDirectoryEntry(name: 'a', cid: linkA.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'b', cid: linkB.cid, tsize: 0),
      ]);

      expect(
        () => resolver.resolve(dir.cid, 'a'),
        throwsA(isA<SymlinkCycleError>()),
      );
    });
  });

  group('UnixFS HAMT Sharded Directory', () {
    late IBlockStore store;
    late UnixFSPathResolver resolver;

    setUp(() async {
      store = MockBlockStore();
      await store.start();
      resolver = UnixFSPathResolver(store: store);
    });

    Future<Block> createRawFile(List<int> data) async {
      final block = await Block.fromData(
        Uint8List.fromList(data),
        format: 'raw',
      );
      await store.putBlock(block);
      return block;
    }

    Future<UnixFSNode> buildHAMT() async {
      final entries = <UnixFSDirectoryEntry>[];
      for (var i = 0; i < 257; i++) {
        final file = await createRawFile([i & 0xff]);
        entries.add(
          UnixFSDirectoryEntry(name: 'file_$i.txt', cid: file.cid, tsize: 0),
        );
      }
      return UnixFSHAMTBuilder(
        fanout: 256,
        shardThreshold: 1,
        maxBucketSize: 1,
      ).build(store, entries);
    }

    test('builds a HAMT shard node', () async {
      final root = await buildHAMT();
      expect(root.isHAMTShard, isTrue);
      expect(root.hashType, kUnixFSHAMTHashType);
      expect(root.fanout, 256);
      expect(root.pbNode.links, isNotEmpty);
      expect(root.pbNode.data, isNotEmpty);
      final inner = unixfs_pb.Data.fromBuffer(root.pbNode.data);
      expect(inner.type, unixfs_pb.Data_DataType.HAMTShard);
      expect(inner.hashType.toInt(), kUnixFSHAMTHashType);
      expect(inner.fanout.toInt(), 256);
      expect(inner.data.length, 256 ~/ 8);
    });

    test('resolves paths through HAMT shards', () async {
      final root = await buildHAMT();

      for (final i in [0, 128, 256]) {
        final resolved = await resolver.resolve(root.cid, 'file_$i.txt');
        expect(resolved, isNotNull);
      }
    });

    test('throws on missing HAMT path', () async {
      final root = await buildHAMT();
      expect(
        () => resolver.resolve(root.cid, 'not-present.txt'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('murmur3X64Hash64 produces deterministic output', () {
      final h1 = murmur3X64Hash64('hello'.codeUnits);
      final h2 = murmur3X64Hash64('hello'.codeUnits);
      expect(h1, h2);
      expect(h1, isNot(murmur3X64Hash64('world'.codeUnits)));
    });
  });
}
