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
    for (final RedBlackTree<PeerId, KademliaTreeNode> bucket in List.from(
      buckets,
    )) {
      // Use List.from on entries to avoid ConcurrentModificationError if entries are modified
      for (final MapEntry<PeerId, KademliaTreeNode> nodeEntry in List.from(
        bucket.entries,
      )) {
        final PeerId peerId = nodeEntry.key;
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
  }
}
