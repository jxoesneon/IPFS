import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/connection_statistics.dart';
import 'package:p2plib/p2plib.dart' as p2p;

import 'dht_client.dart';
import 'kademlia_tree.dart';
import 'kademlia_tree/kademlia_tree_node.dart';
import 'red_black_tree.dart';

/// Kademlia DHT routing table with k-buckets.
///
/// Organizes peers by XOR distance from the local node. Each bucket
/// holds up to [kBucketSize] peers. Supports bucket splitting,
/// stale node eviction, periodic refresh, and IP diversity checks.
class KademliaRoutingTable {
  /// Creates an uninitialized routing table.
  /// Call [initialize] before use.
  KademliaRoutingTable();

  /// The underlying DHT client for network operations.
  late final DHTClient dhtClient;
  late KademliaTree _tree;

  /// Maximum peers per bucket.
  static const int kBucketSize = 20;

  /// Maximum number of peers allowed from a single IP address.
  /// Prevents Sybil/Eclipse attacks where one attacker fills the table.
  static const int maxPeersPerIp = 2;

  final Map<p2p.PeerId, ConnectionStatistics> _connectionStats = {};

  /// Tracks number of peers per IP address.
  final Map<String, int> _ipCounts = {};

  /// Maps a PeerId to its IP address for quick lookup during removal.
  final Map<p2p.PeerId, String> _peerIps = {};

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

  /// Adds a peer to the routing table.
  ///
  /// Enforces IP diversity limits to prevent Sybil attacks.
  Future<void> addPeer(
    p2p.PeerId peerId,
    p2p.PeerId associatedPeerId, {
    p2p.FullAddress? address,
  }) async {
    // 1. IP Diversity Check
    if (address != null) {
      final ip = address.address.address;
      final currentCount = _ipCounts[ip] ?? 0;

      // If peer is not already in the table (check _peerIps map) but limit exceeded
      if (!_peerIps.containsKey(peerId) && currentCount >= maxPeersPerIp) {
        // print(
        //   '[Security] Rejected peer $peerId from $ip (Limit: $maxPeersPerIp)',
        // );
        return;
      }

      // Track IP
      if (!_peerIps.containsKey(peerId)) {
        _ipCounts[ip] = currentCount + 1;
        _peerIps[peerId] = ip;
      }
    }

    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _getOrCreateBucket(bucketIndex);

    if (bucket.containsKey(peerId)) {
      final existingNode = bucket[peerId]!;
      bucket[peerId] = existingNode; // Update last seen by re-inserting.
      return;
    }

    if (bucket.size >= kBucketSize) {
      if (!_removeStaleNode(bucket)) {
        if (_isOurBucket(bucketIndex)) {
          splitBucket(bucketIndex);
          await addPeer(peerId, associatedPeerId, address: address);
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
        _calculateXorDistance(_tree.root!.peerId, _tree.root!.peerId),
      ) ==
      bucketIndex;

  bool _isStaleNode(p2p.PeerId peerId) {
    final nodeStats = _getNodeStats(); // Fetch current network statistics
    final staleThreshold = _calculateStaleThreshold(nodeStats);
    final node = _findNode(peerId);
    if (node == null) return true;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(node.lastSeen),
        ) >
        staleThreshold;
  }

  Duration _calculateStaleThreshold(NodeStats nodeStats) {
    // Example logic: Increase threshold if many peers are connected
    if (nodeStats.numConnectedPeers > 100) {
      return const Duration(hours: 2); // More lenient threshold
    }
    return const Duration(hours: 1); // Default threshold
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

  /// Removes a peer from the routing table.
  void removePeer(p2p.PeerId peerId) {
    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _tree.buckets[bucketIndex];

    if (bucket.containsKey(peerId)) {
      bucket.remove(peerId);

      // Decrement IP count
      if (_peerIps.containsKey(peerId)) {
        final ip = _peerIps[peerId]!;
        final count = _ipCounts[ip] ?? 0;
        if (count > 0) {
          _ipCounts[ip] = count - 1;
          if (_ipCounts[ip] == 0) _ipCounts.remove(ip);
        }
        _peerIps.remove(peerId);
      }

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

  /// Gets the associated peer for a given peer ID.
  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) =>
      _tree.getAssociatedPeer(peerId);

  /// Returns true if the routing table contains the peer.
  bool containsPeer(p2p.PeerId peerId) =>
      _tree.buckets.any((bucket) => bucket.containsKey(peerId));

  /// Total number of peers in the routing table.
  int get peerCount => _tree.buckets.fold(
    0,
    (sum, bucket) => (sum + bucket.entries.length).toInt(),
  );

  /// Clears all peers from the routing table.
  void clear() {
    for (final bucket in _tree.buckets) {
      bucket.clear();
    }
  }

  /// Calculates XOR distance between two peer IDs.
  int distance(p2p.PeerId a, p2p.PeerId b) => _calculateXorDistance(a, b);

  /// Access to the underlying k-buckets.
  List<RedBlackTree<p2p.PeerId, KademliaTreeNode>> get buckets => _tree.buckets;

  /// Splits a bucket when it becomes full.
  void splitBucket(int bucketIndex) {
    if (bucketIndex >= buckets.length ||
        buckets[bucketIndex].size <= kBucketSize) {
      return;
    }

    final bucket = buckets[bucketIndex];
    final lowerBucket = RedBlackTree<p2p.PeerId, KademliaTreeNode>(
      compare: _xorDistanceComparator,
    );
    final upperBucket = RedBlackTree<p2p.PeerId, KademliaTreeNode>(
      compare: _xorDistanceComparator,
    );

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

  /// Finds the k closest peers to target.
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) =>
      _tree.findClosestPeers(target, k);

  /// Performs a node lookup for target.
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async =>
      _tree.nodeLookup(target);

  /// Refreshes stale buckets by querying for random keys.
  void refresh() {
    final bucketsNeedingRefresh = <int>[];
    for (var i = 0; i < buckets.length; i++) {
      if (_removeStaleNodesInBucket(i) < kBucketSize / 2) {
        bucketsNeedingRefresh.add(i);
      }
    }

    for (var bucketIndex in bucketsNeedingRefresh) {
      _refreshBucket(bucketIndex, _tree.root!.peerId);
    }
  }

  void _refreshBucket(int bucketIndex, p2p.PeerId associatedPeerId) {
    final randomKey = _generateRandomKeyInBucket(bucketIndex);
    for (var peer in findClosestPeers(randomKey, kBucketSize)) {
      if (!containsPeer(peer)) addPeerToBucket(peer, associatedPeerId);
    }
  }

  RedBlackTree<p2p.PeerId, KademliaTreeNode> _getOrCreateBucket(
    int bucketIndex,
  ) {
    while (_tree.buckets.length <= bucketIndex) {
      _tree.buckets.add(
        RedBlackTree<p2p.PeerId, KademliaTreeNode>(
          compare: _xorDistanceComparator,
        ),
      );
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

  /// Compares two PeerIds for RedBlack Tree ordering.
  ///
  /// Primary comparison: XOR distance to root node (ascending order).
  /// Secondary comparison: byte-by-byte comparison when distances are equal.
  /// Returns 0 only when both PeerIds are identical (for duplicate detection).
  Comparator<p2p.PeerId> get _xorDistanceComparator => (a, b) {
    // First, check if they're the exact same peer
    if (_peersEqual(a, b)) return 0;

    // Compare distances to root node
    final distA = _calculateXorDistance(a, _tree.root!.peerId);
    final distB = _calculateXorDistance(b, _tree.root!.peerId);

    if (distA != distB) {
      return distA.compareTo(distB);
    }

    // Same distance - use byte comparison as tiebreaker
    final length = min(a.value.length, b.value.length);
    for (int i = 0; i < length; i++) {
      if (a.value[i] != b.value[i]) {
        return a.value[i].compareTo(b.value[i]);
      }
    }
    // If all compared bytes are equal, shorter one comes first
    return a.value.length.compareTo(b.value.length);
  };

  /// Checks if two PeerIds are identical (same bytes).
  bool _peersEqual(p2p.PeerId a, p2p.PeerId b) {
    if (a.value.length != b.value.length) return false;
    for (int i = 0; i < a.value.length; i++) {
      if (a.value[i] != b.value[i]) return false;
    }
    return true;
  }

  p2p.PeerId _generateRandomKeyInBucket(int bucketIndex) {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return p2p.PeerId(value: Uint8List.fromList(keyBytes));
  }

  int _calculateXorDistance(p2p.PeerId a, p2p.PeerId b) {
    final length = min(a.value.length, b.value.length);

    // Find the first differing byte and calculate distance from there
    // This prevents integer overflow for large PeerIds
    for (int i = 0; i < length; i++) {
      int xorByte = a.value[i] ^ b.value[i];
      if (xorByte != 0) {
        // Convert position and XOR value to distance
        // Distance represents the bit position of the first difference
        int leadingZeros = 0;
        int mask = 0x80;
        while ((xorByte & mask) == 0 && mask > 0) {
          leadingZeros++;
          mask >>= 1;
        }
        return (i * 8) + leadingZeros;
      }
    }
    // If all bytes are the same, distance is 0 (same peer)
    return 0;
  }

  int _getBucketIndex(int distance) {
    // Distance 0 means same peer - use bucket 0
    // Otherwise distance represents the bit position, which is the bucket index
    if (distance == 0) return 0;
    return distance.clamp(0, 255); // Ensure we don't exceed bucket array bounds
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

  /// Adds a peer directly to a bucket (internal).
  void addPeerToBucket(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    final distance = _calculateXorDistance(peerId, _tree.root!.peerId);
    final bucketIndex = _getBucketIndex(distance);
    final bucket = _getOrCreateBucket(bucketIndex);

    if (bucket.containsKey(peerId)) {
      final existingNode = bucket[peerId]!;
      bucket[peerId] = existingNode; // Update last seen by re-inserting.
      return;
    }

    if (bucket.size >= kBucketSize) {
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

  /// Removes a peer from its bucket.
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
        if (bucket.size >= kBucketSize) {
          splitBucket(bucketIndex);
        }
      }
    } else {
      // Create an associated PeerId from the peer info
      final associatedPeerId = p2p.PeerId(
        value: Uint8List.fromList(peer.peerId),
      );
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
    p2p.PeerId key,
    p2p.PeerId provider,
    DateTime timestamp,
  ) {
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
        DHTClient.protocolDht,
        msg.writeToBuffer(),
      );

      // Parse response
      final pingResponse = kad.Message.fromBuffer(response);
      return pingResponse.type == kad.Message_MessageType.PING;
    } catch (e) {
      // print('Error pinging peer ${peerId.toString()}: $e');
      return false;
    }
  }
}
