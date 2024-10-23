// lib/src/protocols/dht/kademlia_tree/bucket_management.dart

import 'package:p2plib/p2plib.dart' as p2p;
import '../red_black_tree.dart';
import 'helpers.dart' as helpers;
import '/../src/protocols/dht/kademlia_tree/kademlia_node.dart';
import '../kademlia_tree.dart';

extension BucketManagement on KademliaTree {
  // Getters for private methods
  Future<void> Function(int, p2p.PeerId, p2p.PeerId) get handleBucketFullness =>
      _handleBucketFullness;

  bool Function(p2p.PeerId) get wasNodeContactInRecentLookup =>
      _wasNodeContactInRecentLookup;

  KademliaNode? Function(int) get findLeastRecentlySeenNode =>
      _findLeastRecentlySeenNode;

  void Function(int) get splitBucket => _splitBucket;
  void Function(int, int) get mergeBuckets => _mergeBuckets;
  bool Function(int) get canSplitBucket => _canSplitBucket;
  bool Function(int, int) get canMergeBuckets => _canMergeBuckets;
  int Function(int) get getBucketIndex => _getBucketIndex;

  // Bucket splitting logic
  void _splitBucket(int bucketIndex) {
    // 1. Create a new bucket
    buckets.insert(
      bucketIndex + 1,
      RedBlackTree<p2p.PeerId, KademliaNode>(
        compare: (p2p.PeerId a, p2p.PeerId b) => a.toString().compareTo(b.toString()),
      ),
    );

    // 2. Move peers
    var nodesToMove = buckets[bucketIndex].entries.map((entry) => entry.value).toList();
    for (var node in nodesToMove) {
      if (_getBucketIndex(node.distance) == bucketIndex + 1) {
        buckets[bucketIndex].delete(node.peerId);
        buckets[bucketIndex + 1].insert(node.peerId, node);
        node.bucketIndex = bucketIndex + 1;
      }
    }

    // Handle edge cases
    if (buckets[bucketIndex].isEmpty) {
      buckets.removeAt(bucketIndex);
    }

    if (bucketIndex == 0) {
      // Handle root bucket edge case
    }

    if (bucketIndex == buckets.length - 1) {
      // Handle last bucket edge case
    }
  }

  // Bucket merging logic
  void _mergeBuckets(int bucketIndex1, int bucketIndex2) {
    // Ensure bucketIndex1 is smaller
    if (bucketIndex1 > bucketIndex2) {
      final temp = bucketIndex1;
      bucketIndex1 = bucketIndex2;
      bucketIndex2 = temp;
    }

    // Check for adjacency
    if (bucketIndex2 != bucketIndex1 + 1) {
      return;
    }

    // Move peers
    var nodesToMove = buckets[bucketIndex2].entries.map((entry) => entry.value).toList();
    for (var node in nodesToMove) {
      buckets[bucketIndex1].insert(node.peerId, node);
      node.bucketIndex = bucketIndex1;
    }

    // Remove the empty bucket
    buckets.removeAt(bucketIndex2);
  }

  bool _canSplitBucket(int bucketIndex) {
    if (bucketIndex == buckets.length - 1) {
      return false;
    }

    int minDistance = 1 << (255 - bucketIndex);
    int maxDistance = (1 << (256 - bucketIndex)) - 1;

    for (int distance = minDistance + 1; distance < maxDistance; distance++) {
      if (_getBucketIndex(distance) == bucketIndex + 1) {
        return true;
      }
    }

    return false;
  }

  bool _canMergeBuckets(int bucketIndex1, int bucketIndex2) {
    // Implement your logic here
    return true; // Placeholder
  }

  bool _wasNodeContactInRecentLookup(p2p.PeerId peerId) {
    return this.recentContacts.contains(peerId);
  }

  KademliaNode? _findLeastRecentlySeenNode(int bucketIndex) {
    if (buckets[bucketIndex].isEmpty) {
      return null;
    }

    KademliaNode? leastRecentlySeenNode;
    DateTime? oldestLastSeenTime;

    for (var nodeEntry in buckets[bucketIndex].entries) {
      var node = nodeEntry.value;
      DateTime? lastSeenTime = this.lastSeen[node.peerId];

      if (lastSeenTime == null) {
        leastRecentlySeenNode = node;
        break;
      } else if (oldestLastSeenTime == null || lastSeenTime.isBefore(oldestLastSeenTime)) {
        oldestLastSeenTime = lastSeenTime;
        leastRecentlySeenNode = node;
      }
    }

    return leastRecentlySeenNode;
  }

  int _getBucketIndex(int distance) {
    // Implement your bucket index calculation logic here
    return (255 - (distance.bitLength - 1)).toInt();
  }

  Future<void> _handleBucketFullness(
    int bucketIndex,
    p2p.PeerId peerId,
    p2p.PeerId associatedPeerId,
  ) async {
    final now = DateTime.now();

    if (_canSplitBucket(bucketIndex)) {
      _splitBucket(bucketIndex);
    } else {
      KademliaNode? leastRecentlySeenNode = _findLeastRecentlySeenNode(bucketIndex);
      bool newNodeWasContact = _wasNodeContactInRecentLookup(peerId);
      final nodeActivityThreshold = Duration(minutes: 10);

      if (newNodeWasContact) {
        if (leastRecentlySeenNode != null) {
          //Calculate stability score for the candidate node
          double candidateNodeStability = calculateConnectionStabilityScore(leastRecentlySeenNode);

          //Compare stability scores.  If the new node is more stable, replace.
          if (candidateNodeStability < calculateConnectionStabilityScore(KademliaNode(peerId, helpers.calculateDistance(peerId, root!.peerId), associatedPeerId))) {
            buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
            KademliaNode newNode = KademliaNode(
              peerId,
              helpers.calculateDistance(peerId, root!.peerId),
              associatedPeerId,
            );
            newNode.bucketIndex = bucketIndex;
            buckets[bucketIndex].insert(peerId, newNode);
          }
        }
      } else {
        if (leastRecentlySeenNode != null) {
          final lastSeenTime = this.lastSeen[leastRecentlySeenNode.peerId];

          if (lastSeenTime == null || now.difference(lastSeenTime) > nodeActivityThreshold) {
              //Calculate stability score for the candidate node
            double candidateNodeStability = calculateConnectionStabilityScore(leastRecentlySeenNode);

            //Compare stability scores.  If the new node is more stable, replace.
            if (candidateNodeStability < calculateConnectionStabilityScore(KademliaNode(peerId, helpers.calculateDistance(peerId, root!.peerId), associatedPeerId))) {
              buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
              KademliaNode newNode = KademliaNode(
                peerId,
                helpers.calculateDistance(peerId, root!.peerId),
                associatedPeerId,
              );
              newNode.bucketIndex = bucketIndex;
              buckets[bucketIndex].insert(peerId, newNode);
            }
          } else if (!await isNodeActive(leastRecentlySeenNode)) {
              //Calculate stability score for the candidate node
            double candidateNodeStability = calculateConnectionStabilityScore(leastRecentlySeenNode);

            //Compare stability scores.  If the new node is more stable, replace.
            if (candidateNodeStability < calculateConnectionStabilityScore(KademliaNode(peerId, helpers.calculateDistance(peerId, root!.peerId), associatedPeerId))) {
              buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
              KademliaNode newNode = KademliaNode(
                peerId,
                helpers.calculateDistance(peerId, root!.peerId),
                associatedPeerId,
              );
              newNode.bucketIndex = bucketIndex;
              buckets[bucketIndex].insert(peerId, newNode);
            }
          }
        }
      }
    }
  }
}


