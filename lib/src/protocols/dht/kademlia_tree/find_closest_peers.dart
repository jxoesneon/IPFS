import 'dart:typed_data' show Uint8List;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:collection/collection.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia_node.pb.dart';
// lib/src/protocols/dht/kademlia_tree/find_closest_peers.dart


extension FindClosestPeers on KademliaTree {
  /// Finds the k closest peers to a target peer ID.
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) {
    // Create a priority queue to store peers based on distance
    PriorityQueue<KademliaNode> queue = PriorityQueue<KademliaNode>(
      (KademliaNode a, KademliaNode b) {
        // Convert KademliaId to PeerId before calculating distance
        final peerIdA = p2p.PeerId(value: Uint8List.fromList(a.peerId.id));
        final peerIdB = p2p.PeerId(value: Uint8List.fromList(b.peerId.id));
        return calculateDistance(target, peerIdA)
            .compareTo(calculateDistance(target, peerIdB));
      },
    );

    // Add all nodes from all buckets to the priority queue
    for (var bucket in buckets) {
      for (var nodeEntry in bucket.entries) {
        queue.add(nodeEntry.value);
      }
    }

    // Retrieve the k closest peers from the priority queue
    List<p2p.PeerId> closestPeers = [];
    for (int i = 0; i < k && queue.isNotEmpty; i++) {
      final node = queue.removeFirst();
      // Convert KademliaId to PeerId
      final peerId = p2p.PeerId(value: Uint8List.fromList(node.peerId.id));
      closestPeers.add(peerId);
    }

    return closestPeers;
  }
}
