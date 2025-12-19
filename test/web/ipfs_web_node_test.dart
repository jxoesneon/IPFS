@TestOn('browser')

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSWebNode', () {
    late IPFSWebNode node;

    setUp(() async {
      node = IPFSWebNode();
      await node.start();
    });

    tearDown(() async {
      await node.stop();
    });

    test('should start and set running state', () async {
      expect(node.isRunning, isTrue);
      expect(node.peerID, isNotEmpty);
      expect(node.peerID, startsWith('web-'));
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
      expect(pins, contains(cid.encode()));

      await node.unpin(cid);
      final pinsAfter = await node.listPins();
      expect(pinsAfter, isNot(contains(cid.encode())));
    });
  });
}
