import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/core/messages/message_factory.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart'
    as helpers;
import 'package:p2plib/p2plib.dart' as p2p;

import 'connection_statistics.dart';
import 'kademlia_tree/find_closest_peers.dart';
import 'kademlia_tree/kademlia_tree_node.dart';
import 'kademlia_tree/lru_cache.dart';
import 'kademlia_tree/protocol_messages.dart';
import 'kademlia_tree/refresh.dart';
import 'kademlia_tree/value_store.dart';
import 'rate_limiter.dart';
import 'red_black_tree.dart';

/// Kademlia DHT routing table implementation using a tree structure.
///
/// The Kademlia tree organizes peers into k-buckets based on XOR distance
/// from the local node. This enables efficient O(log n) lookups across
/// a distributed network.
///
/// **Key Kademlia Parameters:**
/// - `K = 20`: Maximum peers per bucket (replication factor)
/// - `alpha = 3`: Concurrent lookup parallelism
///
/// **Core Operations:**
/// - [nodeLookup]: Find the K closest peers to a target
/// - [findClosestPeers]: Query local buckets for nearest peers
/// - [storeValue] / [findValue]: DHT key-value operations
///
/// Example:
/// ```dart
/// final tree = KademliaTree(dhtClient);
///
/// // Find peers close to a target
/// final peers = await tree.nodeLookup(targetPeerId);
///
/// // Store a value in the DHT
/// await tree.storeLocalValue(key, valueBytes);
/// ```
///
/// See also:
/// - [DHTClient] for the DHT protocol handler
/// - [Kademlia paper](https://pdos.csail.mit.edu/~petar/papers/maymounkov-kademlia-lncs.pdf)
class KademliaTree {
  /// Creates a new Kademlia tree with the given [dhtClient].
  ///
  /// Optionally accepts a [root] node for custom initialization.
  KademliaTree(this.dhtClient, {KademliaTreeNode? root}) {
    _root =
        root ??
        KademliaTreeNode(
          dhtClient.peerId,
          0,
          dhtClient.peerId,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
        );

    _initializeBuckets();
    _startPeriodicTasks();
    _valueStore = ValueStore(dhtClient);
    _startValueMaintenanceTasks();

    // Initialize rate limiters with reasonable defaults
    _lookupLimiter = RateLimiter(
      maxOperations: 50, // 50 lookups per window
      interval: const Duration(minutes: 1),
    );

    _storeLimiter = RateLimiter(
      maxOperations: 100, // 100 store operations per window
      interval: const Duration(minutes: 1),
    );

    _findValueLimiter = RateLimiter(
      maxOperations: 100, // 100 find value queries per window
      interval: const Duration(minutes: 1),
    );
  }
  // Tree structure
  KademliaTreeNode? _root;

  /// Maximum peers per k-bucket (replication factor).
  static const int K = 20;

  /// Number of concurrent lookups for parallel queries.
  static const int alpha = 3;

  /// Interval between periodic bucket refresh operations.
  static const Duration refreshInterval = Duration(hours: 1);

  /// Interval between key republishing.
  static const Duration republishInterval = Duration(hours: 24);

  /// Timeout for individual node requests.
  static const Duration nodeTimeout = Duration(seconds: 5);

  // List of k-buckets (256 for IPv6 compatibility)
  final List<RedBlackTree<p2p.PeerId, KademliaTreeNode>> _buckets = [];

  // Peer tracking
  final Map<p2p.PeerId, DateTime> _lastSeen = {};
  final Set<p2p.PeerId> _recentContacts = {};
  final Map<int, Completer<kad.Message>> _pendingRequests = {};

  // Statistics
  final Map<p2p.PeerId, List<bool>> _lookupSuccessHistory = {};
  final Map<p2p.PeerId, ConnectionStatistics> _connectionStats = {};
  final Map<p2p.PeerId, NodeStats> _nodeStats = {};

  /// Timeout duration for bucket refreshes.
  final refreshTimeout = const Duration(minutes: 30);

  /// The underlying DHT client for network operations.
  final DHTClient dhtClient;

  late final ValueStore _valueStore;

  // Rate limiters for different operations
  late final RateLimiter _lookupLimiter;
  late final RateLimiter _storeLimiter;
  late final RateLimiter _findValueLimiter;

  final Map<int, LRUCache> _bucketCaches = {};

  void _initializeBuckets() {
    for (int i = 0; i < 256; i++) {
      _buckets.add(
        RedBlackTree<p2p.PeerId, KademliaTreeNode>(
          compare: (p2p.PeerId a, p2p.PeerId b) {
            final distanceA = helpers.calculateDistance(_root!.peerId, a);
            final distanceB = helpers.calculateDistance(_root!.peerId, b);
            return distanceA.compareTo(distanceB);
          },
        ),
      );
    }
  }

  void _startPeriodicTasks() {
    Timer.periodic(refreshInterval, (_) => refresh());
    Timer.periodic(republishInterval, (_) => _republishKeys());
  }

  void _startValueMaintenanceTasks() {
    // Republish values periodically
    Timer.periodic(republishInterval, (_) async {
      await _valueStore.republishValues();
    });
  }

  /// Map of last seen timestamps for peers.
  Map<p2p.PeerId, DateTime> get lastSeen => _lastSeen;

  /// Set of recently contacted peers.
  Set<p2p.PeerId> get recentContacts => _recentContacts;

  /// Lookup success history by peer.
  Map<p2p.PeerId, List<bool>> get lookupSuccessHistory => _lookupSuccessHistory;

  /// Connection statistics by peer.
  Map<p2p.PeerId, ConnectionStatistics> get connectionStats => _connectionStats;

  /// Node statistics by peer.
  Map<p2p.PeerId, NodeStats> get nodeStats => _nodeStats;

  /// The list of k-buckets.
  List<RedBlackTree<p2p.PeerId, KademliaTreeNode>> get buckets => _buckets;

  /// The root node of the tree.
  KademliaTreeNode? get root => _root;

  /// Performs an iterative node lookup to find the K closest peers to [target].
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    try {
      await _lookupLimiter.acquire();

      Set<p2p.PeerId> queriedPeers = {};
      List<p2p.PeerId> closestPeers = findClosestPeers(target, K);
      int consecutiveFailedAttempts = 0;
      Duration backoffDuration = const Duration(
        milliseconds: 100,
      ); // Initial backoff
      final maxBackoff = const Duration(seconds: 10);
      final minImprovement = 0.01; // 1% improvement threshold

      double previousBestDistance = double.infinity;
      int stagnantRounds = 0;
      final maxStagnantRounds = 3;

      for (int iteration = 0; iteration < 20; iteration++) {
        List<p2p.PeerId> peersToQuery = closestPeers
            .where((p) => !queriedPeers.contains(p))
            .take(alpha)
            .toList();

        if (peersToQuery.isEmpty) {
          // If no new peers to query and we've queried some peers, we're done
          if (queriedPeers.isNotEmpty) break;
          return closestPeers;
        }

        // Calculate current best distance
        double currentBestDistance = helpers
            .calculateDistance(target, closestPeers.first)
            .toDouble();

        // Check for sufficient improvement
        double improvement =
            (previousBestDistance - currentBestDistance) / previousBestDistance;
        if (improvement < minImprovement) {
          stagnantRounds++;
          if (stagnantRounds >= maxStagnantRounds) break;
        } else {
          stagnantRounds = 0;
          previousBestDistance = currentBestDistance;
        }

        try {
          List<Future<List<p2p.PeerId>>> queries = peersToQuery.map((
            peer,
          ) async {
            try {
              // Apply exponential backoff if there were failures
              if (consecutiveFailedAttempts > 0) {
                await Future<void>.delayed(backoffDuration);
              }
              return await _sendFindNodeRequest(peer, target);
            } catch (e) {
              consecutiveFailedAttempts++;
              // Exponential backoff with max limit
              backoffDuration *= 2;
              if (backoffDuration > maxBackoff) {
                backoffDuration = maxBackoff;
              }
              rethrow;
            }
          }).toList();

          List<List<p2p.PeerId>> results = await Future.wait(
            queries,
            eagerError: false,
          ).timeout(const Duration(seconds: 30), onTimeout: () => []);

          // Reset backoff on successful queries
          if (results.isNotEmpty) {
            consecutiveFailedAttempts = 0;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          Set<p2p.PeerId> newPeers = {};
          for (var peerList in results) {
            newPeers.addAll(peerList);
          }

          queriedPeers.addAll(peersToQuery);

          // Remove any peers that have consistently failed
          newPeers.removeWhere(
            (peer) =>
                lookupSuccessHistory[peer]?.last == false &&
                lookupSuccessHistory[peer]!.length >= 3,
          );

          List<p2p.PeerId> allPeers = [...closestPeers, ...newPeers];
          allPeers.sort(
            (a, b) => helpers
                .calculateDistance(target, a)
                .compareTo(helpers.calculateDistance(target, b)),
          );

          List<p2p.PeerId> newClosestPeers = allPeers.take(K).toList();

          // Enhanced termination condition
          if (_areListsEqual(closestPeers, newClosestPeers) &&
              currentBestDistance <
                  previousBestDistance * (1 + minImprovement)) {
            break;
          }

          closestPeers = newClosestPeers;
        } catch (e) {
          // print('Error in lookup iteration $iteration: $e');
          // Don't break on errors, let the backoff mechanism handle it
          continue;
        }
      }

      return closestPeers;
    } finally {
      _lookupLimiter.release();
    }
  }

  Future<List<p2p.PeerId>> _sendFindNodeRequest(
    p2p.PeerId peer,
    p2p.PeerId target,
  ) async {
    final requestId = _generateRequestId();
    final message = FindNodeMessage(
      requestId.toString(),
      _root!.peerId,
      peer,
      target,
    ).toDHTMessage();

    try {
      final response = await _sendMessageWithTimeout(peer, message, requestId);
      return _processFindNodeResponse(response);
    } catch (e) {
      // print('Error in find node request to $peer: $e');
      return [];
    }
  }

  int _generateRequestId() =>
      DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000000);

  Future<kad.Message> _sendMessageWithTimeout(
    p2p.PeerId peer,
    kad.Message message,
    int requestId,
  ) {
    final completer = Completer<kad.Message>();
    _pendingRequests[requestId] = completer;

    // Convert to IPFSMessage protobuf using MessageFactory
    final ipfsMessage = MessageFactory.createBaseMessage(
      protocolId: '/ipfs/kad/1.0.0',
      payload: message.writeToBuffer(),
      senderId: _root!.peerId.toString(),
      type: IPFSMessage_MessageType.DHT,
    );
    ipfsMessage.requestId = requestId.toString();

    final messageBytes = ipfsMessage.writeToBuffer();

    // Use sendDatagram directly from dhtClient's router
    dhtClient.router.sendDatagram(
      addresses: dhtClient.router.resolvePeerId(peer),
      datagram: messageBytes,
    );

    return completer.future.timeout(
      nodeTimeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException('Request timed out');
      },
    );
  }

  List<p2p.PeerId> _processFindNodeResponse(kad.Message response) {
    try {
      if (response.type != kad.Message_MessageType.FIND_NODE) return [];

      return response.closerPeers
          .map((peer) => p2p.PeerId(value: Uint8List.fromList(peer.id)))
          .toList();
    } catch (e) {
      // print('Error processing find node response: $e');
      return [];
    }
  }

  // Message handling
  /// Handles an incoming DHT message.
  void handleIncomingMessage(p2p.Message message) {
    try {
      final ipfsMessage = IPFSMessage.fromBuffer(message.payload!);
      final requestId = int.tryParse(ipfsMessage.requestId) ?? 0;

      final dhtMessage = kad.Message.fromBuffer(ipfsMessage.payload);

      if (_pendingRequests.containsKey(requestId)) {
        _pendingRequests[requestId]!.complete(dhtMessage);
        _pendingRequests.remove(requestId);
      }

      _updateLastSeen(message.srcPeerId);
    } catch (e) {
      // print('Error handling incoming message: $e');
    }
  }

  void _updateLastSeen(p2p.PeerId peerId) {
    _lastSeen[peerId] = DateTime.now();
  }

  // Helper methods
  bool _areListsEqual(List<p2p.PeerId> a, List<p2p.PeerId> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  void _republishKeys() async {
    try {
      await _valueStore.republishValues();
    } catch (e) {
      // print('Error in _republishKeys: $e');
    }
  }

  /// Refreshes all k-buckets.
  void refresh() {
    // This will use the extension method from refresh.dart
    Refresh(this).refresh();
  }

  /// Finds the k closest peers to the target.
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) {
    return FindClosestPeers(this).findClosestPeers(target, k);
  }

  /// Sends a ping request to a peer.
  Future<p2p.Message?> sendPingRequest(p2p.PeerId peer) async {
    final requestId = _generateRequestId();
    final pingMessage = PingMessage(
      requestId.toString(),
      _root!.peerId,
      peer,
    ).toDHTMessage();

    try {
      final response = await _sendMessageWithTimeout(
        peer,
        pingMessage,
        requestId,
      );

      // Convert DHTMessage to p2p.Message
      return p2p.Message(
        srcPeerId: peer,
        dstPeerId: _root!.peerId,
        header: p2p.PacketHeader(
          id: int.parse(
            requestId.toString(),
          ), // Use local requestId since response ID is in IPFSMessage wrapper, not DHTMessage
          issuedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        payload: response.writeToBuffer(),
      );
    } catch (e) {
      // print('Ping request failed: $e');
      return null;
    }
  }

  /// Sends a ping and returns true if the peer responds.
  Future<bool> sendPing(p2p.PeerId peer) async {
    final requestId = _generateRequestId();
    final message = PingMessage(
      requestId.toString(),
      _root!.peerId,
      peer,
    ).toDHTMessage();

    try {
      final response = await _sendMessageWithTimeout(peer, message, requestId);
      return response.type == kad.Message_MessageType.PING;
    } catch (e) {
      // print('Ping failed for peer $peer: $e');
      return false;
    }
  }

  /// Stores a value at a remote peer.
  Future<bool> storeValue(
    p2p.PeerId peer,
    Uint8List key,
    Uint8List value,
  ) async {
    try {
      await _storeLimiter.acquire();

      final requestId = _generateRequestId();
      final message = StoreMessage(
        requestId.toString(),
        _root!.peerId,
        peer,
        key,
        value,
      ).toDHTMessage();

      try {
        final response = await _sendMessageWithTimeout(
          peer,
          message,
          requestId,
        );
        return response.type == kad.Message_MessageType.PUT_VALUE;
      } catch (e) {
        // print('Store value failed for peer $peer: $e');
        return false;
      }
    } finally {
      _storeLimiter.release();
    }
  }

  /// Finds a value by key in the DHT.
  Future<(Uint8List?, List<p2p.PeerId>)> findValue(Uint8List key) async {
    try {
      await _findValueLimiter.acquire();

      final targetPeerId = p2p.PeerId(value: key);
      final closestPeers = findClosestPeers(targetPeerId, K);

      for (final peer in closestPeers) {
        final requestId = _generateRequestId();
        final message = FindValueMessage(
          requestId.toString(),
          _root!.peerId,
          peer,
          key,
        ).toDHTMessage();

        try {
          final response = await _sendMessageWithTimeout(
            peer,
            message,
            requestId,
          );
          if (response.type == kad.Message_MessageType.GET_VALUE &&
              (response.hasRecord() || response.providerPeers.isNotEmpty)) {
            // Check record or providers (GET_VALUE might return providers too?)
            // Assuming record field is populated for value
            if (response.hasRecord()) {
              return (
                Uint8List.fromList(response.record.value),
                <p2p.PeerId>[],
              );
            }
          }
          // If value not found, return closer peers
          final closerPeers = _processFindNodeResponse(response);
          return (null, closerPeers);
        } catch (e) {
          // print('Find value failed for peer $peer: $e');
        }
      }
      return (null, <p2p.PeerId>[]);
    } finally {
      _findValueLimiter.release();
    }
  }

  /// Stores a value locally in the DHT.
  Future<void> storeLocalValue(String key, Uint8List value) async {
    await _valueStore.store(key, value);
  }

  /// Retrieves a locally stored value by key.
  Future<Uint8List?> getValue(String key) async {
    return await _valueStore.retrieve(key);
  }

  /// Access to bucket caches.
  Map<int, LRUCache> get bucketCaches => _bucketCaches;

  /// Gets the associated peer for a given peer ID.
  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) {
    for (var bucket in _buckets) {
      for (var entry in bucket.entries) {
        if (entry.key == peerId) {
          return entry.value.associatedPeerId;
        }
      }
    }
    return null;
  }
}

/// Extension for index-based access on RedBlackTree.
extension RedBlackTreeGetOperator<K, V> on RedBlackTree<K, V> {
  /// Returns the value for [key], or null if not found.
  V? operator [](K key) {
    for (var entry in entries) {
      if (entry.key == key) {
        return entry.value;
      }
    }
    return null;
  }
}

/// Extension for containsKey functionality on RedBlackTree.
extension RedBlackTreeContainsKey<K, V> on RedBlackTree<K, V> {
  /// Returns true if [key] exists in the tree.
  bool containsKey(K key) {
    for (var entry in entries) {
      if (entry.key == key) {
        return true;
      }
    }
    return false;
  }
}
