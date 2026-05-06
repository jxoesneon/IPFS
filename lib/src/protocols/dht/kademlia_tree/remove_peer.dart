import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';

import 'helpers.dart';

/// Extension for removing peers from a Kademlia tree.
extension RemovePeer on KademliaTree {
  /// Removes [peerId] from the tree and handles bucket merging.
  void removePeer(PeerId peerId) {
    int distance = calculateDistance(peerId, root!.peerId);
    int bucketIndex = getBucketIndex(distance);

    // Remove from the RedBlackTree
    buckets[bucketIndex].delete(peerId);

    // Clean up lastSeen map
    lastSeen.remove(peerId);

    // Handle bucket emptiness - merging with other buckets
    if (buckets[bucketIndex].isEmpty && buckets.length > 1) {
      // 1. Try merging with the previous bucket
      if (bucketIndex > 0) {
        mergeBuckets(bucketIndex, bucketIndex - 1);
        // Note: bucketIndex might now be the index of a different bucket or out of bounds
        // If we merged with previous, the current bucketIndex now points to what was bucketIndex + 1
      }
      
      // 2. Try merging with the next bucket (if still within bounds)
      // We need to re-check the index after the first merge
      int newIndex = bucketIndex > 0 ? bucketIndex - 1 : bucketIndex;
      if (newIndex < buckets.length - 1) {
        mergeBuckets(newIndex, newIndex + 1);
      }
    }
  }
}
