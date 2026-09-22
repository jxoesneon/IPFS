import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_reader.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('unixfsReadFile', () {
    /// Builds the blocks for [data] and returns `(root, fetcher)` where
    /// `fetcher` resolves every emitted block by CID.
    Future<(Block, UnixFSBlockFetcher)> buildFile(
      Uint8List data, {
      bool rawLeaves = false,
    }) async {
      final blocks = <Block>[];
      await for (final block in UnixFSBuilder(
        rawLeaves: rawLeaves,
      ).build(Stream.value(data.toList()))) {
        blocks.add(block);
      }
      final byCid = {for (final b in blocks) b.cid.encode(): b};
      Future<Block?> fetch(CID cid) async => byCid[cid.encode()];
      return (blocks.last, fetch);
    }

    test('returns payload of a raw root block directly', () async {
      final payload = Uint8List.fromList(List.generate(64, (i) => i));
      final root = await Block.fromData(payload);

      final result = await unixfsReadFile(root, (_) async => null);
      expect(result, equals(payload));
    });

    test('reassembles a single-chunk UnixFS file', () async {
      final payload = Uint8List.fromList('hello unixfs'.codeUnits);
      final (root, fetch) = await buildFile(payload);

      final result = await unixfsReadFile(root, fetch);
      expect(result, equals(payload));
    });

    test('reassembles a multi-chunk UnixFS file in link order', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize * 2 + 1234);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = i % 251;
      }
      final (root, fetch) = await buildFile(payload);
      expect(root.cid.codec, equals('dag-pb'));

      final result = await unixfsReadFile(root, fetch);
      expect(result, equals(payload));
    });

    test('reassembles a multi-chunk file with raw leaves', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize + 100);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = i % 256;
      }
      final (root, fetch) = await buildFile(payload, rawLeaves: true);

      final result = await unixfsReadFile(root, fetch);
      expect(result, equals(payload));
    });

    test('returns stored bytes for a non-file (directory) node', () async {
      final dirData = unixfs_pb.Data(type: unixfs_pb.Data_DataType.Directory);
      final node = dag_pb.PBNode(data: dirData.writeToBuffer());
      final encoded = node.writeToBuffer();
      final root = Block(
        cid: await CID.fromContent(encoded, codec: 'dag-pb'),
        data: encoded,
        format: 'dag-pb',
      );

      final result = await unixfsReadFile(root, (_) async => null);
      expect(result, equals(encoded));
    });

    test('returns stored bytes for an unparseable dag-pb block', () async {
      final garbage = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0x01]);
      final root = Block(
        cid: await CID.fromContent(garbage, codec: 'dag-pb'),
        data: garbage,
        format: 'dag-pb',
      );

      final result = await unixfsReadFile(root, (_) async => null);
      expect(result, equals(garbage));
    });

    test('throws StateError when a linked block is missing', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize + 10);
      final (root, _) = await buildFile(payload);

      Future<Block?> missing(CID cid) async => null;
      expect(() => unixfsReadFile(root, missing), throwsA(isA<StateError>()));
    });

    test('throws StateError when traversal exceeds maxDepth', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize + 10);
      final (root, fetch) = await buildFile(payload);

      expect(
        () => unixfsReadFile(root, fetch, maxDepth: 0),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when traversal exceeds maxNodes', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize + 10);
      final (root, fetch) = await buildFile(payload);

      expect(
        () => unixfsReadFile(root, fetch, maxNodes: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when the payload exceeds maxBytes', () async {
      final payload = Uint8List(UnixFSBuilder.defaultChunkSize + 10);
      final (root, fetch) = await buildFile(payload);

      expect(
        () => unixfsReadFile(root, fetch, maxBytes: 10),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            startsWith(unixfsReadByteBudgetExceededPrefix),
          ),
        ),
      );
    });

    test('honors maxBytes when the payload fits exactly', () async {
      final payload = Uint8List.fromList('hello unixfs'.codeUnits);
      final (root, fetch) = await buildFile(payload);

      final result = await unixfsReadFile(
        root,
        fetch,
        maxBytes: payload.length,
      );
      expect(result, equals(payload));
    });

    test('byte budget applies to inline file data too', () async {
      final data = unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        data: Uint8List.fromList('inline payload'.codeUnits),
        filesize: Int64(14),
      );
      final node = dag_pb.PBNode(data: data.writeToBuffer());
      final encoded = node.writeToBuffer();
      final root = Block(
        cid: await CID.fromContent(encoded, codec: 'dag-pb'),
        data: encoded,
        format: 'dag-pb',
      );

      expect(
        () => unixfsReadFile(root, (_) async => null, maxBytes: 4),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            startsWith(unixfsReadByteBudgetExceededPrefix),
          ),
        ),
      );
    });

    test('reads a nested tree of intermediate file nodes', () async {
      // Build a two-level tree by hand: root links to an intermediate file
      // node which links to a leaf file node.
      final leafPayload = Uint8List.fromList('nested leaf'.codeUnits);
      final leafData = unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        data: leafPayload,
        filesize: Int64(leafPayload.length),
      );
      final leafNode = dag_pb.PBNode(data: leafData.writeToBuffer());
      final leafBytes = leafNode.writeToBuffer();
      final leaf = Block(
        cid: await CID.fromContent(leafBytes, codec: 'dag-pb'),
        data: leafBytes,
        format: 'dag-pb',
      );

      final midData = unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        filesize: Int64(leafPayload.length),
        blocksizes: [Int64(leafPayload.length)],
      );
      final midNode = dag_pb.PBNode(
        data: midData.writeToBuffer(),
        links: [
          dag_pb.PBLink(
            hash: leaf.cid.toBytes(),
            size: Int64(leafBytes.length),
          ),
        ],
      );
      final midBytes = midNode.writeToBuffer();
      final mid = Block(
        cid: await CID.fromContent(midBytes, codec: 'dag-pb'),
        data: midBytes,
        format: 'dag-pb',
      );

      final rootData = unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        data: Uint8List.fromList('root-inline '.codeUnits),
        filesize: Int64(leafPayload.length + 12),
        blocksizes: [Int64(leafPayload.length)],
      );
      final rootNode = dag_pb.PBNode(
        data: rootData.writeToBuffer(),
        links: [
          dag_pb.PBLink(hash: mid.cid.toBytes(), size: Int64(midBytes.length)),
        ],
      );
      final rootBytes = rootNode.writeToBuffer();
      final root = Block(
        cid: await CID.fromContent(rootBytes, codec: 'dag-pb'),
        data: rootBytes,
        format: 'dag-pb',
      );

      final byCid = {
        leaf.cid.encode(): leaf,
        mid.cid.encode(): mid,
        root.cid.encode(): root,
      };

      final result = await unixfsReadFile(
        root,
        (cid) async => byCid[cid.encode()],
      );
      expect(
        result,
        equals(
          Uint8List.fromList('root-inline '.codeUnits + leafPayload.toList()),
        ),
      );
    });
  });
}
