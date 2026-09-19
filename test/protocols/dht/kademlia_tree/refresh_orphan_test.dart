import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/refresh.dart';
import 'package:test/test.dart';

import '../../../fakes/fake_router.dart';

/// Minimal [NetworkHandler] fake — the tree under test never reaches into it.
class _FakeNetworkHandler implements NetworkHandler {
  _FakeNetworkHandler(this.config);

  @override
  final IPFSConfig config;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('KademliaTree refresh lastSeen pruning', () {
    late DHTClient client;
    late KademliaTree tree;

    PeerId peerId(int byte) => PeerId(value: Uint8List(32)..[0] = byte);

    setUp(() {
      client = DHTClient(
        networkHandler: _FakeNetworkHandler(IPFSConfig()),
        router: FakeRouter(),
      );
      // Set the identity fields directly instead of running initialize() —
      // the tree only needs peerId for its root node.
      final local = PeerId(value: Uint8List(32));
      client.peerId = local;
      client.associatedPeerId = local;
      tree = KademliaTree(client);
    });

    tearDown(() {
      tree.stop();
    });

    test('refresh prunes lastSeen entries for peers no longer in buckets', () {
      final inBucket = peerId(0x01);
      final orphan = peerId(0x02);

      tree.addPeer(inBucket, inBucket);
      // An entry left behind by a removal path that bypassed
      // KademliaTree.removePeer (e.g. routing-table bucket eviction).
      tree.lastSeen[orphan] = DateTime.now();

      expect(tree.lastSeen.containsKey(orphan), isTrue);

      tree.refresh();

      expect(tree.lastSeen.containsKey(orphan), isFalse);
      expect(tree.lastSeen.containsKey(inBucket), isTrue);
    });

    test('refresh keeps live peers and evicts stale ones', () {
      final livePeer = peerId(0x03);
      final stalePeer = peerId(0x04);

      tree.addPeer(livePeer, livePeer);
      tree.addPeer(stalePeer, stalePeer);
      tree.lastSeen[stalePeer] = DateTime.now().subtract(
        KademliaTree.refreshTimeout + const Duration(minutes: 1),
      );

      tree.refresh();

      expect(tree.lastSeen.containsKey(livePeer), isTrue);
      expect(tree.lastSeen.containsKey(stalePeer), isFalse);
    });
  });
}
