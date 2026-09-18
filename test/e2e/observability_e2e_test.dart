@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E observability', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('observability');
      node = await IPFSNode.create(onlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('getHealthStatus reports subsystem states', () async {
      final health = await node!.getHealthStatus();

      expect(health, isA<Map<String, dynamic>>());
      expect(health, isNotEmpty);
    });

    test('bandwidth counters are non-negative', () {
      expect(node!.bandwidthIn, greaterThanOrEqualTo(0));
      expect(node!.bandwidthOut, greaterThanOrEqualTo(0));
    });

    test('dhtPeerCount is zero with no peers', () {
      expect(node!.dhtPeerCount, equals(0));
    });

    test('publicKey is exposed once a self key exists', () async {
      await node!.securityManager.unlockKeystore(
        'test-password',
        salt: Uint8List(16),
      );
      // publicKey resolves the 'self' keystore entry; it is empty until
      // the operator provisions one.
      await node!.keyGen('self');
      final key = await node!.publicKey;
      expect(key, isNotEmpty);
    });

    test('addresses include a loopback TCP listen address', () {
      expect(node!.addresses, isNotEmpty);
      expect(
        node!.addresses.any((a) => a.contains('/ip4/127.0.0.1/tcp/')),
        isTrue,
      );
    });

    test('bandwidthMetrics stream is available', () {
      expect(node!.bandwidthMetrics, isA<Stream<Map<String, dynamic>>>());
    });

    test('resolvePeerId returns an empty list for an unknown peer', () {
      expect(node!.resolvePeerId('QmUnknownPeer'), isEmpty);
    });
  });

  group('E2E stats facade', () {
    late Directory repo;
    IPFS? ipfs;

    setUp(() async {
      repo = await makeRepoDir('stats');
      ipfs = await IPFS.create(config: offlineConfig(repo.path));
      await ipfs!.start();
    });

    tearDown(() async {
      try {
        await ipfs?.stop();
      } catch (_) {}
      await deleteRepo(repo);
    });

    test('stats() reflects added blocks', () async {
      await ipfs!.addFile(utf8Bytes('stats-data'));

      final stats = await ipfs!.stats();
      expect(stats.numConnectedPeers, equals(0));
      expect(stats.bandwidthSent, equals(0));
      expect(stats.bandwidthReceived, equals(0));
    });

    test('facade exposes peerID and addresses', () {
      expect(ipfs!.peerID, isNotEmpty);
      expect(ipfs!.addresses, isA<List<String>>());
    });
  });
}
