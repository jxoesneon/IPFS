import 'dart:async';
import 'package:p2plib/p2plib.dart' as p2p;
import 'helpers.dart'; // Import for _calculateDistance, _findNode
import 'package:collection/collection.dart'; // Import for equality check
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart'; // Import the main KademliaTree class
// lib/src/protocols/dht/kademlia_tree/node_lookup.dart

extension NodeLookup on KademliaTree {
  // Constants moved to extension level
  static const int ALPHA = 3; // Number of concurrent queries
  static const int MAX_ITERATIONS = 20;
  static const int K = 20; // Number of closest peers to consider

  /// Performs an iterative node lookup for a target peer ID.
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    int iterations = 0;

    Set<p2p.PeerId> queriedPeers = {};
    List<p2p.PeerId> closestPeers = findClosestPeers(target, K);

    while (iterations++ < MAX_ITERATIONS) {
      List<p2p.PeerId> peersToQuery = closestPeers
          .where((p) => !queriedPeers.contains(p))
          .take(ALPHA)
          .toList();

      if (peersToQuery.isEmpty) break;

      List<p2p.PeerId> newClosestPeers = [];
      for (var peerId in peersToQuery) {
        try {
          List<p2p.PeerId> queriedPeers =
              await findNode(router.dhtClient, peerId, target);
          newClosestPeers.addAll(queriedPeers);
        } catch (e) {
          print('Error querying peer $peerId: $e');
        }
      }

      newClosestPeers.sort((a, b) =>
          calculateDistance(target, a).compareTo(calculateDistance(target, b)));
      newClosestPeers = newClosestPeers.take(K).toList();

      if (newClosestPeers.equals(closestPeers) ||
          newClosestPeers.contains(target)) {
        break;
      }

      closestPeers = newClosestPeers;
    }

    return closestPeers;
  }
}
