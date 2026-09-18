@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

/// End-to-end tests between two real IPFSNode instances talking over
/// loopback libp2p.
///
/// `ServiceContainer` wraps the global GetIt registry, so lazily-resolved
/// getters (`addresses`, `dhtHandler`, keys, `pinnedCids`) only return the
/// correct services for the most recently built node. A is created first
/// and its lazily-resolved handles are captured before B exists; every
/// other call on both nodes goes through eagerly-injected managers, which
/// always point at the right node's own services.
void main() {
  group('E2E two-node network', () {
    late Directory repoA;
    late Directory repoB;
    IPFSNode? nodeA;
    IPFSNode? nodeB;
    DHTHandler? aDht;

    /// Creates A first (capturing its lazily-resolved handles while it owns
    /// the shared registry), then creates and starts B. Returns A's
    /// dialable multiaddr.
    Future<String> startBoth() async {
      repoA = await makeRepoDir('nodeA');
      nodeA = await IPFSNode.create(onlineConfig(repoA.path));
      await nodeA!.start();
      final aAddr = dialAddress(nodeA!);
      aDht = nodeA!.dhtHandler;

      repoB = await makeRepoDir('nodeB');
      nodeB = await IPFSNode.create(onlineConfig(repoB.path));
      await nodeB!.start();

      return aAddr;
    }

    tearDown(() async {
      await stopQuietly(nodeA);
      await stopQuietly(nodeB);
      await deleteRepo(repoA);
      await deleteRepo(repoB);
    });

    test('connectToPeer links the nodes and both report the peer', () async {
      final aAddr = await startBoth();

      await nodeB!.connectToPeer(aAddr);

      final bPeers = await waitFor<List<String>>(
        () async => (await nodeB!.connectedPeers).isNotEmpty
            ? nodeB!.connectedPeers
            : null,
        description: 'B to report A as connected',
      );
      expect(bPeers, contains(nodeA!.peerID));

      final aPeers = await waitFor<List<String>>(
        () async => (await nodeA!.connectedPeers).isNotEmpty
            ? nodeA!.connectedPeers
            : null,
        description: 'A to report B as connected',
      );
      expect(aPeers, contains(nodeB!.peerID));
    });

    test('B fetches a block from A over Bitswap', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      final data = utf8Bytes('bitswap block payload');
      final cid = await nodeA!.addFile(data);

      final fetched = await waitFor<Uint8List>(
        () async => nodeB!.cat(cid),
        timeout: const Duration(seconds: 30),
        description: 'B to fetch block via Bitswap',
      );
      expect(fetched, equals(data));

      // The fetched block is now cached locally on B.
      expect(await nodeB!.cat(cid), equals(data));
    });

    test('pubsub delivers a signed message from B to subscriber A', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      final received = <String>[];
      final sub = nodeA!.pubsubMessages.listen(
        (m) => received.add('${m.topic}:${m.content}'),
      );

      await nodeA!.subscribe('news');
      await nodeB!.subscribe('news');

      // Wait until both nodes have learned each other's subscription
      // announcement so B has a publish target.
      await waitFor<bool>(
        () async => (await nodeA!.pubsubPeers('news')).contains(nodeB!.peerID)
            ? true
            : null,
        description: 'A to see B subscribed to news',
      );
      await waitFor<bool>(
        () async => (await nodeB!.pubsubPeers('news')).contains(nodeA!.peerID)
            ? true
            : null,
        description: 'B to see A subscribed to news',
      );

      await nodeB!.publish('news', 'hello from B');

      await waitFor<bool>(
        () async => received.isNotEmpty ? true : null,
        description: 'A to receive the published message',
      );
      expect(received, contains('news:hello from B'));
      await sub.cancel();
    });

    test('pubsubLs tracks subscriptions and unsubscribe announces', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      await nodeA!.subscribe('t1');
      await nodeA!.subscribe('t2');
      expect(nodeA!.pubsubLs(), containsAll(<String>['t1', 't2']));

      await nodeA!.unsubscribe('t1');
      expect(nodeA!.pubsubLs(), isNot(contains('t1')));
      expect(nodeA!.pubsubLs(), contains('t2'));
    });

    test('B resolves an IPNS name published by A over the DHT', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      final cid = await nodeA!.addFile(utf8Bytes('ipns over dht'));
      final name = await nodeA!.publishIPNS(cid, keyName: 'self');
      expect(name, isNotEmpty);

      final resolved = await waitFor<String>(
        () async {
          try {
            final r = await nodeB!.resolveIPNS(name);
            return r.isNotEmpty ? r : null;
          } catch (_) {
            return null;
          }
        },
        timeout: const Duration(seconds: 30),
        description: 'B to resolve A\'s IPNS record via PUT_VALUE/GET_VALUE',
      );
      expect(resolved, equals('/ipfs/$cid'));
    });

    test('B discovers A as a provider via findProviders', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      // Content A holds but B has never fetched — B's local block check
      // must not short-circuit provider discovery.
      final cid = await nodeA!.addFile(utf8Bytes('provided by A'));
      await aDht!.provide(CID.decode(cid));

      final providers = await waitFor<List<String>>(
        () async {
          final p = await nodeB!.findProviders(cid);
          return p.isNotEmpty ? p : null;
        },
        timeout: const Duration(seconds: 30),
        description: 'B to discover A as provider',
      );
      expect(providers, contains(nodeA!.peerID));
    });

    test('disconnectFromPeer drops the connection', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      await waitFor<List<String>>(
        () async => (await nodeB!.connectedPeers).isNotEmpty
            ? nodeB!.connectedPeers
            : null,
        description: 'B connected to A',
      );

      await nodeB!.disconnectFromPeer(nodeA!.peerID);

      await waitFor<bool>(
        () async => (await nodeB!.connectedPeers).isEmpty ? true : null,
        description: 'B to report no connected peers',
      );
      expect(await nodeB!.connectedPeers, isEmpty);
    });

    test('requestBlock pulls a specific block from a peer', () async {
      final aAddr = await startBoth();
      await nodeB!.connectToPeer(aAddr);

      final data = utf8Bytes('explicit request');
      final cid = await nodeA!.addFile(data);

      await waitFor<bool>(
        () async {
          try {
            await nodeB!.requestBlock(cid, Peer.fromId(nodeA!.peerID));
            return true;
          } catch (_) {
            return null;
          }
        },
        timeout: const Duration(seconds: 30),
        description: 'B to request the block from A',
      );

      expect(await nodeB!.cat(cid), equals(data));
    });
  });
}
