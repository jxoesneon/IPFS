// Property-based tests for UnixFS chunking and building.
//
// These tests verify that the UnixFS builder produces valid DAG-PB structures
// and that file data can be round-tripped through the chunking process.
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block, IBlock, IBlockStore;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:test/test.dart';

import '../fuzz/_fuzz_helpers.dart';

void main() {
  final rng = makeRandom();

  group('UnixFS property-based tests', () {
    test(
      'for any file data: chunk -> build UnixFS -> root block is valid DAG-PB',
      () async {
        for (var i = 0; i < 50; i++) {
          final data = randomBytesRange(rng, 0, 500_000);
          final builder = UnixFSBuilder();
          final blocks = <Block>[];
          await for (final block in builder.build(_toStream(data))) {
            blocks.add(block);
          }
          // The last block is the root.
          final root = blocks.last;
          expect(root.cid.codec, equals('dag-pb'));
          // Decode the root as a PBNode.
          final pbNode = dag_pb.PBNode.fromBuffer(root.data);
          // Decode the inner UnixFS Data.
          final unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
          expect(unixfsData.type, equals(unixfs_pb.Data_DataType.File));
          expect(unixfsData.filesize.toInt(), equals(data.length));
          // The number of links should match the number of leaf blocks.
          expect(pbNode.links.length, equals(blocks.length - 1));
          // blocksizes should match leaf count.
          expect(unixfsData.blocksizes.length, equals(blocks.length - 1));
        }
      },
    );

    test(
      'chunk size property: different chunk sizes produce valid UnixFS',
      () async {
        // The builder uses a fixed default chunk size, but we can verify that
        // data larger than the chunk size produces multiple leaf blocks.
        final largeData = randomBytes(rng, 600_000); // > 256KB default chunk
        final builder = UnixFSBuilder();
        final blocks = <Block>[];
        await for (final block in builder.build(_toStream(largeData))) {
          blocks.add(block);
        }
        // Should produce at least 2 leaf blocks + 1 root.
        expect(blocks.length, greaterThan(1));
        // The sum of leaf block sizes should equal the total data size.
        final leafBlocks = blocks.sublist(0, blocks.length - 1);
        // Leaf data includes UnixFS wrapping, so we check via the inner Data.
        final root = blocks.last;
        final pbNode = dag_pb.PBNode.fromBuffer(root.data);
        final unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
        var sumBlocksizes = 0;
        for (final bs in unixfsData.blocksizes) {
          sumBlocksizes += bs.toInt();
        }
        expect(sumBlocksizes, equals(largeData.length));
        // Verify each leaf block is non-empty.
        for (final leaf in leafBlocks) {
          expect(leaf.data, isNotEmpty);
        }
      },
    );

    test(
      'small file (single chunk): root has one link and correct filesize',
      () async {
        final data = randomBytesRange(rng, 1, 1000);
        final builder = UnixFSBuilder();
        final blocks = <Block>[];
        await for (final block in builder.build(_toStream(data))) {
          blocks.add(block);
        }
        // Small data fits in one chunk: 1 leaf + 1 root.
        expect(blocks.length, equals(2));
        final root = blocks.last;
        final pbNode = dag_pb.PBNode.fromBuffer(root.data);
        final unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
        expect(unixfsData.filesize.toInt(), equals(data.length));
        expect(pbNode.links.length, equals(1));
      },
    );

    test('empty file: produces a valid root with zero links', () async {
      final builder = UnixFSBuilder();
      final blocks = <Block>[];
      await for (final block in builder.build(_toStream(Uint8List(0)))) {
        blocks.add(block);
      }
      // Empty stream: just a root with no links.
      expect(blocks.length, equals(1));
      final root = blocks.last;
      final pbNode = dag_pb.PBNode.fromBuffer(root.data);
      final unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
      expect(unixfsData.filesize.toInt(), equals(0));
      expect(pbNode.links.length, equals(0));
    });

    test(
      'leaf blocks can be decoded as UnixFSNode and contain original data',
      () async {
        final data = randomBytesRange(rng, 100, 5000);
        final builder = UnixFSBuilder();
        final blocks = <Block>[];
        await for (final block in builder.build(_toStream(data))) {
          blocks.add(block);
        }
        final leafBlocks = blocks.sublist(0, blocks.length - 1);
        // Decode each leaf and verify it contains file data.
        var reassembled = <int>[];
        for (final leaf in leafBlocks) {
          final node = UnixFSNode.fromBlock(leaf);
          expect(node.isFile, isTrue);
          if (node.unixfsData != null) {
            reassembled.addAll(node.unixfsData!.data);
          }
        }
        expect(reassembled, equals(data.toList()));
      },
    );

    test('root CID is deterministic: same data -> same root CID', () async {
      final data = randomBytesRange(rng, 100, 10_000);
      final builder1 = UnixFSBuilder();
      final blocks1 = <Block>[];
      await for (final block in builder1.build(_toStream(data))) {
        blocks1.add(block);
      }
      final builder2 = UnixFSBuilder();
      final blocks2 = <Block>[];
      await for (final block in builder2.build(_toStream(data))) {
        blocks2.add(block);
      }
      expect(blocks2.last.cid, equals(blocks1.last.cid));
    });

    test('different data produces different root CIDs', () async {
      for (var i = 0; i < 30; i++) {
        final data1 = randomBytesRange(rng, 100, 10_000);
        final data2 = randomBytesRange(rng, 100, 10_000);
        if (!_bytesEqual(data1, data2)) {
          final cid1 = await _buildRootCid(data1);
          final cid2 = await _buildRootCid(data2);
          expect(cid1, isNot(equals(cid2)));
        }
      }
    });

    test('rawLeaves option produces raw-codec leaf blocks', () async {
      final data = randomBytesRange(rng, 100, 5000);
      final builder = UnixFSBuilder(rawLeaves: true);
      final blocks = <Block>[];
      await for (final block in builder.build(_toStream(data))) {
        blocks.add(block);
      }
      final leafBlocks = blocks.sublist(0, blocks.length - 1);
      for (final leaf in leafBlocks) {
        expect(leaf.cid.codec, equals('raw'));
        // Raw leaf data is the original chunk data.
        expect(leaf.data.length, lessThanOrEqualTo(data.length));
      }
      // Reassemble raw leaves.
      var reassembled = <int>[];
      for (final leaf in leafBlocks) {
        reassembled.addAll(leaf.data);
      }
      expect(reassembled, equals(data.toList()));
    });

    test('CIDv0 option produces CIDv0 blocks', () async {
      final data = randomBytesRange(rng, 100, 5000);
      final builder = UnixFSBuilder(cidVersion: 0);
      final blocks = <Block>[];
      await for (final block in builder.build(_toStream(data))) {
        blocks.add(block);
      }
      for (final block in blocks) {
        expect(block.cid.version, equals(0));
        expect(block.cid.codec, equals('dag-pb'));
      }
    });
  });
}

/// Converts a [Uint8List] into a single-element stream of bytes.
Stream<List<int>> _toStream(Uint8List data) {
  return Stream.value(data.toList());
}

/// Builds a UnixFS DAG from [data] and returns the root CID.
Future<CID> _buildRootCid(Uint8List data) async {
  final builder = UnixFSBuilder();
  final blocks = <Block>[];
  await for (final block in builder.build(_toStream(data))) {
    blocks.add(block);
  }
  return blocks.last.cid;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
