import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/core/messages/message_factory.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart'
    as helpers;
import 'package:dart_ipfs/src/utils/logger.dart';

import 'connection_statistics.dart';
import 'kademlia_tree/find_closest_peers.dart';
import 'kademlia_tree/kademlia_tree_node.dart';
import 'kademlia_tree/lru_cache.dart';
import 'kademlia_tree/protocol_messages.dart';
import 'kademlia_tree/refresh.dart';
import 'kademlia_tree/value_store.dart';
import 'provider_store.dart';
import 'rate_limiter.dart';
import 'red_black_tree.dart';

/// Kademlia DHT routing table implementation using a tree structure of k-buckets.
class KademliaTree {
  /// Creates a [KademliaTree] and initializes its buckets and maintenance tasks.
  KademliaTree(this.dhtClient, {KademliaTreeNode? root})
    : _logger = Logger('KademliaTree') {
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
    _providerStore = ProviderStore();
    _startValueMaintenanceTasks();

    _lookupLimiter = RateLimiter(
      maxOperations: 50,
      interval: const Duration(minutes: 1),
    );

    _storeLimiter = RateLimiter(
      maxOperations: 100,
      interval: const Duration(minutes: 1),
    );

    _findValueLimiter = RateLimiter(
      maxOperations: 100,
      interval: const Duration(minutes: 1),
    );
  }

  final Logger _logger;
  KademliaTreeNode? _root;

  /// Maximum peers per bucket.
  static const int K = 20;

  /// Parallelism factor for lookups.
  static const int alpha = 3;

  /// Interval for refreshing stale buckets.
  static const Duration refreshInterval = Duration(hours: 1);

  /// Threshold for considering a peer stale.
  static const Duration refreshTimeout = Duration(hours: 1);

  /// Interval for republishing local keys to the network.
  static const Duration republishInterval = Duration(hours: 24);

  /// Default timeout for individual node network requests.
  static const Duration nodeTimeout = Duration(seconds: 5);

  final List<RedBlackTree<PeerId, KademliaTreeNode>> _buckets = [];
  final Map<PeerId, DateTime> _lastSeen = {};
  final Set<PeerId> _recentContacts = {};
  final Map<int, Completer<kad.Message>> _pendingRequests = {};

  final Map<PeerId, List<bool>> _lookupSuccessHistory = {};
  final Map<PeerId, ConnectionStatistics> _connectionStats = {};
  final Map<PeerId, NodeStats> _nodeStats = {};

  /// The underlying [DHTClient].
  final DHTClient dhtClient;
  late final ValueStore _valueStore;
  late final ProviderStore _providerStore;

  late final RateLimiter _lookupLimiter;
  late final RateLimiter _storeLimiter;
  late final RateLimiter _findValueLimiter;

  final Map<int, LRUCache> _bucketCaches = {};

  // Public getters for other files in the same package/logic
  /// The root node of the Kademlia tree.
  KademliaTreeNode? get root => _root;
  /// The buckets containing peer nodes.
  List<RedBlackTree<PeerId, KademliaTreeNode>> get buckets => _buckets;
  /// Maps peers to the time they were last seen.
  Map<PeerId, DateTime> get lastSeen => _lastSeen;
  /// A set of recently contacted peers.
  Set<PeerId> get recentContacts => _recentContacts;
  /// The history of successful lookups per peer.
  Map<PeerId, List<bool>> get lookupSuccessHistory => _lookupSuccessHistory;
  /// Statistics regarding peer connections.
  Map<PeerId, ConnectionStatistics> get connectionStats => _connectionStats;
  /// Node statistics.
  Map<PeerId, NodeStats> get nodeStats => _nodeStats;
  /// LRU caches for buckets.
  Map<int, LRUCache> get bucketCaches => _bucketCaches;

  void _initializeBuckets() {
    for (int i = 0; i < 256; i++) {
      _buckets.add(
        RedBlackTree<PeerId, KademliaTreeNode>(
          compare: (PeerId a, PeerId b) {
            final int distanceA = helpers.calculateDistance(_root!.peerId, a);
            final int distanceB = helpers.calculateDistance(_root!.peerId, b);
            if (distanceA != distanceB) {
              return distanceA.compareTo(distanceB);
            }
            return a.toString().compareTo(b.toString());
          },
        ),
      );
    }
  }

  void _startPeriodicTasks() {
    Timer.periodic(refreshInterval, (_) => refresh());
    Timer.periodic(republishInterval, (_) => _republishKeys());
    Timer.periodic(const Duration(hours: 1), (_) => _providerStore.gc());
  }

  void _startValueMaintenanceTasks() {
    Timer.periodic(republishInterval, (_) async {
      try {
        await _valueStore.republishValues();
      } catch (e) {
        _logger.error('Failed to republish values during maintenance', e);
      }
    });
  }

  /// Performs an iterative node lookup to find the K closest peers to [target].
  Future<List<PeerId>> nodeLookup(PeerId target) async {
    try {
      await _lookupLimiter.acquire();
      _logger.debug('Starting node lookup for target: $target');

      final Set<PeerId> queriedPeers = {};
      List<PeerId> closestPeers = findClosestPeers(target, K);

      int stagnantRounds = 0;
      const int maxStagnantRounds = 3;
      double previousBestDistance = double.infinity;

      for (int iteration = 0; iteration < 20; iteration++) {
        final List<PeerId> peersToQuery = closestPeers
            .where((p) => !queriedPeers.contains(p))
            .take(alpha)
            .toList();

        if (peersToQuery.isEmpty) break;

        final double currentBestDistance = helpers
            .calculateDistance(target, closestPeers.first)
            .toDouble();

        if (currentBestDistance >= previousBestDistance) {
          stagnantRounds++;
          if (stagnantRounds >= maxStagnantRounds) break;
        } else {
          stagnantRounds = 0;
          previousBestDistance = currentBestDistance;
        }

        try {
          final List<Future<List<PeerId>>> queries = peersToQuery.map((
            PeerId peer,
          ) async {
            return await _sendFindNodeRequest(peer, target);
          }).toList();

          final List<List<PeerId>> results = await Future.wait(
            queries,
            eagerError: false,
          ).timeout(const Duration(seconds: 30), onTimeout: () => []);

          final Set<PeerId> newPeers = {};
          for (final List<PeerId> peerList in results) {
            newPeers.addAll(peerList);
          }

          queriedPeers.addAll(peersToQuery);

          final List<PeerId> allPeers = [...closestPeers, ...newPeers];
          allPeers.sort(
            (a, b) => helpers
                .calculateDistance(target, a)
                .compareTo(helpers.calculateDistance(target, b)),
          );

          closestPeers = allPeers.take(K).toList();
        } catch (e) {
          _logger.warning('Error in lookup iteration $iteration: $e');
          continue;
        }
      }

      return closestPeers;
    } finally {
      _lookupLimiter.release();
    }
  }

  /// Entry point for all incoming DHT protocol messages.
  void handleIncomingMessage(kad.Message message, {int? requestId}) {
    if (requestId != null) {
      handleResponse(requestId, message);
      return;
    }

    switch (message.type) {
      case kad.Message_MessageType.PING:
        _handlePing(message);
        break;
      case kad.Message_MessageType.FIND_NODE:
        _handleFindNode(message);
        break;
      case kad.Message_MessageType.GET_VALUE:
        _handleGetValue(message);
        break;
      case kad.Message_MessageType.PUT_VALUE:
        _handlePutValue(message);
        break;
      case kad.Message_MessageType.ADD_PROVIDER:
        _handleAddProvider(message);
        break;
      case kad.Message_MessageType.GET_PROVIDERS:
        _handleGetProviders(message);
        break;
      default:
        _logger.verbose('Received unhandled DHT message type: ${message.type}');
    }
  }

  void _handleAddProvider(kad.Message message) {
    _logger.debug('Handling ADD_PROVIDER for key: ${message.key}');
    final cid = CID.fromBytes(Uint8List.fromList(message.key));
    for (final provider in message.providerPeers) {
      _providerStore.addProvider(cid, PeerId(value: Uint8List.fromList(provider.id)));
    }
  }

  void _handleGetProviders(kad.Message message) {
    _logger.debug('Handling GET_PROVIDERS for key: ${message.key}');
  }

  /// Announces that this node provides the content identified by [cid].
  Future<void> provide(CID cid) async {
    _logger.info('Providing CID: $cid');
    final closestPeers = await nodeLookup(PeerId(value: cid.toBytes()));
    
    for (final peer in closestPeers) {
      final requestId = _generateRequestId();
      final message = AddProviderMessage(
        requestId.toString(),
        _root!.peerId,
        peer,
        cid.toBytes(),
      ).toDHTMessage();
      
      try {
        await _sendMessageWithTimeout(peer, message, requestId);
      } catch (e) {
        _logger.debug('Failed to send ADD_PROVIDER to $peer: $e');
      }
    }
  }

  /// Finds providers for the given [cid].
  Future<List<PeerId>> findProviders(CID cid) async {
    _logger.info('Finding providers for CID: $cid');
    final localProviders = _providerStore.getProviders(cid);
    if (localProviders.isNotEmpty) {
      return localProviders;
    }

    final targetPeerId = PeerId(value: cid.toBytes());
    final closestPeers = findClosestPeers(targetPeerId, K);
    final allProviders = <PeerId>{};

    for (final peer in closestPeers) {
      final requestId = _generateRequestId();
      final message = GetProvidersMessage(
        requestId.toString(),
        _root!.peerId,
        peer,
        cid.toBytes(),
      ).toDHTMessage();

      try {
        final response = await _sendMessageWithTimeout(peer, message, requestId);
        if (response.type == kad.Message_MessageType.GET_PROVIDERS) {
          for (final provider in response.providerPeers) {
            allProviders.add(PeerId(value: Uint8List.fromList(provider.id)));
          }
        }
      } catch (e) {
        _logger.debug('GET_PROVIDERS request failed for $peer: $e');
      }
    }

    return allProviders.toList();
  }

  Future<List<PeerId>> _sendFindNodeRequest(PeerId peer, PeerId target) async {
    final int requestId = _generateRequestId();
    final kad.Message message = FindNodeMessage(
      requestId.toString(),
      _root!.peerId,
      peer,
      target,
    ).toDHTMessage();

    try {
      final kad.Message response = await _sendMessageWithTimeout(
        peer,
        message,
        requestId,
      );
      return _processFindNodeResponse(response);
    } catch (e) {
      _logger.debug('FIND_NODE request failed for $peer: $e');
      return [];
    }
  }

  int _generateRequestId() =>
      DateTime.now().millisecondsSinceEpoch + Random.secure().nextInt(1000000);

  Future<kad.Message> _sendMessageWithTimeout(
    PeerId peer,
    kad.Message message,
    int requestId,
  ) {
    final Completer<kad.Message> completer = Completer<kad.Message>();
    _pendingRequests[requestId] = completer;

    final IPFSMessage ipfsMessage = MessageFactory.createBaseMessage(
      protocolId: '/ipfs/kad/1.0.0',
      payload: message.writeToBuffer(),
      senderId: _root!.peerId.toBase58(),
      type: IPFSMessage_MessageType.DHT,
    );
    ipfsMessage.requestId = requestId.toString();

    final Uint8List messageBytes = ipfsMessage.writeToBuffer();
    dhtClient.router.sendMessage(peer.toBase58(), messageBytes);

    return completer.future.timeout(
      nodeTimeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException(
          'DHT request $requestId to ${peer.toBase58()} timed out',
        );
      },
    );
  }

  List<PeerId> _processFindNodeResponse(kad.Message response) {
    try {
      if (response.type != kad.Message_MessageType.FIND_NODE &&
          response.type != kad.Message_MessageType.GET_PROVIDERS) {
        return [];
      }
      return response.closerPeers
          .map((kad.Peer peer) => PeerId(value: Uint8List.fromList(peer.id)))
          .toList();
    } catch (e) {
      _logger.warning('Failed to process response: $e');
      return [];
    }
  }

  /// Handles an incoming response from a DHT request.
  void handleResponse(int requestId, kad.Message response) {
    final Completer<kad.Message>? completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  /// Handles a PING message.
  void _handlePing(kad.Message message) {}
  /// Handles a FIND_NODE message.
  void _handleFindNode(kad.Message message) {}
  /// Handles a GET_VALUE message.
  void _handleGetValue(kad.Message message) {}
  /// Handles a PUT_VALUE message.
  void _handlePutValue(kad.Message message) {}

  /// Republishes keys to the network.
  void _republishKeys() async {
    try {
      await _valueStore.republishValues();
    } catch (e) {
      _logger.error('Key republication failed', e);
    }
  }

  /// Refreshes the DHT routing table.
  void refresh() {
    Refresh(this).refresh();
  }

  /// Finds the K closest peers to the target [target] peer ID.
  List<PeerId> findClosestPeers(PeerId target, int k) {
    return FindClosestPeers(this).findClosestPeers(target, k);
  }

  /// Sends a PING request to a [peer].
  Future<bool> sendPing(PeerId peer) async {
    final int requestId = _generateRequestId();
    final kad.Message message = PingMessage(
      requestId.toString(),
      _root!.peerId,
      peer,
    ).toDHTMessage();

    try {
      final kad.Message response = await _sendMessageWithTimeout(peer, message, requestId);
      return response.type == kad.Message_MessageType.PING;
    } catch (e) {
      return false;
    }
  }

  /// Stores a value in the DHT using the provided [key] and [value] on the given [peer].
  Future<bool> storeValue(PeerId peer, Uint8List key, Uint8List value) async {
    try {
      await _storeLimiter.acquire();
      final int requestId = _generateRequestId();
      final kad.Message message = StoreMessage(
        requestId.toString(),
        _root!.peerId,
        peer,
        key,
        value,
      ).toDHTMessage();

      try {
        final kad.Message response = await _sendMessageWithTimeout(peer, message, requestId);
        return response.type == kad.Message_MessageType.PUT_VALUE;
      } catch (e) {
        return false;
      }
    } finally {
      _storeLimiter.release();
    }
  }

  /// Iteratively finds the closest nodes to [key].
  Future<(Uint8List?, List<PeerId>)> findValue(Uint8List key) async {
    try {
      await _findValueLimiter.acquire();
      final PeerId targetPeerId = PeerId(value: key);
      final List<PeerId> closestPeers = findClosestPeers(targetPeerId, K);

      for (final PeerId peer in closestPeers) {
        final int requestId = _generateRequestId();
        final kad.Message message = FindValueMessage(
          requestId.toString(),
          _root!.peerId,
          peer,
          key,
        ).toDHTMessage();

        try {
          final kad.Message response = await _sendMessageWithTimeout(peer, message, requestId);
          if (response.type == kad.Message_MessageType.GET_VALUE && response.hasRecord()) {
            return (Uint8List.fromList(response.record.value), <PeerId>[]);
          }
          final List<PeerId> closerPeers = _processFindNodeResponse(response);
          if (closerPeers.isNotEmpty) {
            return (null, closerPeers);
          }
        } catch (e) {
          _logger.debug('Error in findValue iteration: $e');
        }
      }
      return (null, <PeerId>[]);
    } finally {
      _findValueLimiter.release();
    }
  }

  /// Stores a local key-value pair in the DHT.
  Future<void> storeLocalValue(String key, Uint8List value) async {
    await _valueStore.store(key, value);
  }

  /// Retrieves a local value from the DHT.
  Future<Uint8List?> getValue(String key) async {
    return await _valueStore.retrieve(key);
  }

  /// Returns the peer associated with the given [peerId].
  PeerId? getAssociatedPeer(PeerId peerId) {
    for (final bucket in _buckets) {
      final node = bucket[peerId];
      if (node != null) return node.associatedPeerId;
    }
    return null;
  }
}
