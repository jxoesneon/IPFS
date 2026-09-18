@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

/// Journeys across the remaining public surface: accessor wiring,
/// offline error contracts, and edge-case semantics that the feature
/// suites do not exercise.
void main() {
  group('E2E node accessors and state', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('surface');
      node = await IPFSNode.create(offlineConfig(repo.path));
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('state transitions across the lifecycle', () async {
      expect(node!.state, equals(NodeState.stopped));
      expect(node!.isRunning, isFalse);

      await node!.start();
      expect(node!.state, equals(NodeState.running));
      expect(node!.isRunning, isTrue);

      await node!.stop();
      expect(node!.state, equals(NodeState.stopped));
      expect(node!.isRunning, isFalse);
    });

    test('offline node exposes null network accessors', () async {
      await node!.start();

      expect(node!.router, isNull);
      expect(node!.bitswap, isNull);
      expect(node!.dhtHandler, isNull);
      expect(node!.ipns, isNull);
      expect(() => node!.dhtClient, throwsStateError);
    });

    test('offline node exposes storage and service accessors', () async {
      await node!.start();

      expect(node!.blockStore, isNotNull);
      expect(node!.datastore, isNotNull);
      expect(node!.metricsCollector, isNotNull);
      expect(node!.networkManager, isNotNull);
      // Optional services are nullable — the getter must not throw.
      node!.denylistService;
      node!.mobileCoordinator;
    });

    test('online node exposes wired protocol accessors', () async {
      await stopQuietly(node);
      node = await IPFSNode.create(onlineConfig(repo.path));
      await node!.start();

      expect(node!.router, isNotNull);
      expect(node!.bitswap, isNotNull);
      expect(node!.dhtHandler, isNotNull);
      expect(node!.ipns, isNotNull);
      expect(node!.dhtClient, isNotNull);
    });

    test('datastore supports direct put/get/has/delete/query', () async {
      await node!.start();
      final ds = node!.datastore;

      await ds.put(Key('/e2e/key1'), utf8Bytes('value1'));
      await ds.put(Key('/e2e/key2'), utf8Bytes('value2'));

      expect(await ds.get(Key('/e2e/key1')), equals(utf8Bytes('value1')));
      expect(await ds.has(Key('/e2e/key1')), isTrue);
      expect(await ds.has(Key('/e2e/missing')), isFalse);

      final seen = <String>{};
      await for (final entry in ds.query(Query(prefix: '/e2e/'))) {
        seen.add(entry.key.toString());
      }
      expect(seen, containsAll(<String>['/e2e/key1', '/e2e/key2']));

      await ds.delete(Key('/e2e/key1'));
      expect(await ds.has(Key('/e2e/key1')), isFalse);
      expect(await ds.get(Key('/e2e/key1')), isNull);
    });

    test('blockStore supports direct put/get/has/remove', () async {
      await node!.start();
      final store = node!.blockStore;

      final block = await Block.fromData(utf8Bytes('direct block'));
      final cidStr = block.cid.encode();

      expect(await store.hasBlock(cidStr), isFalse);
      await store.putBlock(block);
      expect(await store.hasBlock(cidStr), isTrue);

      final fetched = await store.getBlock(cidStr);
      expect(fetched.found, isTrue);

      await store.removeBlock(cidStr);
      expect(await store.hasBlock(cidStr), isFalse);
      final gone = await store.getBlock(cidStr);
      expect(gone.found, isFalse);
    });
  });

  group('E2E offline error contracts', () {
    late Directory repo;
    IPFSNode? node;
    IPFS? ipfs;

    setUp(() async {
      repo = await makeRepoDir('offline_errors');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      try {
        await ipfs?.stop();
      } catch (_) {}
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('connectToPeer rejects a malformed multiaddr offline', () async {
      // The network handler exists but is unstarted; a garbage address
      // must fail rather than silently succeed.
      await expectLater(
        node!.connectToPeer('definitely-not-a-multiaddr'),
        throwsA(anything),
      );
    });

    test('disconnectFromPeer is a silent no-op offline', () async {
      await node!.disconnectFromPeer('QmAnyPeer');
    });

    test('requestBlock fails offline', () async {
      final cid = await node!.addFile(utf8Bytes('x'));
      await expectLater(
        node!.requestBlock(cid, Peer.fromId('QmPeer')),
        throwsA(anything),
      );
    });

    test('publish fails when the pubsub client is unstarted', () async {
      // The handler exists but the client was never started — publishing
      // must fail loudly, not drop the message.
      await expectLater(node!.publish('topic', 'message'), throwsA(anything));
    });

    test('subscribe/unsubscribe and listing are no-ops offline', () async {
      await node!.subscribe('topic');
      await node!.unsubscribe('topic');
      expect(node!.pubsubLs(), isEmpty);
      expect(await node!.pubsubPeers('topic'), isEmpty);
    });

    test('resolveIPNS throws without a routing subsystem', () async {
      await expectLater(
        node!.resolveIPNS('k51_unknown_name'),
        throwsA(anything),
      );
    });

    test('publishIPNS throws without a routing subsystem', () async {
      final cid = await node!.addFile(utf8Bytes('x'));
      await expectLater(
        node!.publishIPNS(cid, keyName: 'self'),
        throwsA(anything),
      );
    });

    test('findProviders reports self for locally-held content', () async {
      final cid = await node!.addFile(utf8Bytes('local provider'));
      final providers = await node!.findProviders(cid);
      // Even offline, the node reports itself as the provider of
      // content it holds locally.
      expect(providers, equals(<String>[node!.peerID]));
    });

    test('findProviders returns empty for unknown content offline', () async {
      // A CID the node has never stored — no local hit, no network to ask.
      final cid = await node!.addFile(utf8Bytes('known'));
      await node!.datastore.delete(Key('/blocks/$cid'));
      final providers = await node!.findProviders(cid);
      expect(providers, isEmpty);
    });

    test('facade subscribe/unsubscribe are no-ops offline', () async {
      await stopQuietly(node);
      node = null;
      ipfs = await IPFS.create(config: offlineConfig(repo.path));
      await ipfs!.start();

      await ipfs!.subscribe('topic');
      await ipfs!.unsubscribe('topic');
      expect(ipfs!.pubsubLs(), isEmpty);
    });

    test('facade resolveIPNS and provide fail fast offline', () async {
      await stopQuietly(node);
      node = null;
      ipfs = await IPFS.create(config: offlineConfig(repo.path));
      await ipfs!.start();

      await expectLater(
        ipfs!.resolveIPNS('k51_unknown_name'),
        throwsA(anything),
      );
      await expectLater(ipfs!.provide('bafkrei_test'), throwsA(anything));
    });

    test('facade unpin throws on a never-pinned CID', () async {
      await stopQuietly(node);
      node = null;
      ipfs = await IPFS.create(config: offlineConfig(repo.path));
      await ipfs!.start();

      final cid = await ipfs!.addFile(utf8Bytes('unpinned'));
      await expectLater(ipfs!.unpin(cid), throwsA(anything));
    });
  });

  group('E2E edge-case semantics', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('edges');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('importCAR rejects malformed bytes', () async {
      await expectLater(
        node!.importCAR(Uint8List.fromList(<int>[1, 2, 3, 255, 0, 128])),
        throwsA(anything),
      );
    });

    test('importCAR rejects empty input', () async {
      await expectLater(node!.importCAR(Uint8List(0)), throwsA(anything));
    });

    test('get on a directory root returns its serialized node', () async {
      final dirCid = await node!.addDirectory(<String, dynamic>{
        'a.txt': utf8Bytes('A'),
      });
      final bytes = await node!.get(dirCid);
      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);
    });

    test('get with a path on a file CID returns null', () async {
      final cid = await node!.addFile(utf8Bytes('flat file'));
      expect(await node!.get(cid, path: 'child'), isNull);
    });

    test('addDirectory with an empty map produces a listable dir', () async {
      final dirCid = await node!.addDirectory(<String, dynamic>{});
      expect(dirCid, isNotEmpty);
      expect(await node!.ls(dirCid), isEmpty);
    });

    test('keyGen accepts and ignores an explicit size', () async {
      await node!.securityManager.unlockKeystore('pw', salt: Uint8List(16));
      final name = await node!.keyGen('sized', type: 'ed25519', size: 2048);
      expect(name, isNotEmpty);
      expect(await node!.keyList(), contains('sized'));
    });

    test('keystore round-trips survive stop/start', () async {
      await node!.securityManager.unlockKeystore('pw', salt: Uint8List(16));
      final name = await node!.keyGen('persisted');
      expect(name, isNotEmpty);
      await node!.stop();
      await node!.start();
      await node!.securityManager.unlockKeystore('pw', salt: Uint8List(16));
      expect(await node!.keyList(), contains('persisted'));
      final exported = await node!.keyExport('persisted');
      expect(exported, hasLength(32));
    });
  });
}
