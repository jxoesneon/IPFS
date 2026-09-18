@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/web_block_store.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:test/test.dart';

import 'e2e_helpers.dart';

/// End-to-end journeys through [IPFSWebNode] on the IO platform.
///
/// WebBlockStore persists under relative paths (`blocks/`, `pins/`), so the
/// suite runs with the process working directory pointed at a temporary
/// repo — each test file executes in its own VM process, making this safe.
void main() {
  group('E2E IPFSWebNode', () {
    late Directory workDir;
    late Directory previousCwd;
    IPFSWebNode? node;

    setUpAll(() async {
      previousCwd = Directory.current;
      workDir = await Directory.systemTemp.createTemp('ipfs_web_e2e_');
      Directory.current = workDir;
    });

    tearDownAll(() async {
      Directory.current = previousCwd;
      await deleteRepo(workDir);
    });

    tearDown(() async {
      try {
        await node?.stop();
      } catch (_) {}
      node = null;
    });

    test('add and get round-trip content', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();
      expect(node!.isRunning, isTrue);
      expect(node!.peerID, isNotEmpty);

      final data = utf8Bytes('web node content');
      final cid = await node!.add(data);
      expect(cid.encode(), isNotEmpty);

      final fetched = await node!.get(cid.encode());
      expect(fetched, equals(data));
    });

    test('addStream reassembles chunked input', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      final chunk = utf8Bytes('stream-part');
      final cid = await node!.addStream(
        Stream<List<int>>.fromIterable(<List<int>>[chunk, chunk, chunk]),
      );

      final fetched = await node!.get(cid.encode());
      expect(
        fetched,
        equals(Uint8List.fromList(<int>[...chunk, ...chunk, ...chunk])),
      );
    });

    test('addStream of an empty stream produces an empty file', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      // An empty file is valid UnixFS content (zero-size file node).
      final cid = await node!.addStream(const Stream<List<int>>.empty());
      expect(cid.encode(), isNotEmpty);
      expect(await node!.get(cid.encode()), equals(Uint8List(0)));
    });

    test('get returns raw bytes for non-UnixFS dag-pb content', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      // A dag-pb block whose payload is not a decodable PBNode — content
      // falls back to the stored bytes rather than failing.
      final garbage = Uint8List.fromList(<int>[0x80]);
      final cid = await CID.fromContent(garbage, codec: 'dag-pb');
      final store = WebBlockStore(getPlatform());
      await store.putBlock(Block(cid: cid, data: garbage));

      expect(await node!.get(cid.encode()), equals(garbage));
    });

    test('get returns serialized bytes for non-file UnixFS nodes', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      // A directory node has no file payload; get surfaces the node bytes.
      final dirNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.Directory,
        ).writeToBuffer(),
      );
      final dirBytes = Uint8List.fromList(dirNode.writeToBuffer());
      final cid = await CID.fromContent(dirBytes, codec: 'dag-pb');
      final store = WebBlockStore(getPlatform());
      await store.putBlock(Block(cid: cid, data: dirBytes));

      expect(await node!.get(cid.encode()), equals(dirBytes));
    });

    test('get reassembles a file through a raw linked child', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      final childData = utf8Bytes('raw-leaf');
      final childCid = await CID.fromContent(childData, codec: 'raw');
      final store = WebBlockStore(getPlatform());
      await store.putBlock(Block(cid: childCid, data: childData));

      final fileNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
        ).writeToBuffer(),
        links: <dag_pb.PBLink>[dag_pb.PBLink(hash: childCid.toBytes())],
      );
      final rootBytes = Uint8List.fromList(fileNode.writeToBuffer());
      final rootCid = await CID.fromContent(rootBytes, codec: 'dag-pb');
      await store.putBlock(Block(cid: rootCid, data: rootBytes));

      expect(await node!.get(rootCid.encode()), equals(childData));
    });

    test(
      'get throws StateError when a linked child block is missing',
      () async {
        node = IPFSWebNode(config: IPFSConfig(offline: true));
        await node!.start();

        final missingCid = await CID.fromContent(
          Uint8List.fromList(<int>[1, 2, 3]),
          codec: 'raw',
        );
        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
          ).writeToBuffer(),
          links: <dag_pb.PBLink>[dag_pb.PBLink(hash: missingCid.toBytes())],
        );
        final rootBytes = Uint8List.fromList(fileNode.writeToBuffer());
        final rootCid = await CID.fromContent(rootBytes, codec: 'dag-pb');
        final store = WebBlockStore(getPlatform());
        await store.putBlock(Block(cid: rootCid, data: rootBytes));

        await expectLater(
          node!.get(rootCid.encode()),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('pin and listPins track pinned CIDs', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();

      final cid = await node!.add(utf8Bytes('pinned web content'));
      await node!.pin(cid);

      final pins = await node!.listPins();
      expect(pins, contains(cid.encode()));

      await node!.unpin(cid);
      expect(await node!.listPins(), isNot(contains(cid.encode())));
    });

    test('stop releases the node cleanly', () async {
      node = IPFSWebNode(config: IPFSConfig(offline: true));
      await node!.start();
      await node!.stop();
      expect(node!.isRunning, isFalse);
    });
  });
}
