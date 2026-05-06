import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/cid.dart';

void main() {
  group('IPFSWebNode', () {
    late IPFSWebNode node;

    setUp(() {
      node = IPFSWebNode();
    });

    test('start and stop', () async {
      await node.start();
      expect(node.isRunning, isTrue);
      expect(node.peerID, isNotEmpty);

      await node.stop();
      expect(node.isRunning, isFalse);
    });

    test('add and get', () async {
      await node.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await node.add(data);

      final retrieved = await node.get(cid.encode());
      expect(retrieved, equals(data));

      final retrievedCat = await node.cat(cid);
      expect(retrievedCat, equals(data));
    });

    test('pinning', () async {
      await node.start();
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      await node.pin(cid);
      final pins = await node.listPins();
      expect(pins.any((p) => p.contains(cid.encode())), isTrue);

      await node.unpin(cid);
      final pins2 = await node.listPins();
      expect(pins2.any((p) => p.contains(cid.encode())), isFalse);
    });
  });
}
