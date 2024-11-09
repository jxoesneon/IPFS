import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_node.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart' as helpers;
// lib/src/protocols/dht/kademlia_tree/add_peer.dart

extension AddPeer on KademliaTree {
  // Add a peer to the Kademlia tree
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    // Calculate the distance and bucket index
    int distance = helpers.calculateDistance(peerId, this.root!.peerId);
    int bucketIndex = helpers.getBucketIndex(distance);

    KademliaNode newNode = KademliaNode(
      peerId, 
      distance, 
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
    newNode.bucketIndex = bucketIndex;

    // Insert into the RedBlackTree
    this.buckets[bucketIndex].insert(peerId, newNode);

    // Handle bucket fullness - splitting or replacement
    if (this.buckets[bucketIndex].size > KademliaTree.kBucketSize) {
      handleBucketFullness(bucketIndex, peerId, associatedPeerId);
    }
  }
}


