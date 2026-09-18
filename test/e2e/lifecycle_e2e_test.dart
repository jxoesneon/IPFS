@TestOn('vm')
import 'dart:io';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E lifecycle', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('lifecycle');
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('offline node starts, serves content, and stops cleanly', () async {
      node = await IPFSNode.create(offlineConfig(repo.path));
      expect(node!.isRunning, isFalse);

      await node!.start();
      expect(node!.isRunning, isTrue);
      expect(node!.peerID, isNotEmpty);

      final cid = await node!.addFile(utf8Bytes('lifecycle'));
      expect(await node!.cat(cid), isNotNull);

      await node!.stop();
      expect(node!.isRunning, isFalse);
    });

    test(
      'online node starts with identity, addresses, and clean shutdown',
      () async {
        node = await IPFSNode.create(onlineConfig(repo.path));
        await node!.start();

        expect(node!.peerID, isNotEmpty);
        expect(node!.peerID, isNot(equals('offline')));
        expect(node!.addresses, isNotEmpty);
        expect(
          node!.addresses.any((a) => a.contains('/tcp/')),
          isTrue,
          reason: 'expected a TCP listen address in ${node!.addresses}',
        );
        expect(await node!.connectedPeers, isEmpty);

        await node!.stop();
        expect(node!.isRunning, isFalse);
      },
    );

    test('a second start on a running node throws NodeStateError', () async {
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();

      await expectLater(node!.start(), throwsStateError);
    });

    test('stop is idempotent', () async {
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();

      await node!.stop();
      await expectLater(node!.stop(), completes);
    });

    test('restart preserves identity and content', () async {
      node = await IPFSNode.create(onlineConfig(repo.path));
      await node!.start();
      final peerIdBefore = node!.peerID;
      final cid = await node!.addFile(utf8Bytes('restart-data'));

      await node!.restart();
      expect(node!.isRunning, isTrue);
      expect(node!.peerID, equals(peerIdBefore));
      expect(await node!.cat(cid), equals(utf8Bytes('restart-data')));
    });

    test('a new node on the same repo reuses the persisted identity', () async {
      node = await IPFSNode.create(onlineConfig(repo.path));
      await node!.start();
      final peerId = node!.peerID;
      await node!.stop();
      node = null;

      final node2 = await IPFSNode.create(onlineConfig(repo.path));
      try {
        await node2.start();
        expect(node2.peerID, equals(peerId));
      } finally {
        await stopQuietly(node2);
      }
    });

    test('a new node on the same repo sees persisted blocks', () async {
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
      final cid = await node!.addFile(utf8Bytes('durable'));
      await node!.stop();
      node = null;

      final node2 = await IPFSNode.create(offlineConfig(repo.path));
      try {
        await node2.start();
        expect(await node2.cat(cid), equals(utf8Bytes('durable')));
      } finally {
        await stopQuietly(node2);
      }
    });
  });
}
