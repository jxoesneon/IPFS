import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'helpers.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';

/// Extension for removing peers from a Kademlia tree.
extension RemovePeer on KademliaTree {
  /// Removes [peerId] from the tree and handles bucket merging.
  void removePeer(p2p.PeerId peerId) {
    int distance = calculateDistance(peerId, root!.peerId);
    int bucketIndex = getBucketIndex(distance);

    // Remove from the RedBlackTree
    buckets[bucketIndex].delete(peerId);

    // Handle bucket emptiness - merging with other buckets
    if (buckets[bucketIndex].isEmpty) {
      // Check if the bucket can be merged with an adjacent bucket
      if (bucketIndex > 0 && bucketIndex < buckets.length - 1) {
        // Try merging with the previous or next bucket
        this.mergeBuckets(
          bucketIndex,
          bucketIndex - 1,
        ); // Use through KademliaTree instance
        this.mergeBuckets(
          bucketIndex,
          bucketIndex + 1,
        ); // Use through KademliaTree instance
      }
    }
  }
}
