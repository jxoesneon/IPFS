// lib/src/protocols/dht/kademlia_tree/node_lookup.dart
import 'package:collection/collection.dart'; // Import for equality check
import 'package:p2plib/p2plib.dart' as p2p;
import 'dart:async';

import 'find_closest_peers.dart'; // Import for findClosestPeers
import 'helpers.dart'; // Import for _calculateDistance, _findNode
import '../kademlia_tree.dart'; // Import the main KademliaTree class
import '../../../proto/generated/dht/node_lookup.pb.dart' as node_lookup_pb;
import '../../../proto/generated/dht/common_kademlia.pb.dart' as common_kademlia_pb;

extension NodeLookup on KademliaTree {
  /// Performs an iterative node lookup for a target peer ID.
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    // 1. Start with initial peers (closest peers to the target)
    int k = 20; // Number of closest peers to consider in each iteration (adjustable)
    List<p2p.PeerId> closestPeers = findClosestPeers(target, k);

    // 2. Iteratively query peers and update the closestPeers list
    while (true) {
      List<p2p.PeerId> newClosestPeers = [];
      for (var peerId in closestPeers) {
        // Query the peer identified by peerId for closer peers to the target
        try {
          // Assuming you have a method to send a FIND_NODE request
          List<p2p.PeerId> queriedPeers = await _findNode(peerId, target);
          newClosestPeers.addAll(queriedPeers);
        } catch (e) {
          // Handle potential errors during peer querying (e.g., timeout, network error)
          print('Error querying peer $peerId: $e');
        }
      }

      // 3. Sort and select the k closest peers
      newClosestPeers.sort((a, b) =>
          _calculateDistance(target, a).compareTo(_calculateDistance(target, b)));
      newClosestPeers = newClosestPeers.take(k).toList();

      // 4. Check for convergence or target found
      if (newClosestPeers.equals(closestPeers) ||
          newClosestPeers.contains(target)) {
        // Node lookup has converged or the target has been found
        break;
      }

      // 5. Update the closestPeers list for the next iteration
      closestPeers = newClosestPeers;
    }

    // 6. Return the closestPeers list
    return closestPeers;
  }
}
