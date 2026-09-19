import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/remove_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/red_black_tree.dart';

/// Extension for periodic refresh of Kademlia tree buckets.
extension Refresh on KademliaTree {
  /// Refreshes buckets by evicting stale peers.
  void refresh() {
    // 1. Iterate through buckets and check the last seen time of each peer
    // Use List.from to avoid ConcurrentModificationError when buckets are merged/removed
    final Set<PeerId> peersInBuckets = {};
    for (final RedBlackTree<PeerId, KademliaTreeNode> bucket in List.from(
      buckets,
    )) {
      // Use List.from on entries to avoid ConcurrentModificationError if entries are modified
      for (final MapEntry<PeerId, KademliaTreeNode> nodeEntry in List.from(
        bucket.entries,
      )) {
        final PeerId peerId = nodeEntry.key;
        peersInBuckets.add(peerId);
        // Check if the peer has been seen recently
        DateTime? lastSeenTime = lastSeen[peerId];
        if (lastSeenTime != null &&
            DateTime.now().difference(lastSeenTime) >
                KademliaTree.refreshTimeout) {
          // 2. Evict stale peers
          removePeer(peerId);
          lastSeen.remove(peerId);
        } else {
          // If the peer is not stale, update last seen time to current time
          lastSeen[peerId] = DateTime.now();
        }
      }
    }

    // 3. Drop lastSeen entries for peers no longer in any bucket. Other
    // removal paths (e.g. the routing table evicting peers directly from
    // buckets) bypass removePeer, which would otherwise leave these entries
    // orphaned forever.
    lastSeen.removeWhere(
      (PeerId peerId, DateTime _) => !peersInBuckets.contains(peerId),
    );
  }
}
