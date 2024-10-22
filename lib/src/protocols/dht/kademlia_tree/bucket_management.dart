// lib/src/protocols/dht/kademlia_tree/bucket_management.dart
import 'package:p2plib/p2plib.dart' as p2p;
import '../red_black_tree.dart';
import 'helpers.dart';
import 'kademlia_node.dart';
import '../kademlia_tree.dart';
import '/../src/proto/dht/bucket_management.pb.dart' as bucket_management_pb;

extension BucketManagement on KademliaTree {
  // Bucket splitting logic
  void splitBucket(int bucketIndex) {
    // 1. Create a new bucket (a new Red-Black Tree)
    _buckets.insert(bucketIndex + 1, RedBlackTree<p2p.PeerId, _KademliaNode>(
        compare: (p2p.PeerId a, p2p.PeerId b) =>
            a.toString().compareTo(b.toString())));

    // 2. Move peers from the original bucket to the new bucket based on their distances
    // Get all nodes from the original bucket
    // (Assuming your RedBlackTree has a way to get all entries or values)
    var nodesToMove = _buckets[bucketIndex].entries.map((entry) => entry.value).toList(); 

    // Iterate and move nodes to the new bucket if they belong there
    for (var node in nodesToMove) {
      if (_getBucketIndex(node.distance) == bucketIndex + 1) {
        _buckets[bucketIndex].delete(node.peerId); // Remove from original bucket
        _buckets[bucketIndex + 1].insert(node.peerId, node); // Insert into new bucket
        node.bucketIndex = bucketIndex + 1; // Update bucket index
      }
    }

    // ... (Handle edge cases: empty bucket, root bucket, last bucket) ...
  }

  // Bucket merging logic
  void mergeBuckets(int bucketIndex1, int bucketIndex2) {
    // 1. Ensure bucketIndex1 is the smaller index (for consistency)
    // ... (Implementation for ensuring bucketIndex1 < bucketIndex2) ...

    // 2. Check if the buckets are adjacent and can be merged
    // ... (Implementation for checking adjacency and merge conditions) ...

    // 3. Move peers from bucketIndex2 to bucketIndex1
    // (Assuming your RedBlackTree has a way to get all entries or values)
    var nodesToMove = _buckets[bucketIndex2].entries.map((entry) => entry.value).toList();

    for (var node in nodesToMove) {
      _buckets[bucketIndex1].insert(node.peerId, node); // Assuming you're using RedBlackTree
      node.bucketIndex = bucketIndex1; // Update bucket index
    }

    // 4. Remove the empty bucketIndex2
    _buckets.removeAt(bucketIndex2);
  }
}
