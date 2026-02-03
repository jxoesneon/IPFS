import 'package:collection/collection.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';

/// Extension for finding closest peers in Kademlia tree.
extension FindClosestPeers on KademliaTree {
  /// Finds the [k] closest peers to [target] by XOR distance.
  List<PeerId> findClosestPeers(PeerId target, int k) {
    // Create a priority queue to store peers based on distance
    PriorityQueue<KademliaTreeNode> queue = PriorityQueue<KademliaTreeNode>((
      KademliaTreeNode a,
      KademliaTreeNode b,
    ) {
      return calculateDistance(
        target,
        a.peerId,
      ).compareTo(calculateDistance(target, b.peerId));
    });

    // Add all nodes from all buckets to the priority queue
    for (var bucket in buckets) {
      for (var nodeEntry in bucket.entries) {
        queue.add(nodeEntry.value);
      }
    }

    // Retrieve the k closest peers from the priority queue
    List<PeerId> closestPeers = [];
    for (int i = 0; i < k && queue.isNotEmpty; i++) {
      final node = queue.removeFirst();
      closestPeers.add(node.peerId);
    }

    return closestPeers;
  }
}
