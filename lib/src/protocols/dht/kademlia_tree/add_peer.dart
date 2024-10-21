// lib/src/protocols/dht/kademlia_tree/add_peer.dart
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/proto/dht/common_tree.pb.dart' as common_tree; // Import Protobuf definitions
import '../red_black_tree.dart';
import 'helpers.dart' as helpers;
import 'helpers.dart';
import 'kademlia_node.dart';
import '../kademlia_tree.dart';
import 'bucket_management.dart'; // Import for bucket management functions

extension AddPeer on KademliaTree { 

  // Add a peer to the Kademlia tree
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    // Calculate the distance and bucket index
    int distance = helpers.calculateDistance(peerId, this.root!.peerId);
    int bucketIndex = helpers.getBucketIndex(distance);


    KademliaNode newNode = KademliaNode(peerId, distance, associatedPeerId);
    newNode.bucketIndex = bucketIndex;

    // Insert into the RedBlackTree
    this.buckets[bucketIndex].insert(peerId, newNode);

    // Handle bucket fullness - splitting or replacement
    if (this.buckets[bucketIndex].size > this.kBucketSize) {
      _handleBucketFullness(bucketIndex, peerId, associatedPeerId);
    }
  }


  bool canSplitBucket(int bucketIndex) {
    // 1. Check if it's the last bucket
    if (bucketIndex == buckets.length - 1) {
      return false; // Cannot split the last bucket
    }

    // 2. Check if the distance range can be further divided
    //    (Assuming getBucketIndex is implemented correctly in helpers.dart)
    //    We need to check if there's a possible distance that would fall into
    //    a new bucket if we were to split this one.

    // Get the minimum and maximum distances for the current bucket
    int minDistance = 1 << (255 - bucketIndex); // Assuming 256-bit Peer IDs
    int maxDistance = (1 << (256 - bucketIndex)) - 1;

    // Check if there's a distance between minDistance and maxDistance
    // that would fall into a new bucket (bucketIndex + 1)
    for (int distance = minDistance + 1; distance < maxDistance; distance++) {
      if (helpers.getBucketIndex(distance) == bucketIndex + 1) {
        return true; // Distance range can be divided, bucket can be split
      }
    }

    return false; // Distance range cannot be further divided
  }


  // Helper function to handle bucket fullness (splitting or replacement)
  void _handleBucketFullness(
      int bucketIndex, p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    if (canSplitBucket(bucketIndex)) {
      // ... (split bucket logic) ...
    } else {
      // Bucket cannot be split, apply replacement strategy

      // 1. Find the least recently seen node in the bucket
      KademliaNode? leastRecentlySeenNode =
          _findLeastRecentlySeenNode(bucketIndex);

      // 2. Check if the new node was the contact in a recent lookup
      bool newNodeWasContact =
          _wasNodeContactInRecentLookup(peerId); // You'll need to implement this

      if (newNodeWasContact) {
        // 3a. If new node was the contact, always replace the least recently seen
        if (leastRecentlySeenNode != null) {
          buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
          KademliaNode newNode = KademliaNode(peerId, helpers.calculateDistance(peerId, _root!.peerId), associatedPeerId);
          newNode.bucketIndex = bucketIndex;
          buckets[bucketIndex].insert(peerId, newNode);
        }
      } else {
        // 3b. If new node wasn't the contact, check node activity
        if (leastRecentlySeenNode != null &&
            _isNodeActive(leastRecentlySeenNode)) {
          // If the least recently seen node is active, drop the new node
          return;
        } else {
          // If the least recently seen node is inactive, replace it
          if (leastRecentlySeenNode != null) {
            buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
          }
          KademliaNode newNode = KademliaNode(peerId, calculateDistance(peerId, _root!.peerId), associatedPeerId);
          newNode.bucketIndex = bucketIndex;
          buckets[bucketIndex].insert(peerId, newNode);
        }
      }
    }
  }

  // Helper functions (you'll need to implement these)
  KademliaNode? _findLeastRecentlySeenNode(int bucketIndex) {
    // ... (implementation to find the node with the oldest last seen time) ...
  }

  bool _wasNodeContactInRecentLookup(p2p.PeerId peerId) {
    // ... (implementation to check if the node was a contact in a recent lookup) ...
  }

  bool _isNodeActive(KademliaNode node) {
    // ... (implementation to determine if the node is active) ...
  }
}


