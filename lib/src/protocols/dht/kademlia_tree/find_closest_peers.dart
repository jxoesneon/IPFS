// lib/src/protocols/dht/kademlia_tree/find_closest_peers.dart
import 'package:collection/collection.dart'; // Import for PriorityQueue
import 'package:p2plib/p2plib.dart' as p2p;
import 'dart:collection';
import 'helpers.dart'; // Import for _calculateDistance
import '../kademlia_tree.dart'; // Import the main KademliaTree class


extension FindClosestPeers on KademliaTree {
  /// Finds the k closest peers to a target peer ID.
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) {
    // Create a priority queue to store peers based on distance
    PriorityQueue<_KademliaNode> queue = PriorityQueue<_KademliaNode>(
      (_KademliaNode a, _KademliaNode b) =>
          _calculateDistance(target, a.peerId)
              .compareTo(_calculateDistance(target, b.peerId)),
    );

    // Add all nodes from all buckets to the priority queue
    for (var bucket in _buckets) {
      for (var nodeEntry in bucket.entries) {
        queue.add(nodeEntry.value);
      }
    }

    // Retrieve the k closest peers from the priority queue
    List<p2p.PeerId> closestPeers = [];
    for (int i = 0; i < k && queue.isNotEmpty; i++) {
      closestPeers.add(queue.removeFirst().peerId);
    }

    return closestPeers;
  }
}
