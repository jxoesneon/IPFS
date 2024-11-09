import 'dart:math';
import 'dart:async';
import 'red_black_tree.dart';
import 'connection_statistics.dart';
import 'kademlia_tree/kademlia_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/core/data_structures/node_stats.dart';
import '../../proto/generated/dht/dht_messages.pb.dart';
// lib/src/protocols/dht/kademlia_tree.dart

/// Represents a Kademlia tree for efficient peer routing and lookup.
class KademliaTree {
  // Tree structure
  KademliaNode? _root;

  // List of k-buckets
  List<RedBlackTree<p2p.PeerId, KademliaNode>> _buckets = [];
  static const int kBucketSize = 20;

  // Track peer interactions
  Map<p2p.PeerId, DateTime> _lastSeen = {};
  Set<p2p.PeerId> _recentContacts = {};

  // Connection statistics and lookup history
  Map<p2p.PeerId, List<bool>> _lookupSuccessHistory = {};
  Map<p2p.PeerId, ConnectionStatistics> _connectionStats = {};
  Map<p2p.PeerId, NodeStats> _nodeStats = {};

  // Constructor
  KademliaTree(p2p.PeerId localPeerId, {KademliaNode? root}) {
    _root = root ??
        KademliaNode(
          localPeerId,
          0,
          localPeerId,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
        );

    // Pre-allocate buckets for 256-bit Peer IDs
    for (int i = 0; i < 256; i++) {
      _buckets.add(
        RedBlackTree<p2p.PeerId, KademliaNode>(
          compare: (p2p.PeerId a, p2p.PeerId b) {
            // Calculate XOR distances from the local node to both peers
            final distanceA = _xorDistance(_root!.peerId, a);
            final distanceB = _xorDistance(_root!.peerId, b);
            // Compare the distances to determine ordering
            return distanceA.compareTo(distanceB);
          },
        ),
      );
    }
  }

  // Public getters
  Map<p2p.PeerId, DateTime> get lastSeen => _lastSeen;
  Set<p2p.PeerId> get recentContacts => _recentContacts;
  Map<p2p.PeerId, List<bool>> get lookupSuccessHistory => _lookupSuccessHistory;
  Map<p2p.PeerId, ConnectionStatistics> get connectionStats => _connectionStats;
  Map<p2p.PeerId, NodeStats> get nodeStats => _nodeStats;
  List<RedBlackTree<p2p.PeerId, KademliaNode>> get buckets => _buckets;
  KademliaNode? get root => _root;

  Future<bool> Function(KademliaNode node) get isNodeActive => _isNodeActive;
  double Function(KademliaNode node) get calculateConnectionStabilityScore =>
      _calculateConnectionStabilityScore;

  get router => null;

  // Core Kademlia operations (using extensions)
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) =>
      this.addPeer(peerId, associatedPeerId);
  void removePeer(p2p.PeerId peerId) => this.removePeer(peerId);
  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) =>
      this.getAssociatedPeer(peerId);
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) =>
      this.findClosestPeers(target, k);

  // Node lookup
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    int k = 20; // Number of closest peers
    List<KademliaNode> closestNodes = findClosestPeers(target, k)
        .map((peerId) => _findNode(peerId)!)
        .toList();

    // TODO: Refactor to iterative lookup instead of recursive
    List<Future<List<p2p.PeerId>>> queries =
        closestNodes.map((node) => _queryNode(node, target)).toList();
    List<List<p2p.PeerId>> results = await Future.wait(queries);

    return this.nodeLookup(target);
  }

  KademliaNode? _findNode(p2p.PeerId peerId) {
    if (_root == null) return null;
    int distance = _xorDistance(peerId, _root!.peerId);
    int bucketIndex = distance % 256; // Assuming 256 buckets; adjust as needed

    final bucket = _buckets[bucketIndex];
    if (bucket.containsKey(peerId)) {
      return bucket[peerId];
    }
    return null;
  }

  int _xorDistance(p2p.PeerId a, p2p.PeerId b) {
    return calculateDistance(a, b);
  }

  Future<List<p2p.PeerId>> queryForNode(p2p.PeerId target,
      [List<p2p.PeerId>? knownNodes]) async {
    final findNodeMessage = p2p.Message(
      type: MessageType.findNode,
      payload: target.value,
    );

    final nodesToQuery = knownNodes ?? _getDefaultNodes();

    final responses = await Future.wait(nodesToQuery
        .map((node) => _sendMessageAndAwaitResponse(node, findNodeMessage)));

    final closerPeers = <p2p.PeerId>[];
    for (final response in responses) {
      if (response != null &&
          response is p2p.Message &&
          response.type == MessageType.findNodeResponse) {
        final peerIds = (response.payload as List<dynamic>?)
                ?.map((bytes) =>
                    p2p.PeerId(Uint8List.fromList(bytes as List<int>)))
                .toList() ??
            [];
        closerPeers.addAll(peerIds);
      }
    }

    return closerPeers;
  }

  Future<p2p.Message?> _sendMessageAndAwaitResponse(
      p2p.PeerId peerId, p2p.Message message) async {
    final completer = Completer<p2p.Message?>();

    Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      // TODO: Replace with your actual router's sendMessage method.
      router.sendMessage(
          dstPeerId: peerId,
          message: message); // Assuming your router has this method.
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }

    //TODO: Replace with your actual router's onMessage stream
    router.onMessage.listen((receivedMessage) {
      if (receivedMessage.type == MessageType.findNodeResponse &&
          _isMatchingRequest(receivedMessage, message)) {
        completer.complete(receivedMessage);
      }
    });

    return completer.future;
  }

  bool _isMatchingRequest(
      p2p.Message receivedMessage, p2p.Message sentMessage) {
    // TODO: Implement proper request matching logic.  Add a request ID or similar property to your Message objects
    return true; // Placeholder
  }

  List<p2p.PeerId> _getDefaultNodes() {
    // TODO: Implement logic to retrieve default/bootstrap nodes.  Read from config or hardcode a list
    return []; // Placeholder
  }

  // TODO: Add logic to split buckets if needed and manage them properly
  void splitBucket(int bucketIndex) => this.splitBucket(bucketIndex);

  void mergeBuckets(int bucketIndex1, int bucketIndex2) =>
      this.mergeBuckets(bucketIndex1, bucketIndex2);

  // Node activity check
  Future<bool> _isNodeActive(KademliaNode node) async {
    final now = DateTime.now();
    final lastSeenTime = _lastSeen[node.peerId];
    final nodeActivityThreshold = Duration(minutes: 10);

    if (lastSeenTime == null ||
        now.difference(lastSeenTime) > nodeActivityThreshold) {
      return false;
    }

    bool pingSentSuccessfully = _sendPingMessage(node.peerId);
    if (!pingSentSuccessfully) return false;

    try {
      bool pingResponseReceived = await _receivePingResponse(node.peerId)
          .timeout(const Duration(seconds: 5))
          .then((value) => value != null);
      if (!pingResponseReceived) return false;
    } catch (e) {
      print('Error: $e');
      return false;
    }

    final lookupHistory = _lookupSuccessHistory[node.peerId] ?? [];
    final recentLookups = lookupHistory.take(10).toList();
    final hasConsecutiveSuccesses =
        recentLookups.take(3).every((success) => success);
    double weightedSuccesses = recentLookups.asMap().entries.fold<double>(
          0,
          (sum, entry) => sum + (entry.value ? pow(0.8, entry.key) : 0),
        );

    return weightedSuccesses >= 2.0 && hasConsecutiveSuccesses;
  }

  // Ping and message handling
  Future<PingResponse> _receivePingResponse(p2p.PeerId peerId) async {
    final completer = Completer<PingResponse>();
    this.router.onMessage((message) {
      if (message is PingResponse && message.peerId == peerId) {
        completer.complete(message);
      }
    });
    return completer.future;
  }

  bool _sendPingMessage(p2p.PeerId peerId) {
    print('Sending ping to $peerId');
    return true; // Assume success
  }

  // Metrics calculations
  double _calculateConnectionStabilityScore(KademliaNode node) {
    final connectionStats = _connectionStats[node.peerId];
    if (connectionStats == null) return 0;

    double score = 1.0 -
        (connectionStats.disconnections /
                connectionStats.totalConnections *
                0.6 +
            connectionStats.averageLatency / 1000 * 0.3 +
            (1 / connectionStats.averageConnectionDuration) * 0.1);

    return max(0.0, min(1.0, score));
  }

  double _calculateBandwidthScore(KademliaNode node) {
    final nodeStats = _nodeStats[node.peerId];
    if (nodeStats == null) return 0;

    return (nodeStats.bandwidthSent + nodeStats.bandwidthReceived) / 1000000;
  }

  // XOR distance calculation (useful for Kademlia's bucket and peer management)
  int _xorDistance(p2p.PeerId a, p2p.PeerId b) {
    return calculateDistance(a, b);
  }

  // Clear recent contacts
  void clearRecentContacts() {
    _recentContacts.clear();
  }

  // Add setter for root
  set root(KademliaNode? node) {
    _root = node;
  }
}

extension RedBlackTreeGetOperator<K, V> on RedBlackTree<K, V> {
  V? operator [](K key) {
    // Implement the [] logic here
    for (var entry in this.entries) {
      if (entry.key == key) {
        return entry.value;
      }
    }
    return null;
  }
}

// Extension for RedBlackTree to support containsKey functionality
extension RedBlackTreeContainsKey<K, V> on RedBlackTree<K, V> {
  bool containsKey(K key) {
    for (var entry in this.entries) {
      if (entry.key == key) {
        return true;
      }
    }
    return false;
  }
}
