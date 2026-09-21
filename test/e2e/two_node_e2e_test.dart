// Real two-node libp2p traffic needs reliable loopback scheduling; on
// GitHub's shared-tenant Windows/macOS runners every transfer starves past
// its budget even though dialing succeeds. Signal lives on Linux.
@TestOn('vm && !windows && !mac-os')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

/// End-to-end tests between two real IPFSNode instances talking over
/// loopback libp2p.
///
/// Each node resolves lazily-fetched services (`addresses`, `dhtHandler`,
/// `securityManager`, `bitswap`, keys, `pinnedCids`) from its own scoped
/// `ServiceContainer`, so creating node B never affects what node A's
/// getters return.
void main() {
  group(
    'E2E two-node network',
    // Two real nodes plus DHT rounds exceed the 30s default on slower
    // CI runners (notably Windows loopback).
    timeout: const Timeout.factor(3),
    () {
      late Directory repoA;
      late Directory repoB;
      IPFSNode? nodeA;
      IPFSNode? nodeB;

      /// Creates and starts A, then creates and starts B. Returns A's
      /// dialable multiaddr.
      Future<String> startBoth() async {
        repoA = await makeRepoDir('nodeA');
        nodeA = await IPFSNode.create(onlineConfig(repoA.path));
        await nodeA!.start();
        final aAddr = dialAddress(nodeA!);

        repoB = await makeRepoDir('nodeB');
        nodeB = await IPFSNode.create(onlineConfig(repoB.path));
        await nodeB!.start();

        // Regression check for the node-scoped service containers: A's
        // lazily-resolved services must still be A's own after B exists.
        expect(nodeA!.securityManager, isNot(same(nodeB!.securityManager)));
        expect(nodeA!.dhtHandler, isNot(same(nodeB!.dhtHandler)));
        expect(nodeA!.bitswap, isNot(same(nodeB!.bitswap)));
        expect(nodeA!.blockStore, isNot(same(nodeB!.blockStore)));
        expect(nodeA!.datastore, isNot(same(nodeB!.datastore)));

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
          timeout: const Duration(seconds: 60),
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
        await nodeA!.securityManager.unlockKeystore('e2e-keystore-password');
        await nodeA!.securityManager.generateSecureKey('self');
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
          timeout: const Duration(seconds: 60),
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
        await nodeA!.dhtHandler!.provide(CID.decode(cid));

        final providers = await waitFor<List<String>>(
          () async {
            final p = await nodeB!.findProviders(cid);
            return p.isNotEmpty ? p : null;
          },
          timeout: const Duration(seconds: 60),
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

      test('reconnect restores pubsub delivery after a dropped peer', () async {
        final aAddr = await startBoth();
        await nodeB!.connectToPeer(aAddr);

        await nodeA!.subscribe('reconnect-topic');
        await nodeB!.subscribe('reconnect-topic');

        final received = <String>[];
        final sub = nodeA!.pubsubMessages.listen(
          (m) => received.add('${m.topic}:${m.content}'),
        );

        // Drop the connection, then dial again — the gossipsub session
        // stream must be re-established and subscription state re-announced.
        await nodeB!.disconnectFromPeer(nodeA!.peerID);
        await waitFor<bool>(
          () async => (await nodeB!.connectedPeers).isEmpty ? true : null,
          description: 'B to drop A',
        );

        await nodeB!.connectToPeer(aAddr);
        await waitFor<bool>(
          () async =>
              (await nodeA!.pubsubPeers(
                'reconnect-topic',
              )).contains(nodeB!.peerID)
              ? true
              : null,
          timeout: const Duration(seconds: 60),
          description: 'A to re-learn B subscribed after reconnect',
        );

        await nodeB!.publish('reconnect-topic', 'back online');
        await waitFor<bool>(
          () async => received.isNotEmpty ? true : null,
          description: 'A to receive the post-reconnect message',
        );
        expect(received, contains('reconnect-topic:back online'));
        await sub.cancel();
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
          timeout: const Duration(seconds: 60),
          description: 'B to request the block from A',
        );

        expect(await nodeB!.cat(cid), equals(data));
      });

      test('connectToPeer rejects a malformed multiaddr', () async {
        await startBoth();

        await expectLater(
          nodeB!.connectToPeer('definitely-not-a-multiaddr'),
          throwsA(anything),
        );
        expect(await nodeB!.connectedPeers, isEmpty);
      });

      test('connection seeds the DHT routing table', () async {
        final aAddr = await startBoth();
        await nodeB!.connectToPeer(aAddr);

        await waitFor<bool>(
          () async => nodeB!.dhtPeerCount >= 1 ? true : null,
          description: 'B to learn at least one DHT peer',
        );
        expect(nodeB!.dhtPeerCount, greaterThanOrEqualTo(1));
      });

      test('resolvePeerId returns addresses for a connected peer', () async {
        final aAddr = await startBoth();
        await nodeB!.connectToPeer(aAddr);

        final addrs = await waitFor<List<String>>(
          () async => nodeB!.resolvePeerId(nodeA!.peerID).isNotEmpty
              ? nodeB!.resolvePeerId(nodeA!.peerID)
              : null,
          description: 'B to resolve A\'s listen addresses',
        );
        expect(addrs, isNotEmpty);
        expect(addrs.first, contains('/p2p/'));
      });

      test('bandwidth counters move after a Bitswap transfer', () async {
        final aAddr = await startBoth();
        await nodeB!.connectToPeer(aAddr);

        final cid = await nodeA!.addFile(utf8Bytes('metered payload'));
        await waitFor<Uint8List>(
          () async => nodeB!.cat(cid),
          timeout: const Duration(seconds: 60),
          description: 'B to fetch block via Bitswap',
        );

        await waitFor<bool>(
          () async => nodeB!.bandwidthIn > 0 ? true : null,
          description: 'B inbound bandwidth counter to move',
        );
        // A's Bitswap ledger resolves from A's own scoped container even
        // though B was created afterwards.
        await waitFor<bool>(
          () async => nodeA!.bitswap!.bandwidthSent > 0 ? true : null,
          description: 'A outbound bandwidth counter to move',
        );
      });
    },
  );

  group('E2E facade messagesFor', () {
    late Directory repoA;
    late Directory repoB;
    IPFS? ipfsA;
    IPFSNode? nodeB;

    tearDown(() async {
      try {
        await ipfsA?.stop();
      } catch (_) {}
      await stopQuietly(nodeB);
      await deleteRepo(repoA);
      await deleteRepo(repoB);
    });

    test('messagesFor delivers only the requested topic', () async {
      repoA = await makeRepoDir('facadeA');
      ipfsA = await IPFS.create(config: onlineConfig(repoA.path));
      await ipfsA!.start();
      final aPeerId = ipfsA!.peerID;
      final aAddr =
          '${ipfsA!.addresses.firstWhere((a) => a.contains('/tcp/'))}'
          '/p2p/$aPeerId';

      repoB = await makeRepoDir('facadeB');
      nodeB = await IPFSNode.create(onlineConfig(repoB.path));
      await nodeB!.start();
      await nodeB!.connectToPeer(aAddr);

      final received = <String>[];
      final sub = ipfsA!
          .messagesFor('wanted')
          .listen((m) => received.add('${m.topic}:${m.content}'));

      await ipfsA!.subscribe('wanted');
      await ipfsA!.subscribe('other');
      await nodeB!.subscribe('wanted');
      await nodeB!.subscribe('other');

      await waitFor<bool>(
        () async => (await nodeB!.pubsubPeers('wanted')).contains(aPeerId)
            ? true
            : null,
        description: 'B to see A subscribed to wanted',
      );
      await waitFor<bool>(
        () async =>
            (await nodeB!.pubsubPeers('other')).contains(aPeerId) ? true : null,
        description: 'B to see A subscribed to other',
      );

      await nodeB!.publish('wanted', 'yes');
      await nodeB!.publish('other', 'no');

      await waitFor<bool>(
        () async => received.isNotEmpty ? true : null,
        description: 'A facade to receive the wanted message',
      );

      // The 'other' message must never pass the topic filter, even after
      // giving it time to arrive on the raw stream.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(received, contains('wanted:yes'));
      expect(received.every((m) => m.startsWith('wanted:')), isTrue);

      await sub.cancel();
    });
  });
}
