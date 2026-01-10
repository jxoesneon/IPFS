import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/remove_peer.dart';

/// Extension for periodic refresh of Kademlia tree buckets.
extension Refresh on KademliaTree {
  /// Refreshes buckets by evicting stale peers.
  void refresh() {
    // 1. Iterate through buckets and check the last seen time of each peer
    for (var bucket in buckets) {
      for (var nodeEntry in bucket.entries) {
        // Check if the peer has been seen recently
        DateTime? lastSeenTime = lastSeen[nodeEntry.key]; // Use the public getter instead
        if (lastSeenTime != null && DateTime.now().difference(lastSeenTime) > refreshTimeout) {
          // 2. Evict stale peers
          removePeer(nodeEntry.key);
          lastSeen.remove(nodeEntry.key); // Use the public getter
        } else {
          // If the peer has been seen recently, or is new, update last seen time
          lastSeen[nodeEntry.key] = DateTime.now(); // Use the public getter
        }
      }
    }
  }
}
