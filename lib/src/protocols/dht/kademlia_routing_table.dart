import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/connection_statistics.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

import 'dht_client.dart';
import 'kademlia_tree.dart';
import 'kademlia_tree/kademlia_tree_node.dart';
import 'red_black_tree.dart';

/// Kademlia DHT routing table implementation using k-buckets.
///
/// Organizes peers by their XOR distance from the local node. Each bucket
/// maintains a fixed capacity and handles splitting as the network grows.
///
/// **Security features:**
/// - IP diversity: Limits peers per IP address to prevent Sybil/Eclipse attacks.
/// - Stale eviction: Periodically prunes unresponsive nodes.
class KademliaRoutingTable {
  /// Creates a [KademliaRoutingTable] instance.
  ///
  /// The table must be initialized via [initialize] before performing operations.
  KademliaRoutingTable() : _logger = Logger('KademliaRoutingTable');

  /// The underlying DHT client.
  late final DHTClient dhtClient;
  late final KademliaTree _tree;
  final Logger _logger;

  /// Maximum number of peers per k-bucket.
  static const int kBucketSize = 20;

  /// Maximum allowed peers from a single IP address (Security: Sybil protection).
  static const int maxPeersPerIp = 2;

  final Map<PeerId, ConnectionStatistics> _connectionStats = {};
  final Map<String, int> _ipCounts = {};
  final Map<PeerId, String> _peerIps = {};

  /// Initializes the routing table with the provided [client].
  ///
  /// Parameters:
  /// - [client]: The [DHTClient] that owns this routing table.
  void initialize(DHTClient client) {
    dhtClient = client;
    _tree = KademliaTree(
      client,
      root: KademliaTreeNode(
        client.peerId,
        0,
        client.associatedPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _logger.debug('KademliaRoutingTable initialized for peer ${client.peerId}');
  }

  /// Adds a peer to the routing table, enforcing security and bucket constraints.
  ///
  /// Parameters:
  /// - [peerId]: The [PeerId] of the peer to add.
  /// - [associatedPeerId]: The associated PeerID (often same as peerId).
  /// - [address]: Optional IP address for diversity checks.
  Future<void> addPeer(
    PeerId peerId,
    PeerId associatedPeerId, {
    String? address,
  }) async {
    // SEC: IP Diversity Check
    if (address != null) {
      final String ip = address;
      final int currentCount = _ipCounts[ip] ?? 0;

      if (!_peerIps.containsKey(peerId) && currentCount >= maxPeersPerIp) {
        _logger.warning(
          'Security: Rejected peer $peerId from $ip (IP diversity limit reached)',
        );
        return;
      }

      if (!_peerIps.containsKey(peerId)) {
        _ipCounts[ip] = currentCount + 1;
        _peerIps[peerId] = ip;
      }
    }

    final int dist = _calculateXorDistance(peerId, _tree.root!.peerId);
    final int bucketIndex = _getBucketIndex(dist);
    final RedBlackTree<PeerId, KademliaTreeNode> bucket = _getOrCreateBucket(
      bucketIndex,
    );

    final KademliaTreeNode? existingNode = _findNodeInBucket(bucket, peerId);
    if (existingNode != null) {
      existingNode.lastSeen = DateTime.now().millisecondsSinceEpoch;
      _logger.verbose('Updated last seen for peer $peerId');
      return;
    }

    if (bucket.size >= kBucketSize) {
      if (!_removeStaleNode(bucket)) {
        _logger.debug(
          'Bucket $bucketIndex full and no stale nodes found; dropping peer $peerId',
        );
        return;
      }
    }

    bucket[peerId] = KademliaTreeNode(
      peerId,
      dist,
      associatedPeerId,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    _connectionStats.putIfAbsent(peerId, () => ConnectionStatistics());
    _logger.debug('Added peer $peerId to routing table');
  }

  /// Determines if a node is considered stale based on network activity.
  bool _isStaleNode(KademliaTreeNode node) {
    final NodeStats stats = _getNodeStats();
    final Duration threshold = _calculateStaleThreshold(stats);

    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(node.lastSeen),
        ) >
        threshold;
  }

  /// Calculates the timeout duration for stale nodes.
  Duration _calculateStaleThreshold(NodeStats stats) {
    if (stats.numConnectedPeers > 100) {
      return const Duration(hours: 2);
    }
    return const Duration(hours: 1);
  }

  /// Internal placeholder for fetching node statistics.
  NodeStats _getNodeStats() {
    return NodeStats(
      numBlocks: 0,
      datastoreSize: 0,
      numConnectedPeers: 50,
      bandwidthSent: 0,
      bandwidthReceived: 0,
    );
  }

  /// Removes a peer from the routing table.
  void removePeer(PeerId peerId) {
    _logger.debug('Removing peer $peerId from routing table');
    final int dist = _calculateXorDistance(peerId, _tree.root!.peerId);
    final int bucketIndex = _getBucketIndex(dist);

    if (bucketIndex >= _tree.buckets.length) return;
    final RedBlackTree<PeerId, KademliaTreeNode> bucket =
        _tree.buckets[bucketIndex];

    final KademliaTreeNode? node = _findNode(peerId);
    if (node != null) {
      bucket.remove(peerId);
      bucket.entries.removeWhere(
        (MapEntry<PeerId, KademliaTreeNode> e) => _peersEqual(e.key, peerId),
      );
      bucket.size = bucket.entries.length;

      final String? ip = _peerIps.remove(peerId);
      if (ip != null) {
        final int count = _ipCounts[ip] ?? 0;
        if (count > 1) {
          _ipCounts[ip] = count - 1;
        } else {
          _ipCounts.remove(ip);
        }
      }
      _logger.info('Removed peer $peerId from routing table');
    }
  }

  /// Returns the associated PeerID for a given [peerId].
  PeerId? getAssociatedPeer(PeerId peerId) => _tree.getAssociatedPeer(peerId);

  /// Checks if the routing table contains the specified [peerId].
  bool containsPeer(PeerId peerId) {
    for (final bucket in _tree.buckets) {
      for (final entry in bucket.entries) {
        if (_peersEqual(entry.key, peerId)) return true;
      }
    }
    return false;
  }

  /// Total number of peers currently in the routing table.
  int get peerCount =>
      _tree.buckets.fold(0, (sum, bucket) => sum + bucket.entries.length);

  /// Clears all entries from the routing table.
  void clear() {
    _logger.info('Clearing routing table');
    for (final bucket in _tree.buckets) {
      bucket.clear();
    }
    _peerIps.clear();
    _ipCounts.clear();
    _connectionStats.clear();
  }

  /// Calculates the XOR distance between two peers.
  int calculateDistance(PeerId a, PeerId b) => _calculateXorDistance(a, b);

  /// Provides access to the underlying buckets.
  List<RedBlackTree<PeerId, KademliaTreeNode>> get buckets => _tree.buckets;

  /// Finds the K closest peers to the given [target].
  List<PeerId> findClosestPeers(PeerId target, int k) =>
      _tree.findClosestPeers(target, k);

  /// Performs an iterative node lookup for [target] across the network.
  Future<List<PeerId>> nodeLookup(PeerId target) async =>
      _tree.nodeLookup(target);

  /// Refreshes the routing table by refreshing stale buckets.
  void refresh() {
    _logger.debug('Refreshing routing table buckets');
    final List<int> bucketsNeedingRefresh = [];
    for (int i = 0; i < buckets.length; i++) {
      if (_removeStaleNodesInBucket(i) < kBucketSize / 2) {
        bucketsNeedingRefresh.add(i);
      }
    }

    for (final int bucketIndex in bucketsNeedingRefresh) {
      _refreshBucket(bucketIndex, _tree.root!.peerId);
    }
  }

  /// Refreshes a specific bucket by performing a lookup for a random key in that bucket's range.
  ///
  /// This helps keep the routing table fresh and prevents buckets from becoming stale.
  void _refreshBucket(int bucketIndex, PeerId associatedPeerId) {
    try {
      final PeerId randomKey = _generateRandomKeyInBucket(bucketIndex);
      for (final PeerId peer in findClosestPeers(randomKey, kBucketSize)) {
        if (!containsPeer(peer)) {
          addPeerToBucket(peer, associatedPeerId);
        }
      }
    } catch (e) {
      _logger.debug('Error refreshing bucket $bucketIndex: $e');
    }
  }

  /// Gets an existing bucket or creates new ones up to [bucketIndex].
  RedBlackTree<PeerId, KademliaTreeNode> _getOrCreateBucket(int bucketIndex) {
    while (_tree.buckets.length <= bucketIndex) {
      _tree.buckets.add(
        RedBlackTree<PeerId, KademliaTreeNode>(compare: _xorDistanceComparator),
      );
    }
    return _tree.buckets[bucketIndex];
  }

  /// Evicts stale nodes from a specific bucket.
  ///
  /// Returns the number of nodes removed.
  int _removeStaleNodesInBucket(int index) {
    final bucket = _tree.buckets[index];
    int removedCount = 0;
    for (final entry in bucket.entries.toList()) {
      if (_isStaleNode(entry.value)) {
        removePeerFromBucket(entry.key);
        removedCount++;
      }
    }
    return removedCount;
  }

  /// Compares PeerIds for tree ordering based on XOR distance to local root.
  Comparator<PeerId> get _xorDistanceComparator => (PeerId a, PeerId b) {
    if (_peersEqual(a, b)) return 0;

    final int distA = _calculateXorDistance(a, _tree.root!.peerId);
    final int distB = _calculateXorDistance(b, _tree.root!.peerId);

    if (distA != distB) {
      return distA.compareTo(distB);
    }

    final int length = min(a.value.length, b.value.length);
    for (int i = 0; i < length; i++) {
      if (a.value[i] != b.value[i]) {
        return a.value[i].compareTo(b.value[i]);
      }
    }
    return a.value.length.compareTo(b.value.length);
  };

  /// Byte-level equality check for [PeerId].
  bool _peersEqual(PeerId a, PeerId b) {
    if (a.value.length != b.value.length) return false;
    for (int i = 0; i < a.value.length; i++) {
      if (a.value[i] != b.value[i]) return false;
    }
    return true;
  }

  /// Generates a random [PeerId] for bucket probing.
  PeerId _generateRandomKeyInBucket(int bucketIndex) {
    final Random random = Random.secure();
    final Uint8List keyBytes = Uint8List.fromList(
      List<int>.generate(32, (i) => random.nextInt(256)),
    );
    return PeerId(value: keyBytes);
  }

  /// Calculates XOR distance as the first bit position that differs.
  int _calculateXorDistance(PeerId a, PeerId b) {
    final int length = min(a.value.length, b.value.length);

    for (int i = 0; i < length; i++) {
      final int xorByte = a.value[i] ^ b.value[i];
      if (xorByte != 0) {
        int leadingZeros = 0;
        int mask = 0x80;
        while ((xorByte & mask) == 0 && mask > 0) {
          leadingZeros++;
          mask >>= 1;
        }
        return (i * 8) + leadingZeros;
      }
    }
    return 0;
  }

  /// Maps a distance to a bucket index (0-255).
  int _getBucketIndex(int distance) {
    if (distance == 0) return 0;
    return distance.clamp(0, 255);
  }

  /// Attempts to remove a single stale node from a bucket to make space.
  bool _removeStaleNode(RedBlackTree<PeerId, KademliaTreeNode> bucket) {
    for (final entry in bucket.entries.toList()) {
      if (_isStaleNode(entry.value)) {
        bucket.remove(entry.key);
        _logger.debug('Evicted stale node ${entry.key} from bucket');
        return true;
      }
    }
    return false;
  }

  /// Locates a node in any bucket.
  KademliaTreeNode? _findNode(PeerId peerId) {
    for (final bucket in _tree.buckets) {
      final KademliaTreeNode? node = _findNodeInBucket(bucket, peerId);
      if (node != null) return node;
    }
    return null;
  }

  /// Locates a node within a specific bucket.
  KademliaTreeNode? _findNodeInBucket(
    RedBlackTree<PeerId, KademliaTreeNode> bucket,
    PeerId peerId,
  ) {
    for (final entry in bucket.entries) {
      if (_peersEqual(entry.key, peerId)) return entry.value;
    }
    return null;
  }

  /// Directly adds a peer to a bucket (internal use).
  void addPeerToBucket(PeerId peerId, PeerId associatedPeerId) {
    final int dist = _calculateXorDistance(peerId, _tree.root!.peerId);
    final int bucketIndex = _getBucketIndex(dist);
    final RedBlackTree<PeerId, KademliaTreeNode> bucket = _getOrCreateBucket(
      bucketIndex,
    );

    if (_findNodeInBucket(bucket, peerId) != null) return;

    if (bucket.size < kBucketSize) {
      bucket[peerId] = KademliaTreeNode(
        peerId,
        dist,
        associatedPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Removes a peer from whichever bucket contains it.
  void removePeerFromBucket(PeerId peerId) {
    for (final bucket in _tree.buckets) {
      if (_findNodeInBucket(bucket, peerId) != null) {
        bucket.remove(peerId);
        bucket.entries.removeWhere((e) => _peersEqual(e.key, peerId));
        bucket.size = bucket.entries.length;
        break;
      }
    }
  }

  /// Updates peer information and connection statistics.
  ///
  /// Throws an [Exception] if the peer is unreachable.
  Future<void> updatePeer(V_PeerInfo peer) async {
    final PeerId peerId = PeerId(value: Uint8List.fromList(peer.peerId));

    if (!await pingPeer(peerId)) {
      _logger.warning('Failed to update peer $peerId: Peer unreachable');
      throw Exception('Peer unreachable');
    }

    final KademliaTreeNode? node = _findNode(peerId);
    if (node != null) {
      node.lastSeen = DateTime.now().millisecondsSinceEpoch;
      _connectionStats[peerId]?.updateFromPeerInfo(peer);
      _logger.verbose('Updated metadata for peer $peerId');
    } else {
      await addPeer(peerId, peerId);
    }
  }

  /// Registers a provider for a specific DHT key.
  void addKeyProvider(PeerId key, PeerId provider, DateTime timestamp) {
    final int dist = _calculateXorDistance(key, _tree.root!.peerId);
    final int bucketIndex = _getBucketIndex(dist);
    final RedBlackTree<PeerId, KademliaTreeNode> bucket = _getOrCreateBucket(
      bucketIndex,
    );

    bucket[key] = KademliaTreeNode(
      key,
      dist,
      provider,
      lastSeen: timestamp.millisecondsSinceEpoch,
    );
    _connectionStats.putIfAbsent(provider, () => ConnectionStatistics());
  }

  /// Updates the last-seen timestamp for a key provider.
  void updateKeyProviderTimestamp(
    PeerId key,
    PeerId provider,
    DateTime timestamp,
  ) {
    final KademliaTreeNode? node = _findNode(key);
    if (node != null && node.associatedPeerId == provider) {
      node.lastSeen = timestamp.millisecondsSinceEpoch;
    }
  }

  /// Calculates the logarithmic XOR distance between two Peer IDs.
  int distance(PeerId a, PeerId b) => _calculateXorDistance(a, b);

  /// Pings a peer to verify its online status.
  ///
  /// Returns true if the peer responds to the ping.
  Future<bool> pingPeer(PeerId peerId) async {
    try {
      final kad.Message msg = kad.Message()
        ..type = kad.Message_MessageType.PING;

      final Uint8List? response = await dhtClient.networkHandler
          .sendRequest(
            peerId.toBase58(),
            DHTClient.protocolDht,
            msg.writeToBuffer(),
          )
          .timeout(const Duration(seconds: 10));

      if (response == null) return false;

      final kad.Message pingResponse = kad.Message.fromBuffer(response);
      return pingResponse.type == kad.Message_MessageType.PING;
    } catch (e) {
      _logger.debug('Ping failed for peer $peerId: $e');
      return false;
    }
  }
}
