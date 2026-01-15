import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:test/test.dart';

import 'dart:io';

@TestOn('vm || browser')
void main() {
  group('IPFSWebNode', () {
    late IPFSWebNode node;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ipfs_web_node_test_');
      final config = IPFSConfig(
        blockStorePath: tempDir.path,
        datastorePath: tempDir.path,
      );
      node = IPFSWebNode(config: config);
      await node.start();
    });

    tearDown(() async {
      await node.stop();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('should start and set running state', () async {
      expect(node.isRunning, isTrue);
      expect(node.peerID, isNotEmpty);
      // expect(node.peerID, startsWith('web-')); // Router in VM generates real ID
    });

    test('should add and retrieve content', () async {
      final content = Uint8List.fromList('Hello Web World'.codeUnits);
      final cid = await node.add(content);

      expect(cid, isNotNull);
      expect(cid.encode(), isNotEmpty);

      // Retrieve by String
      final retrieved = await node.get(cid.encode());
      expect(retrieved, isNotNull);
      expect(String.fromCharCodes(retrieved!), equals('Hello Web World'));

      // Retrieve by CID object
      final retrievedCat = await node.cat(cid);
      expect(retrievedCat, isNotNull);
      expect(retrievedCat, equals(retrieved));
    });

    test('should handle pinning', () async {
      final content = Uint8List.fromList('Pinned Content'.codeUnits);
      final cid = await node.add(content);

      await node.pin(cid);

      // We can't easily inspect the platform storage directly in unit tests
      // without mocking, but we can list pins
      final pins = await node.listPins();
      expect(pins, contains(anyOf(cid.encode(), 'pins/${cid.encode()}')));

      await node.unpin(cid);
      final pinsAfter = await node.listPins();
      expect(pinsAfter, isNot(contains(cid.encode())));
    });
    test('should addStream and retrieve content', () async {
      // Create a stream of data
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final stream = Stream<List<int>>.value(data);

      final cid = await node.addStream(stream);
      expect(cid, isNotNull);

      // Get the root block (UnixFS DAG-PB)
      final rootBlock = await node.get(cid.encode());
      expect(rootBlock, isNotNull);
      // Logic check: root block length should be > 0
      expect(rootBlock!.length, greaterThan(0));
    });
  });
}
