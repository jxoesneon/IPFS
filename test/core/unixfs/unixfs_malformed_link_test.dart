// test/core/unixfs/unixfs_malformed_link_test.dart
//
// A DAG-PB link target that is neither a valid CID nor a valid identity CID
// must surface the strict decoder's error. `tryDecodeCidBytesLenient`
// returns null for such targets, and every call site falls back to
// `CID.fromBytes` so the error the caller observes is the decoder's own
// rather than a null dereference.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_errors.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_reader.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_resolver.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '../../mocks/mock_block_store.dart';

/// A link target that is not a CID: too short, and not the identity layout
/// (`0x01 | codec | 0x00 | 0x00`) that the lenient decoder understands.
final Uint8List _malformedHash = Uint8List.fromList([0x02, 0x03]);

void main() {
  late IBlockStore store;

  setUp(() async {
    store = MockBlockStore();
    await store.start();
  });

  /// Builds a DAG-PB node with one link pointing at [_malformedHash] and
  /// stores it, returning the node block.
  Future<Block> storeNodeWithMalformedLink({
    required unixfs_pb.Data_DataType type,
    bool withBlocksizes = false,
  }) async {
    final node = dag_pb.PBNode(
      links: <dag_pb.PBLink>[
        dag_pb.PBLink(name: 'broken', hash: _malformedHash),
      ],
      data: unixfs_pb.Data(
        type: type,
        filesize: Int64(3),
        blocksizes: withBlocksizes ? [Int64(3)] : const [],
      ).writeToBuffer(),
    );
    final bytes = Uint8List.fromList(node.writeToBuffer());
    final cid = await CID.computeForData(bytes, format: 'dag-pb');
    final block = Block(cid: cid, data: bytes);
    await store.putBlock(block);
    return block;
  }

  /// Builds a UnixFS file node with no links and stores it.
  Future<Block> storeCleanFile() async {
    final node = dag_pb.PBNode(
      data: unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        filesize: Int64(3),
        blocksizes: [Int64(3)],
      ).writeToBuffer(),
    );
    final bytes = Uint8List.fromList(node.writeToBuffer());
    final cid = await CID.computeForData(bytes, format: 'dag-pb');
    final block = Block(cid: cid, data: bytes);
    await store.putBlock(block);
    return block;
  }

  group('malformed DAG-PB link targets surface the decoder error', () {
    test('computeTsize rejects a malformed child link', () async {
      final block = await storeNodeWithMalformedLink(
        type: unixfs_pb.Data_DataType.Directory,
      );

      await expectLater(
        computeTsize(store, block.cid),
        throwsA(isA<Exception>()),
      );
    });

    test('addChildToDirectory rejects a malformed sibling link', () async {
      // The existing directory carries the malformed link; the new child is
      // clean, so the failure comes from decoding the directory's own links.
      final block = await storeNodeWithMalformedLink(
        type: unixfs_pb.Data_DataType.Directory,
      );
      final child = await storeCleanFile();

      await expectLater(
        addChildToDirectory(store, block.cid, 'new.bin', child.cid),
        throwsA(isA<Exception>()),
      );
    });

    test('hamtLeafEntries rejects a malformed shard link', () async {
      final node = dag_pb.PBNode(
        links: <dag_pb.PBLink>[
          dag_pb.PBLink(name: 'broken', hash: _malformedHash),
        ],
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.HAMTShard,
          fanout: Int64(256),
        ).writeToBuffer(),
      );
      final bytes = Uint8List.fromList(node.writeToBuffer());
      final cid = await CID.computeForData(bytes, format: 'dag-pb');
      final shard = UnixFSNode.fromBlock(Block(cid: cid, data: bytes));

      await expectLater(
        hamtLeafEntries(store, shard),
        throwsA(isA<Exception>()),
      );
    });

    test('hamtLeafEntries walks a valid sub-shard link', () async {
      // A link whose name is exactly the prefix width addresses a child
      // shard; the shard block is not stored, so the walk reports it as
      // missing rather than silently skipping the link. The sub-shard fetch
      // is reported through `onFetch` so callers can charge it against a
      // traversal budget.
      final child = await storeCleanFile();
      final node = dag_pb.PBNode(
        links: <dag_pb.PBLink>[
          dag_pb.PBLink(name: 'ab', hash: child.cid.toBytes(), size: Int64(3)),
        ],
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.HAMTShard,
          fanout: Int64(256),
        ).writeToBuffer(),
      );
      final bytes = Uint8List.fromList(node.writeToBuffer());
      final cid = await CID.computeForData(bytes, format: 'dag-pb');
      final shard = UnixFSNode.fromBlock(Block(cid: cid, data: bytes));

      var fetches = 0;
      await expectLater(
        hamtLeafEntries(store, shard, onFetch: () => fetches++),
        throwsA(isA<PathResolutionError>()),
      );
      expect(fetches, equals(1));
    });

    test('unixfsReadFile rejects a malformed chunk link', () async {
      final block = await storeNodeWithMalformedLink(
        type: unixfs_pb.Data_DataType.File,
        withBlocksizes: true,
      );

      await expectLater(
        unixfsReadFile(block, (cid) async {
          final response = await store.getBlock(cid.encode());
          if (!response.found) return null;
          return Block(cid: cid, data: Uint8List.fromList(response.block.data));
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('UnixFSPathResolver rejects a malformed child link', () async {
      final block = await storeNodeWithMalformedLink(
        type: unixfs_pb.Data_DataType.Directory,
      );
      final resolver = UnixFSPathResolver(store: store);

      await expectLater(
        resolver.resolve(block.cid, 'broken'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
