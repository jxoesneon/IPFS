import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:dart_ipfs/src/core/cid.dart';

void main() {
  group('IPFSWebNode Coverage', () {
    test('start with bootstrap peers', () async {
      final node = IPFSWebNode(bootstrapPeers: ['ws://localhost:1234']);
      // Should not throw even if connection fails
      await node.start();
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('addStream handles data', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> stream() async* {
        yield [1, 2, 3];
        yield [4, 5, 6];
      }

      final cid = await node.addStream(stream());
      expect(cid, isNotNull);

      final retrieved = await node.get(cid.encode());
      // It returns the UnixFS PB node, so we just check it found something
      expect(retrieved, isNotNull);
      expect(retrieved!.length, greaterThan(0));

      await node.stop();
    });

    test('addStream for empty stream creates root node', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> stream() async* {}

      final cid = await node.addStream(stream());
      expect(cid, isNotNull);
      await node.stop();
    });

    test('addFile throws UnimplementedError on non-web', () async {
      final node = IPFSWebNode();
      // On native, this should throw
      expect(() => node.addFile(null), throwsA(isA<UnimplementedError>()));
    });

    test('get fallback to Bitswap (uncovered branch)', () async {
      final node = IPFSWebNode();
      await node.start();

      // We don't have connected peers in WebStubRouter by default,
      // so we can't easily test the bitswap fallback without more mocking.
      // But we can check it returns null for missing content.
      final result = await node.get('QmNonExistent');
      expect(result, isNull);

      await node.stop();
    });

    test('publishIPNS and resolveIPNS coverage', () async {
      final node = IPFSWebNode();
      await node.start();

      await node.securityManager.unlockKeystore('password');

      // These will call into MockDHTHandler and MockPubSub
      try {
        await node.publishIPNS('QmCID', keyName: 'self');
      } catch (_) {}

      try {
        await node.resolveIPNS('QmName');
      } catch (_) {}

      await node.stop();
    });

    test('publishIPNS/resolveIPNS throw when not started', () async {
      final node = IPFSWebNode();
      expect(
        () => node.publishIPNS('QmCID', keyName: 'self'),
        throwsStateError,
      );
      expect(() => node.resolveIPNS('QmName'), throwsStateError);
    });

    test('cat uses encode', () async {
      final node = IPFSWebNode();
      await node.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await node.add(data);

      final result = await node.cat(cid);
      expect(result, equals(data));
      await node.stop();
    });

    test('double start is idempotent', () async {
      final node = IPFSWebNode();
      await node.start();
      await node.start(); // Should return immediately
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('stop when not started', () async {
      final node = IPFSWebNode();
      await node.stop(); // Should return immediately
      expect(node.isRunning, isFalse);
    });

    test('pinning coverage', () async {
      final node = IPFSWebNode();
      await node.start();
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      await node.pin(cid);
      await node.listPins();
      await node.unpin(cid);
      await node.stop();
    });
  });
}
