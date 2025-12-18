import 'dart:math' as Math;

import 'package:p2plib/p2plib.dart' as p2p;

import '../kademlia_tree.dart';
import '../red_black_tree.dart';
import 'helpers.dart' as helpers;
import 'kademlia_tree_node.dart';
import 'lru_cache.dart';

/// Extension for managing k-bucket operations in a Kademlia tree.
///
/// Handles bucket splitting, merging, and peer replacement strategies.
extension BucketManagement on KademliaTree {
  /// Handler for full bucket situations.
  Future<void> Function(int, p2p.PeerId, p2p.PeerId) get handleBucketFullness =>
      _handleBucketFullness;

  bool Function(p2p.PeerId) get wasNodeContactInRecentLookup =>
      _wasNodeContactInRecentLookup;

  KademliaTreeNode? Function(int) get findLeastRecentlySeenNode =>
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
      RedBlackTree<p2p.PeerId, KademliaTreeNode>(
        compare: (p2p.PeerId a, p2p.PeerId b) =>
            a.toString().compareTo(b.toString()),
      ),
    );

    // 2. Move peers
    var nodesToMove = buckets[bucketIndex].entries
        .map((entry) => entry.value)
        .toList();
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
    var nodesToMove = buckets[bucketIndex2].entries
        .map((entry) => entry.value)
        .toList();
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
    return recentContacts.contains(peerId);
  }

  KademliaTreeNode? _findLeastRecentlySeenNode(int bucketIndex) {
    if (buckets[bucketIndex].isEmpty) {
      return null;
    }

    KademliaTreeNode? leastRecentlySeenNode;
    DateTime? oldestLastSeenTime;

    for (var nodeEntry in buckets[bucketIndex].entries) {
      var node = nodeEntry.value;
      DateTime? lastSeenTime = lastSeen[node.peerId];

      if (lastSeenTime == null) {
        leastRecentlySeenNode = node;
        break;
      } else if (oldestLastSeenTime == null ||
          lastSeenTime.isBefore(oldestLastSeenTime)) {
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

  Future<bool> _pingNode(KademliaTreeNode node) async {
    try {
      final response = await sendPingRequest(node.peerId);
      return response != null;
    } catch (e) {
      // print('Ping failed for node ${node.peerId}: $e');
      return false;
    }
  }

  LRUCache _getOrCreateCache(int bucketIndex) {
    return bucketCaches.putIfAbsent(
      bucketIndex,
      () => LRUCache(KademliaTree.K * 2), // Cache size twice the k-bucket size
    );
  }

  Future<void> _handleBucketFullness(
    int bucketIndex,
    p2p.PeerId peerId,
    p2p.PeerId associatedPeerId,
  ) async {
    if (_canSplitBucket(bucketIndex)) {
      _splitBucket(bucketIndex);
      return;
    }

    final cache = _getOrCreateCache(bucketIndex);
    final leastRecentNode = _findLeastRecentlySeenNode(bucketIndex);

    if (leastRecentNode == null) return;

    // Try pinging the least recently seen node
    final isAlive = await _pingNode(leastRecentNode);

    if (!isAlive) {
      // If node is unresponsive, replace it
      buckets[bucketIndex].delete(leastRecentNode.peerId);
      final newNode = KademliaTreeNode(
        peerId,
        helpers.calculateDistance(peerId, root!.peerId),
        associatedPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      buckets[bucketIndex].insert(peerId, newNode);
      cache.put(peerId, newNode);
      return;
    }

    // Update LRU cache with the successful ping
    cache.put(leastRecentNode.peerId, leastRecentNode);

    // If the node is alive but we have a better candidate
    if (_shouldReplaceNode(leastRecentNode, peerId)) {
      buckets[bucketIndex].delete(leastRecentNode.peerId);
      final newNode = KademliaTreeNode(
        peerId,
        helpers.calculateDistance(peerId, root!.peerId),
        associatedPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      buckets[bucketIndex].insert(peerId, newNode);
      cache.put(peerId, newNode);
    }
  }

  bool _shouldReplaceNode(KademliaTreeNode existingNode, p2p.PeerId newPeerId) {
    // Check if the new peer was recently active in lookups
    if (_wasNodeContactInRecentLookup(newPeerId)) {
      return true;
    }

    // Check connection stability
    final existingStability = calculateConnectionStabilityScore(existingNode);
    final newStability = calculateConnectionStabilityScore(
      KademliaTreeNode(
        newPeerId,
        helpers.calculateDistance(newPeerId, root!.peerId),
        root!.peerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return newStability > existingStability;
  }

  double calculateConnectionStabilityScore(KademliaTreeNode node) {
    // Base score starts at 1.0
    double score = 1.0;

    // Factor 1: Connection state
    switch (node.state) {
      case KademliaNodeState.active:
        score *= 1.0;
        break;
      case KademliaNodeState.stale:
        score *= 0.5;
        break;
      case KademliaNodeState.failed:
        score *= 0.1;
        break;
    }

    // Factor 2: Failed requests penalty
    score *= Math.pow(0.9, node.failedRequests);

    // Factor 3: Recent activity bonus
    final lastSeenDuration = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(node.lastSeen),
    );
    if (lastSeenDuration < const Duration(minutes: 30)) {
      score *= 1.2; // 20% bonus for recent activity
    }

    // Factor 4: RTT (Round Trip Time) consideration
    if (node.lastRtt > 0) {
      // Normalize RTT between 0 and 1, assuming 1000ms as high latency
      final rttScore = 1.0 - (node.lastRtt / 1000.0).clamp(0.0, 1.0);
      score *= (0.5 + (0.5 * rttScore)); // RTT affects up to 50% of score
    }

    return score.clamp(0.0, 1.0); // Ensure final score is between 0 and 1
  }
}
