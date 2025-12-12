import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'; // V_PeerInfo
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;

import 'dht_client.dart';
import 'kademlia_tree.dart';
import 'red_black_tree.dart';
import 'kademlia_tree/kademlia_tree_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/protocols/dht/connection_statistics.dart';

// Represents the routing table for the DHT client.
class KademliaRoutingTable {
  late final DHTClient dhtClient;
  late KademliaTree _tree;
  static const int K_BUCKET_SIZE = 20;
  final Map<p2p.PeerId, ConnectionStatistics> _connectionStats = {};

  KademliaRoutingTable() {
    // Don't initialize _tree in the initializer list
    // It will be properly initialized in the initialize() method
  }

  /// Initializes the routing table with a reference to the DHT client
  void initialize(DHTClient client) {
    dhtClient = client;
    _tree = KademliaTree(
      client,
      root: KademliaTreeNode(
        client.peerId,
        0, // Distance to self is 0
        client.associatedPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) async {
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
          await addPeer(peerId, associatedPeerId);
        }
        return;
      }
    }

    bucket[peerId] = KademliaTreeNode(
      peerId,
      distance,
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    // Initialize connection statistics for new peer
    if (!_connectionStats.containsKey(peerId)) {
      _connectionStats[peerId] = ConnectionStatistics();
    }
  }

  bool _isOurBucket(int bucketIndex) =>
      _getBucketIndex(
          _calculateXorDistance(_tree.root!.peerId, _tree.root!.peerId)) ==
      bucketIndex;

  bool _isStaleNode(p2p.PeerId peerId) {
    final nodeStats = _getNodeStats(); // Fetch current network statistics
    final staleThreshold = _calculateStaleThreshold(nodeStats);
    final node = _findNode(peerId);
    if (node == null) return true;
    return DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(node.lastSeen)) >
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

  void removePeer(p2p.PeerId peerId) {
    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _tree.buckets[bucketIndex];

    if (bucket.containsKey(peerId)) {
      bucket.remove(peerId);

      // Check if bucket needs to be merged after removal
      if (bucket.isEmpty && bucketIndex > 0) {
        _mergeBuckets(bucketIndex);
      }
    }
  }

  void _mergeBuckets(int bucketIndex) {
    if (bucketIndex > 0 && _tree.buckets[bucketIndex].isEmpty) {
      final previousBucket = _tree.buckets[bucketIndex - 1];
      final currentBucket = _tree.buckets[bucketIndex];

      // Move all nodes from current bucket to previous bucket
      for (var entry in currentBucket.entries) {
        previousBucket[entry.key] = entry.value;
      }

      // Remove the empty bucket
      _tree.buckets.removeAt(bucketIndex);
    }
  }

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

  List<RedBlackTree<p2p.PeerId, KademliaTreeNode>> get buckets => _tree.buckets;

  void splitBucket(int bucketIndex) {
    if (bucketIndex >= buckets.length ||
        buckets[bucketIndex].size <= K_BUCKET_SIZE) return;

    final bucket = buckets[bucketIndex];
    final lowerBucket = RedBlackTree<p2p.PeerId, KademliaTreeNode>(
        compare: _xorDistanceComparator);
    final upperBucket = RedBlackTree<p2p.PeerId, KademliaTreeNode>(
        compare: _xorDistanceComparator);

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

  RedBlackTree<p2p.PeerId, KademliaTreeNode> _getOrCreateBucket(
      int bucketIndex) {
    while (_tree.buckets.length <= bucketIndex) {
      _tree.buckets.add(RedBlackTree<p2p.PeerId, KademliaTreeNode>(
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

  bool _removeStaleNode(RedBlackTree<p2p.PeerId, KademliaTreeNode> bucket) {
    for (var entry in bucket.entries.toList()) {
      if (_isStaleNode(entry.key)) {
        bucket.remove(entry.key);
        return true; // Return true if a stale node was removed
      }
    }
    return false; // Return false if no stale node was found
  }

  KademliaTreeNode? _findNode(p2p.PeerId peerId) {
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

    bucket[peerId] = KademliaTreeNode(
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

  /// Updates peer information in the routing table
  Future<void> updatePeer(V_PeerInfo peer) async {
    final peerId = p2p.PeerId(value: Uint8List.fromList(peer.peerId));

    // Verify peer is still alive with a ping
    if (!await pingPeer(peerId)) {
      throw Exception('Peer unreachable');
    }

    if (containsPeer(peerId)) {
      final node = _findNode(peerId);
      if (node != null) {
        node.lastSeen = DateTime.now().millisecondsSinceEpoch;

        // Update connection stats
        if (_connectionStats.containsKey(peerId)) {
          _connectionStats[peerId]!.updateFromPeerInfo(peer);
        }

        // Find the bucket containing this node and check if it needs splitting
        final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
        final bucketIndex = _getBucketIndex(distance);
        final bucket = _tree.buckets[bucketIndex];

        // Check if bucket needs splitting
        if (bucket.size >= K_BUCKET_SIZE) {
          splitBucket(bucketIndex);
        }
      }
    } else {
      // Create an associated PeerId from the peer info
      final associatedPeerId =
          p2p.PeerId(value: Uint8List.fromList(peer.peerId));
      await addPeer(peerId, associatedPeerId);
    }
  }

  /// Adds a key provider to the routing table
  void addKeyProvider(p2p.PeerId key, p2p.PeerId provider, DateTime timestamp) {
    // Calculate distance between key and our node
    final distance = _calculateXorDistance(key, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _getOrCreateBucket(bucketIndex);

    // Create or update the key node
    final keyNode = KademliaTreeNode(
      key,
      distance,
      provider,
      lastSeen: timestamp.millisecondsSinceEpoch,
    );

    bucket[key] = keyNode;

    // Initialize connection stats for provider if needed
    if (!_connectionStats.containsKey(provider)) {
      _connectionStats[provider] = ConnectionStatistics();
    }
  }

  /// Updates the timestamp for a key provider
  void updateKeyProviderTimestamp(
      p2p.PeerId key, p2p.PeerId provider, DateTime timestamp) {
    final node = _findNode(key);
    if (node != null && node.associatedPeerId == provider) {
      node.lastSeen = timestamp.millisecondsSinceEpoch;
    }
  }

  /// Pings a peer to check if it's still alive
  Future<bool> pingPeer(p2p.PeerId peerId) async {
    try {
      // Create ping request message
      final msg = kad.Message()..type = kad.Message_MessageType.PING;

      // Send request through DHT client's network handler
      final response = await dhtClient.networkHandler.sendRequest(
        peerId,
        DHTClient.PROTOCOL_DHT,
        msg.writeToBuffer(),
      );

      // Parse response
      final pingResponse = kad.Message.fromBuffer(response);
      return pingResponse.type == kad.Message_MessageType.PING;
    } catch (e) {
      print('Error pinging peer ${peerId.toString()}: $e');
      return false;
    }
  }
}
