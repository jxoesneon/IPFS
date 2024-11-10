import 'package:p2plib/p2plib.dart' as p2p;
import 'helpers.dart'; // Import for calculateDistance, getBucketIndex
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart'; // Import the main KademliaTree class
// lib/src/protocols/dht/kademlia_tree/remove_peer.dart


extension RemovePeer on KademliaTree {
  /// Removes a peer from the Kademlia tree.
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
        this.mergeBuckets(bucketIndex, bucketIndex - 1); // Use through KademliaTree instance
        this.mergeBuckets(bucketIndex, bucketIndex + 1); // Use through KademliaTree instance
      }
    }
  }
}
