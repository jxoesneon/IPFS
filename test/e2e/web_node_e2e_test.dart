@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
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
