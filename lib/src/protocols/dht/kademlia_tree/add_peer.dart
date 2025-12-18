import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart'
    as helpers;
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// Extension for adding peers to a Kademlia tree.
extension AddPeer on KademliaTree {
  /// Adds [peerId] with [associatedPeerId] to the tree.
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    // Calculate the distance and bucket index
    int distance = helpers.calculateDistance(peerId, root!.peerId);
    int bucketIndex = helpers.getBucketIndex(distance);

    KademliaTreeNode newNode = KademliaTreeNode(
      peerId,
      distance,
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
    newNode.bucketIndex = bucketIndex;

    // Insert into the RedBlackTree
    buckets[bucketIndex].insert(peerId, newNode);

    // Handle bucket fullness - splitting or replacement
    if (buckets[bucketIndex].size > KademliaTree.K) {
      handleBucketFullness(bucketIndex, peerId, associatedPeerId);
    }
  }
}
