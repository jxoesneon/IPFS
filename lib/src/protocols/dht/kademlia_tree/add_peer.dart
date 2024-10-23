// lib/src/protocols/dht/kademlia_tree/add_peer.dart
import 'package:p2plib/p2plib.dart' as p2p;
import 'helpers.dart' as helpers;
import 'kademlia_node.dart';
import '../kademlia_tree.dart';
import 'bucket_management.dart';

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
    if (this.buckets[bucketIndex].size > KademliaTree.kBucketSize) {
      handleBucketFullness(bucketIndex, peerId, associatedPeerId); // Call the getter
    }
  }
}


