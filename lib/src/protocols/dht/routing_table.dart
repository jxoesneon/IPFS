import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dht_client.dart';
import 'kademlia_tree.dart';
import 'red_black_tree.dart';
import '../../utils/Base58.dart';
import 'package:fixnum/fixnum.dart';
import 'package:convert/convert.dart';
import 'kademlia_tree/kademlia_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../../core/data_structures/node_stats.dart';
import '../../proto/generated/dht/store_provider.pb.dart';
import '../../proto/generated/dht/routing_table.pb.dart' as routing_table_pb;
import '../../proto/generated/dht/kademlia_node.pb.dart' as kademlia_node_pb;
import '../../proto/generated/dht/common_red_black_tree.pb.dart' as common_tree;

// Represents the routing table for the DHT client.
class RoutingTable {
  final DHTClient dhtClient;
  final KademliaTree _tree;
  static const int K_BUCKET_SIZE = 20;

  RoutingTable(this.dhtClient) : _tree = KademliaTree(dhtClient.peerId);

  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _getOrCreateBucket(bucketIndex);

    if (bucket.containsKey(peerId)) {
      final existingNode = bucket[peerId]!;
      bucket[peerId] = existingNode; // Update last seen by re-inserting.
      return;
    }

    if (bucket.size >= K_BUCKET_SIZE) {
      if (!_removeStaleNode(bucket)) {
        if (_isOurBucket(bucketIndex)) {
          splitBucket(bucketIndex);
          addPeer(peerId, associatedPeerId);
        }
        return;
      }
    }

    bucket[peerId] = KademliaNode(
      peerId,
      distance,
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isOurBucket(int bucketIndex) =>
      _getBucketIndex(
          _calculateXorDistance(_tree.root!.peerId, _tree.root!.peerId)) ==
      bucketIndex;

  bool _isStaleNode(p2p.PeerId peerId) {
    final nodeStats = _getNodeStats(); // Fetch current network statistics
    final staleThreshold = _calculateStaleThreshold(
        nodeStats); // Calculate threshold based on stats
    final node = _findNode(peerId);
    if (node == null) return true;
    return DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(node.lastSeen ?? 0)) >
        staleThreshold;
  }

  Duration _calculateStaleThreshold(NodeStats nodeStats) {
    // Example logic: Increase threshold if many peers are connected
    if (nodeStats.numConnectedPeers > 100) {
      return Duration(hours: 2); // More lenient threshold
    }
    return Duration(hours: 1); // Default threshold
  }

  NodeStats _getNodeStats() {
    // Implement logic to fetch current NodeStats
    // This could be a call to a service or a direct access to a NodeStats instance
    return NodeStats(
      numBlocks: 0, // Example values
      datastoreSize: 0,
      numConnectedPeers: 50,
      bandwidthSent: 0,
      bandwidthReceived: 0,
    );
  }

  void removePeer(p2p.PeerId peerId) => _tree.removePeer(peerId);

  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) =>
      _tree.getAssociatedPeer(peerId);

  bool containsPeer(p2p.PeerId peerId) =>
      _tree.buckets.any((bucket) => bucket.containsKey(peerId));

  int get peerCount => _tree.buckets
      .fold(0, (sum, bucket) => (sum + bucket.entries.length).toInt());

  void clear() => _tree.buckets.forEach((bucket) => bucket.clear());

  int distance(p2p.PeerId a, p2p.PeerId b) => List<int>.generate(
          min(a.value.length, b.value.length), (i) => a.value[i] ^ b.value[i])
      .reduce((acc, val) => (acc << 8) | val);

  List<RedBlackTree<p2p.PeerId, KademliaNode>> get buckets => _tree.buckets;

  void splitBucket(int bucketIndex) {
    if (bucketIndex >= buckets.length ||
        buckets[bucketIndex].size <= K_BUCKET_SIZE) return;

    final bucket = buckets[bucketIndex];
    final lowerBucket =
        RedBlackTree<p2p.PeerId, KademliaNode>(compare: _xorDistanceComparator);
    final upperBucket =
        RedBlackTree<p2p.PeerId, KademliaNode>(compare: _xorDistanceComparator);

    for (var entry in bucket.entries) {
      final node = entry.value;
      if (_calculateXorDistance(node.peerId, _tree.root!.peerId) <
          (1 << bucketIndex)) {
        lowerBucket[node.peerId] = node;
      } else {
        upperBucket[node.peerId] = node;
      }
    }

    buckets[bucketIndex] = lowerBucket;
    buckets.insert(bucketIndex + 1, upperBucket);
  }

  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) =>
      _tree.findClosestPeers(target, k);

  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async =>
      _tree.nodeLookup(target);

  void refresh() {
    final bucketsNeedingRefresh = <int>[];
    for (var i = 0; i < buckets.length; i++) {
      if (_removeStaleNodesInBucket(i) < K_BUCKET_SIZE / 2) {
        bucketsNeedingRefresh.add(i);
      }
    }

    for (var bucketIndex in bucketsNeedingRefresh) {
      _refreshBucket(bucketIndex, _tree.root!.peerId);
    }
  }

  void _refreshBucket(int bucketIndex, p2p.PeerId associatedPeerId) {
    final randomKey = _generateRandomKeyInBucket(bucketIndex);
    for (var peer in findClosestPeers(randomKey, K_BUCKET_SIZE)) {
      if (!containsPeer(peer)) addPeerToBucket(peer, associatedPeerId);
    }
  }

  RedBlackTree<p2p.PeerId, KademliaNode> _getOrCreateBucket(int bucketIndex) {
    while (_tree.buckets.length <= bucketIndex) {
      _tree.buckets.add(RedBlackTree<p2p.PeerId, KademliaNode>(
          compare: _xorDistanceComparator));
    }
    return _tree.buckets[bucketIndex];
  }

  int _removeStaleNodesInBucket(int index) {
    final bucket = _tree.buckets[index];
    var removedCount = 0;
    for (var entry in bucket.entries.toList()) {
      if (_isStaleNode(entry.key)) {
        removePeerFromBucket(entry.key);
        removedCount++;
      }
    }
    return removedCount;
  }

  Comparator<p2p.PeerId> get _xorDistanceComparator =>
      (a, b) => _calculateXorDistance(a, b).compareTo(0);

  p2p.PeerId _generateRandomKeyInBucket(int bucketIndex) {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return p2p.PeerId(value: Uint8List.fromList(keyBytes));
  }

  int _calculateXorDistance(p2p.PeerId a, p2p.PeerId b) {
    final length = min(a.value.length, b.value.length);
    int distance = 0;
    for (int i = 0; i < length; i++) {
      distance = (distance << 8) | (a.value[i] ^ b.value[i]);
    }
    return distance;
  }

  int _getBucketIndex(int distance) {
    // Assuming the bucket index is determined by the number of leading zeros in the distance
    return distance.bitLength - 1;
  }

  bool _removeStaleNode(RedBlackTree<p2p.PeerId, KademliaNode> bucket) {
    for (var entry in bucket.entries.toList()) {
      if (_isStaleNode(entry.key)) {
        bucket.remove(entry.key);
        return true; // Return true if a stale node was removed
      }
    }
    return false; // Return false if no stale node was found
  }

  KademliaNode? _findNode(p2p.PeerId peerId) {
    for (var bucket in _tree.buckets) {
      if (bucket.containsKey(peerId)) {
        return bucket[peerId];
      }
    }
    return null;
  }

  void addPeerToBucket(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _getOrCreateBucket(bucketIndex);

    if (bucket.containsKey(peerId)) {
      final existingNode = bucket[peerId]!;
      bucket[peerId] = existingNode; // Update last seen by re-inserting.
      return;
    }

    if (bucket.size >= K_BUCKET_SIZE) {
      if (!_removeStaleNode(bucket) && _isOurBucket(bucketIndex)) {
        splitBucket(bucketIndex);
        addPeerToBucket(peerId, associatedPeerId);
      }
      return;
    }

    bucket[peerId] = KademliaNode(
      peerId,
      distance,
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void removePeerFromBucket(p2p.PeerId peerId) {
    for (var bucket in _tree.buckets) {
      if (bucket.containsKey(peerId)) {
        bucket.remove(peerId);
        break;
      }
    }
  }
}
