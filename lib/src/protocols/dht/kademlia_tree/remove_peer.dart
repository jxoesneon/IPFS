// lib/src/protocols/dht/kademlia_tree/remove_peer.dart
import 'package:p2plib/p2plib.dart' as p2p;
import 'bucket_management.dart'; // Import for mergeBuckets
import 'helpers.dart'; // Import for _calculateDistance, _getBucketIndex
import '../kademlia_tree.dart'; // Import the main KademliaTree class


extension RemovePeer on KademliaTree {
  /// Removes a peer from the Kademlia tree.
  void removePeer(p2p.PeerId peerId) {
    int distance = _calculateDistance(peerId, _root!.peerId);
    int bucketIndex = _getBucketIndex(distance);

    // Remove from the RedBlackTree
    _buckets[bucketIndex].delete(peerId);

    // Handle bucket emptiness - merging with other buckets
    if (_buckets[bucketIndex].isEmpty) {
      // Check if the bucket can be merged with an adjacent bucket
      if (bucketIndex > 0 && bucketIndex < _buckets.length - 1) {
        // Try merging with the previous or next bucket
        mergeBuckets(bucketIndex, bucketIndex - 1); // Try merging with previous
        mergeBuckets(bucketIndex, bucketIndex + 1); // Try merging with next
      }
    }
  }
}
