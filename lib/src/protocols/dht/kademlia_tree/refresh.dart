// lib/src/protocols/dht/kademlia_tree/refresh.dart
import 'package:p2plib/p2plib.dart' as p2p;
import 'dart:async';

import 'remove_peer.dart'; // Import for removePeer
import '../kademlia_tree.dart'; // Import the main KademliaTree class
import '/../src/proto/dht/refresh.pb.dart' as refresh_pb;

extension Refresh on KademliaTree {
  /// Refreshes the Kademlia tree by periodically checking and updating buckets.
  void refresh() {
    // 1. Iterate through buckets and check the last seen time of each peer
    for (var bucket in _buckets) {
      for (var nodeEntry in bucket.entries) {
        // Check if the peer has been seen recently
        DateTime? lastSeenTime = _lastSeen[nodeEntry.key]; // Access last seen time using peerId
        if (lastSeenTime != null &&
            DateTime.now().difference(lastSeenTime) > refreshTimeout) {
          // 2. Evict stale peers
          removePeer(nodeEntry.key);
          _lastSeen.remove(nodeEntry.key); // Remove from last seen records
        } else {
          // If the peer has been seen recently, or is new, update last seen time
          _lastSeen[nodeEntry.key] = DateTime.now();
        }
      }
    }
  }

  // timeout for refresh
  final refreshTimeout = Duration(minutes: 30);

  // Assuming _lastSeen is a Map<p2p.PeerId, DateTime> to store last seen times for peers
  Map<p2p.PeerId, DateTime> _lastSeen = {};
}
