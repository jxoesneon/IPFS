// src/protocols/dht/dht_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart'; // For SHA256
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;

import '../../core/cid.dart';
import '../../core/config/ipfs_config.dart';
import '../../core/ipfs_node/ipfs_node.dart';
import '../../core/ipfs_node/network_handler.dart';
import '../../core/metrics/metrics_collector.dart';
import '../../core/storage/datastore.dart' as ds;
import '../../core/types/peer_id.dart';
import '../../proto/generated/dht/dht.pb.dart' as dht_proto;
import '../../proto/generated/dht/ipfs_node_network_events.pb.dart'
    as ipfs_node_network_events;
import '../../proto/generated/dht/kademlia.pb.dart' as kad;
import '../../transport/libp2p_router.dart';
import '../../transport/router_interface.dart';
import '../../utils/base58.dart';
import '../../utils/logger.dart';
import 'dht_envelope.dart';
import 'kademlia_routing_adapter.dart';
import 'kademlia_routing_table.dart';

/// Kademlia DHT client implementation for IPFS.
///
/// Implements the [IPFS Kademlia DHT specification](https://github.com/libp2p/specs/tree/master/kad-dht)
/// for distributed peer discovery and content routing.
///
/// **Core Operations:**
/// - [findProviders]: Locate peers providing content
/// - [findPeer]: Discover peer addresses
/// - [addProvider]: Announce content availability
/// - [storeValue]: Store a value in the DHT
/// - [getValue]: Retrieve a value from the DHT
///
/// Example:
/// ```dart
/// final dht = DHTClient(networkHandler: handler, router: router);
/// await dht.initialize();
///
/// // Find providers for a CID
/// final providers = await dht.findProviders(cid);
/// ```
class DHTClient {
  /// Creates a new DHT client.
  DHTClient({
    required this.networkHandler,
    required RouterInterface router,
    MetricsCollector? metricsCollector,
  }) : _router = router,
       _metrics = metricsCollector,
       _logger = Logger('DHTClient');

  /// The IPFS node this client belongs to.
  IPFSNode get node => networkHandler.ipfsNode;

  /// Handler for network operations.
  final NetworkHandler networkHandler;

  final RouterInterface _router;
  final MetricsCollector? _metrics;
  final Logger _logger;

  /// The local peer ID.
  late final PeerId peerId;

  /// The associated peer ID.
  late final PeerId associatedPeerId;

  late final KademliaRoutingTable _kademliaRoutingTable;
  late final DHTConfig _config;
  bool _initialized = false;
  final Set<String> _bootstrappedPeers = {};
  StreamSubscription<ConnectionEvent>? _connectionEventSub;

  final Map<String, Completer<Uint8List>> _pendingRequests = {};
  final Random _random = Random.secure();
  int _requestCounter = 0;

  /// Protocol identifier for Kademlia DHT (WAN).
  static const String protocolDht = '/ipfs/kad/1.0.0';

  /// Protocol identifier for LAN Kademlia DHT (used by private networks).
  static const String protocolDhtLan = '/ipfs/lan/kad/1.0.0';

  /// Initializes the DHT client.
  Future<void> initialize() async {
    if (_initialized) return;

    _config = networkHandler.config.dht;

    // Start the router if it hasn't been started
    await _router.initialize();
    await _router.start();

    if (_router.peerID.isEmpty) {
      throw StateError('Router peer ID not available to initialize DHT client');
    }

    peerId = PeerId.fromBase58(_router.peerID);
    associatedPeerId = peerId;

    _kademliaRoutingTable = KademliaRoutingTable();
    _kademliaRoutingTable.initialize(this);

    // Expose the routing table via the router interface for DHT protocol handlers
    final routingAdapter = KademliaRoutingAdapter(_kademliaRoutingTable);
    if (_router is Libp2pRouter) {
      (_router).setDHTRoutingTable(routingAdapter);
    }

    // Register protocols and handlers
    _registerProtocols();
    _setupHandlers();

    // Bootstrap newly-connected peers so that small/private networks converge
    // even without explicit bootstrap peer lists.
    _connectionEventSub = _router.connectionEvents.listen((event) {
      if (event.type == ConnectionEventType.connected) {
        unawaited(_bootstrapConnectedPeer(event.peerId));
      }
    });

    _initialized = true;
  }

  void _registerProtocols() {
    // Add protocol registration logic here
    _router.registerProtocol(protocolDht);
    _router.registerProtocol(protocolDhtLan);
  }

  void _setupHandlers() {
    // Register handlers for each protocol
    _router.registerProtocolHandler(protocolDht, _handlePacket);
    _router.registerProtocolHandler(protocolDhtLan, _handlePacket);
  }

  // Helper: Convert kad.Peer to PeerId
  PeerId _convertKadPeerToPeerId(kad.Peer kadPeer) {
    return PeerId(value: Uint8List.fromList(kadPeer.id));
  }

  // Helper: Convert PeerId to kad.Peer with proper multiaddr byte encoding.
  kad.Peer _convertPeerIdToKadPeer(PeerId peerId) {
    var addresses = <String>[];
    try {
      addresses = _router.resolvePeerId(peerId.toBase58());
    } catch (_) {
      // Ignore if peer not found
    }
    return kad.Peer()
      ..id = peerId.value
      ..addrs.addAll(
        addresses
            .where(_isValidMultiaddr)
            .map((a) => libp2p.MultiAddr(a).toBytes()),
      );
  }

  /// Returns true if [addr] is a parseable multiaddr string.
  bool _isValidMultiaddr(String addr) {
    try {
      libp2p.MultiAddr(addr);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validates a provider [Peer] entry from the wire.
  ///
  /// Enforces the checks required by the DHT integration spec:
  /// - non-empty peer ID
  /// - at least one parseable multiaddr
  bool _isValidProviderRecord(kad.Peer provider) {
    if (!_config.validateProviderRecords) return true;
    if (provider.id.isEmpty) return false;
    if (provider.addrs.isEmpty) return false;
    return provider.addrs.any((addr) {
      try {
        libp2p.MultiAddr.fromBytes(Uint8List.fromList(addr));
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  // Helper: Get Routing Key (SHA-256 of Multihash)
  /// Computes the routing key for a CID string.
  PeerId getRoutingKey(String cidStr) {
    Uint8List hashBytes;
    try {
      final cid = CID.decode(cidStr);
      // The Kademlia key for a CID is the SHA-256 hash of its Multihash bytes
      final multihashBytes = cid.multihash.toBytes();
      hashBytes = Uint8List.fromList(sha256.convert(multihashBytes).bytes);
    } catch (e) {
      // Fallback for non-CID keys (e.g. raw strings) - use SHA-256 of UTF8
      hashBytes = Uint8List.fromList(sha256.convert(utf8.encode(cidStr)).bytes);
    }

    return PeerId(value: hashBytes);
  }

  // Content Routing API: Find Providers (GET_PROVIDERS)
  /// Finds providers for a CID in the DHT using iterative Kademlia expansion.
  ///
  /// This method queries the closest peers to the CID and returns a list of
  /// validated [PeerId]s.
  Future<List<PeerId>> findProviders(String cid) async {
    _checkInitialized();
    if (_kademliaRoutingTable.peerCount == 0) {
      await _seedConnectedPeers();
    }

    // Fast path: if a provider record was already announced to us locally,
    // return it immediately. This covers the interop case where Kubo/Helia
    // send ADD_PROVIDER messages and we need to report them without relying on
    // a full iterative query over the wire.
    var localProviders = node.dhtHandler?.getLocalProvidersForCid(cid);
    // ignore: avoid_print
    print('findProviders($cid) local=${localProviders?.length ?? -1}');
    if (localProviders != null && localProviders.isNotEmpty) {
      return localProviders;
    }

    // In small/private networks a peer may have just announced itself as a
    // provider but the ADD_PROVIDER hasn't been processed yet. Poll briefly
    // for a local record before falling back to network queries.
    if (_router.connectedPeers.isNotEmpty) {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        localProviders = node.dhtHandler?.getLocalProvidersForCid(cid);
        if (localProviders != null && localProviders.isNotEmpty) {
          // ignore: avoid_print
          print(
            'findProviders($cid) local after poll=${localProviders.length}',
          );
          return localProviders;
        }
      }
    }

    // Fallback for small/private networks: ask directly connected peers for
    // providers. Kubo/Helia may not have propagated the record through a full
    // iterative lookup yet, but they can answer a direct GET_PROVIDERS query.
    final directProviders = await _queryConnectedPeersForProviders(cid);
    if (directProviders.isNotEmpty) {
      return directProviders;
    }

    final target = getRoutingKey(cid);
    final alpha = _config.alpha;
    final k = _config.bucketSize;
    final maxQueries = k * 2;

    final request = kad.Message()
      ..type = kad.Message_MessageType.GET_PROVIDERS
      // The key sent on wire is the raw Multihash bytes for GET_PROVIDERS
      ..key = CID.decode(cid).multihash.toBytes()
      ..clusterLevelRaw = 0;

    final queried = <PeerId>{};
    final providers = <PeerId>{};
    final closest = _SortedPeerQueue(target, _kademliaRoutingTable);

    // Seed from routing table.
    closest.addAll(_kademliaRoutingTable.findClosestPeers(target, k));

    while (closest.isNotEmpty && queried.length < maxQueries) {
      final batch = closest.takeUnqueried(alpha, queried);
      if (batch.isEmpty) break;

      final responses = await Future.wait(
        batch.map((peer) => _queryPeer(peer, request)),
      );

      for (var i = 0; i < batch.length; i++) {
        final peer = batch[i];
        final response = responses[i];
        queried.add(peer);

        if (response == null) continue;

        for (final provider in response.providerPeers) {
          if (_isValidProviderRecord(provider)) {
            providers.add(_convertKadPeerToPeerId(provider));
          } else {
            _metrics?.recordSecurityEvent('invalid_provider_record');
            _logger.debug(
              'Dropping invalid provider record from ${peer.toBase58()}',
            );
          }
        }

        for (final closer in response.closerPeers) {
          if (closer.id.isEmpty) continue;
          closest.add(_convertKadPeerToPeerId(closer));
        }
      }
    }

    return providers.toList();
  }

  /// Finds a peer by its ID in the DHT using iterative Kademlia expansion.
  ///
  /// Returns the [PeerId] if the peer is found in the routing path, or
  /// null if the lookup cannot locate it.
  Future<PeerId?> findPeer(PeerId id) async {
    _checkInitialized();
    final target = id;
    final alpha = _config.alpha;
    final k = _config.bucketSize;
    final maxQueries = k * 2;

    // If we already know the target, return immediately.
    if (_kademliaRoutingTable.containsPeer(target)) {
      return id;
    }

    final request = kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = id.value;

    final queried = <PeerId>{};
    final closest = _SortedPeerQueue(target, _kademliaRoutingTable);
    closest.addAll(_kademliaRoutingTable.findClosestPeers(target, k));

    while (closest.isNotEmpty && queried.length < maxQueries) {
      final batch = closest.takeUnqueried(alpha, queried);
      if (batch.isEmpty) break;

      final responses = await Future.wait(
        batch.map((peer) => _queryPeer(peer, request)),
      );

      for (var i = 0; i < batch.length; i++) {
        final peer = batch[i];
        final response = responses[i];
        queried.add(peer);

        if (response == null) continue;

        for (final closer in response.closerPeers) {
          final closerPeerId = _convertKadPeerToPeerId(closer);
          if (listsEqual(closerPeerId.value, id.value)) {
            return id;
          }
          if (closer.id.isNotEmpty) {
            closest.add(closerPeerId);
          }
        }
      }
    }

    return null;
  }

  /// Adds a provider (ADD_PROVIDER) to the DHT for a given [cid].
  ///
  /// [cid] is the content identifier and [providerId] is the peer ID of the
  /// provider. The request is sent to the XOR-closest peers in batches of
  /// [alpha] for concurrency.
  Future<void> addProvider(String cid, String providerId) async {
    _checkInitialized();
    if (_kademliaRoutingTable.peerCount == 0) {
      await _seedConnectedPeers();
    }
    final target = getRoutingKey(cid);
    final alpha = _config.alpha;
    final k = _config.bucketSize;

    final msg = kad.Message()
      ..type = kad.Message_MessageType.ADD_PROVIDER
      ..key = CID.decode(cid).multihash.toBytes()
      ..providerPeers.add(
        _convertPeerIdToKadPeer(PeerId.fromBase58(providerId)),
      );

    final closestPeers = _kademliaRoutingTable.findClosestPeers(target, k);
    // Sort by XOR distance to the target so closest peers are contacted first.
    closestPeers.sort(
      (a, b) => _kademliaRoutingTable
          .calculateDistance(target, a)
          .compareTo(_kademliaRoutingTable.calculateDistance(target, b)),
    );

    var successCount = 0;
    for (var i = 0; i < closestPeers.length; i += alpha) {
      final batch = closestPeers.sublist(
        i,
        min(i + alpha, closestPeers.length),
      );
      final results = await Future.wait(
        batch.map((peer) => _sendAddProvider(peer, msg)),
      );
      successCount += results.where((success) => success).length;
    }

    _metrics?.recordDhtProvide(successCount > 0);
  }

  /// Announces a batch of [cids] as provided by [providerId] to the DHT.
  ///
  /// Computes the closest peers for each CID, groups CIDs by target peer, and
  /// sends [ADD_PROVIDER] messages for the batch. Concurrency is limited by
  /// [DHTConfig.reproviderConcurrency] when available, otherwise by [alpha].
  Future<void> addProviders(List<CID> cids, String providerId) async {
    _checkInitialized();
    if (cids.isEmpty) return;

    final k = _config.bucketSize;
    final concurrency = _config.reproviderConcurrency > 0
        ? _config.reproviderConcurrency
        : _config.alpha;

    final providerPeer = _convertPeerIdToKadPeer(PeerId.fromBase58(providerId));

    // Map target peer -> list of CIDs to announce.
    final peerCids = <PeerId, List<CID>>{};

    for (final cid in cids) {
      final target = getRoutingKey(cid.toString());
      final closest = _kademliaRoutingTable.findClosestPeers(target, k);
      closest.sort(
        (a, b) => _kademliaRoutingTable
            .calculateDistance(target, a)
            .compareTo(_kademliaRoutingTable.calculateDistance(target, b)),
      );
      for (final peer in closest) {
        peerCids.putIfAbsent(peer, () => []).add(cid);
      }
    }

    if (peerCids.isEmpty) {
      _logger.debug('No peers available to announce ${cids.length} CIDs');
      return;
    }

    final pending = <Future<bool>>[];
    var successCount = 0;
    var attemptedCount = 0;

    for (final entry in peerCids.entries) {
      final peer = entry.key;
      final peerCidList = entry.value;

      for (final cid in peerCidList) {
        attemptedCount++;
        final msg = kad.Message()
          ..type = kad.Message_MessageType.ADD_PROVIDER
          ..key = cid.multihash.toBytes()
          ..providerPeers.add(providerPeer);

        final future = _sendAddProvider(peer, msg);
        pending.add(future);

        if (pending.length >= concurrency) {
          final results = await Future.wait(pending);
          successCount += results.where((success) => success).length;
          pending.clear();
        }
      }
    }

    if (pending.isNotEmpty) {
      final results = await Future.wait(pending);
      successCount += results.where((success) => success).length;
    }

    _metrics?.recordDhtProvide(successCount > 0);
    _logger.debug(
      'addProviders completed: $successCount/$attemptedCount succeeded',
    );
  }

  Future<bool> _sendAddProvider(PeerId peer, kad.Message msg) async {
    try {
      // ADD_PROVIDER is a fire-and-forget message in libp2p-kad-dht. Send the
      // raw protobuf without our envelope framing so Kubo/Helia can parse it.
      final p2plibRouter = node.dhtHandler?.router;
      if (p2plibRouter == null) return false;
      await p2plibRouter.sendMessage(
        peer.toBase58(),
        msg.writeToBuffer(),
        protocolId: protocolDht,
      );
      return true;
    } catch (e) {
      _logger.debug(
        'Error adding provider to peer ${Base58().encode(peer.value)}: $e',
      );
      return false;
    }
  }

  /// Stores a value in the DHT (PUT_VALUE)
  ///
  /// Sends the value to the K closest peers to the key, batched by alpha.
  /// Returns true if at least one peer successfully stored the value.
  Future<bool> storeValue(Uint8List key, Uint8List value) async {
    _checkInitialized();
    final target = getRoutingKey(Base58().encode(key));
    final alpha = _config.alpha;
    final k = _config.bucketSize;

    final closestPeers = _kademliaRoutingTable.findClosestPeers(target, k);
    closestPeers.sort(
      (a, b) => _kademliaRoutingTable
          .calculateDistance(target, a)
          .compareTo(_kademliaRoutingTable.calculateDistance(target, b)),
    );

    final record = dht_proto.Record()
      ..key = key
      ..value = value;
    final msg = kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = record;
    final msgBytes = msg.writeToBuffer();

    var successCount = 0;
    for (var i = 0; i < closestPeers.length; i += alpha) {
      final batch = closestPeers.sublist(
        i,
        min(i + alpha, closestPeers.length),
      );
      final results = await Future.wait(
        batch.map((peer) => _sendStoreValue(peer, msgBytes)),
      );
      successCount += results.where((success) => success).length;
    }

    return successCount > 0;
  }

  Future<bool> _sendStoreValue(PeerId peer, Uint8List msgBytes) async {
    try {
      await _sendRequest(peer, protocolDht, msgBytes);
      return true;
    } catch (e) {
      _logger.debug(
        'Error storing value with peer ${Base58().encode(peer.value)}: $e',
      );
      return false;
    }
  }

  /// Stores a value directly on a specific [peer].
  Future<bool> storeValueToPeer(
    PeerId peer,
    Uint8List key,
    Uint8List value,
  ) async {
    _checkInitialized();
    final record = dht_proto.Record()
      ..key = key
      ..value = value;

    final msg = kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = record;

    try {
      await _sendRequest(peer, protocolDht, msg.writeToBuffer());
      return true;
    } catch (e) {
      _logger.debug(
        'Error storing value with peer ${Base58().encode(peer.value)}: $e',
      );
      return false;
    }
  }

  /// Retrieves a value from the DHT (GET_VALUE)
  ///
  /// Queries the K closest peers to the [key] iteratively and returns the
  /// first value found.
  Future<Uint8List?> getValue(Uint8List key) async {
    _checkInitialized();
    final target = getRoutingKey(Base58().encode(key));
    final alpha = _config.alpha;
    final k = _config.bucketSize;
    final maxQueries = k * 2;

    final request = kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;

    final queried = <PeerId>{};
    final closest = _SortedPeerQueue(target, _kademliaRoutingTable);
    closest.addAll(_kademliaRoutingTable.findClosestPeers(target, k));

    while (closest.isNotEmpty && queried.length < maxQueries) {
      final batch = closest.takeUnqueried(alpha, queried);
      if (batch.isEmpty) break;

      final responses = await Future.wait(
        batch.map((peer) => _queryPeer(peer, request)),
      );

      for (var i = 0; i < batch.length; i++) {
        final peer = batch[i];
        final response = responses[i];
        queried.add(peer);

        if (response == null) continue;

        if (response.hasRecord() && response.record.value.isNotEmpty) {
          return Uint8List.fromList(response.record.value);
        }

        for (final closer in response.closerPeers) {
          if (closer.id.isEmpty) continue;
          closest.add(_convertKadPeerToPeerId(closer));
        }
      }
    }

    return null;
  }

  /// Stores a raw DHT value on connected peers using unframed Kademlia
  /// messages. This is required for interop with Kubo/Helia, which do not
  /// understand the internal DHTEnvelope framing.
  Future<bool> storeValueRaw(Uint8List key, Uint8List value) async {
    _checkInitialized();
    final router = node.dhtHandler?.router;
    if (router == null) return false;

    final record = dht_proto.Record()
      ..key = key
      ..value = value;
    final msg = kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = record;
    final msgBytes = msg.writeToBuffer();

    var successCount = 0;
    for (final peerIdStr in router.connectedPeers) {
      try {
        await router.sendMessage(peerIdStr, msgBytes, protocolId: protocolDht);
        successCount++;
      } catch (e) {
        _logger.debug('Raw PUT_VALUE to $peerIdStr failed: $e');
      }
    }
    return successCount > 0;
  }

  /// Retrieves a raw DHT value from connected peers using unframed Kademlia
  /// messages. Returns the first value found.
  Future<Uint8List?> getValueRaw(Uint8List key) async {
    _checkInitialized();
    final router = node.dhtHandler?.router;
    if (router == null) return null;

    final request = kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;
    final requestBytes = request.writeToBuffer();

    for (final peerIdStr in router.connectedPeers) {
      try {
        final responseBytes = await router.sendRequest(
          peerIdStr,
          protocolDht,
          requestBytes,
        );
        if (responseBytes == null) continue;
        final response = kad.Message.fromBuffer(responseBytes);
        if (response.hasRecord() && response.record.value.isNotEmpty) {
          return Uint8List.fromList(response.record.value);
        }
      } catch (e) {
        _logger.debug('Raw GET_VALUE from $peerIdStr failed: $e');
      }
    }
    return null;
  }

  /// Checks if a value exists on a specific peer.
  ///
  /// Used for replica health checks.
  Future<bool> checkValueOnPeer(PeerId peer, Uint8List key) async {
    _checkInitialized();
    final msg = kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;

    try {
      final responseBytes = await _sendRequest(
        peer,
        protocolDht,
        msg.writeToBuffer(),
      );
      final response = kad.Message.fromBuffer(responseBytes);
      return response.hasRecord() && response.record.value.isNotEmpty;
    } catch (e) {
      _logger.debug(
        'Error checking value on peer ${Base58().encode(peer.value)}: $e',
      );
      return false;
    }
  }

  /// Sends a single DHT query to [peer] and returns the parsed response.
  Future<kad.Message?> _queryPeer(PeerId peer, kad.Message request) async {
    try {
      final requestBytes = request.writeToBuffer();
      final stopwatch = Stopwatch()..start();
      final responseBytes = await _sendRequest(peer, protocolDht, requestBytes);
      stopwatch.stop();
      _metrics?.recordLatency(protocolDht, stopwatch.elapsed);
      _metrics?.recordMessageSent(protocolDht, requestBytes.length);
      _metrics?.recordMessageReceived(protocolDht, responseBytes.length);
      return kad.Message.fromBuffer(responseBytes);
    } catch (e) {
      _logger.debug('DHT query to ${peer.toBase58()} failed: $e');
      return null;
    }
  }

  /// Directly queries all connected peers for providers of [cid].
  ///
  /// This bypasses iterative Kademlia expansion and is used as a fast path in
  /// small/private networks where we are directly connected to a provider.
  Future<List<PeerId>> _queryConnectedPeersForProviders(String cid) async {
    final providers = <PeerId>{};
    final request = kad.Message()
      ..type = kad.Message_MessageType.GET_PROVIDERS
      ..key = CID.decode(cid).multihash.toBytes()
      ..clusterLevelRaw = 0;
    final requestBytes = request.writeToBuffer();

    final router = node.dhtHandler?.router;
    if (router == null) {
      // ignore: avoid_print
      print('_queryConnectedPeersForProviders: no router');
      return [];
    }
    // ignore: avoid_print
    print(
      '_queryConnectedPeersForProviders: connected=${router.connectedPeers.length}',
    );

    for (final peerIdStr in router.connectedPeers) {
      // ignore: avoid_print
      print('  querying $peerIdStr');
      try {
        // In private networks Kubo/Helia use the LAN DHT protocol; try it
        // first, then fall back to the WAN protocol.
        Uint8List? responseBytes;
        for (final proto in [protocolDhtLan, protocolDht]) {
          responseBytes = await router.sendRequest(
            peerIdStr,
            proto,
            requestBytes,
          );
          if (responseBytes != null) break;
        }
        // ignore: avoid_print
        print(
          '  response from $peerIdStr: ${responseBytes?.length ?? -1} bytes',
        );
        if (responseBytes == null) continue;
        final response = kad.Message.fromBuffer(responseBytes);
        for (final provider in response.providerPeers) {
          if (_isValidProviderRecord(provider)) {
            providers.add(_convertKadPeerToPeerId(provider));
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('  query $peerIdStr failed: $e');
        _logger.debug('Direct provider query to $peerIdStr failed: $e');
      }
    }

    // ignore: avoid_print
    print('_queryConnectedPeersForProviders result: ${providers.length}');
    return providers.toList();
  }

  // Helper method for sending protocol requests with correlation.
  /// Sends a raw DHT message payload to [peer] over the kad protocol.
  ///
  /// Used by collaborators (e.g. [OptimisticProvider]) that compose their own
  /// kad [kad.Message] bytes and only need the transport dispatch.
  Future<void> sendMessageRaw(PeerId peer, Uint8List msgBytes) =>
      _sendRequest(peer, protocolDht, msgBytes);

  Future<Uint8List> _sendRequest(
    PeerId peer,
    String protocol,
    Uint8List data,
  ) async {
    final requestId = _generateRequestId();
    final completer = Completer<Uint8List>();
    _pendingRequests[requestId] = completer;

    final p2plibRouter = node.dhtHandler?.router;
    if (p2plibRouter == null) {
      _pendingRequests.remove(requestId);
      throw Exception('DHT Offline: Router not available');
    }

    final envelope = DHTEnvelope(requestId: requestId, payload: data);
    try {
      await p2plibRouter.sendMessage(
        peer.toBase58(),
        envelope.toBytes(),
        protocolId: protocol,
      );
    } catch (e) {
      _pendingRequests.remove(requestId);
      _logger.debug('Error sending DHT request to ${peer.toBase58()}: $e');
      rethrow;
    }

    return completer.future.timeout(_config.requestTimeout);
  }

  String _generateRequestId() {
    _requestCounter++;
    return 'dht-${DateTime.now().microsecondsSinceEpoch}-$_requestCounter-${_random.nextInt(0x7FFFFFFF)}';
  }

  // Main Handle Packet
  void _handlePacket(NetworkPacket packet) async {
    // ignore: avoid_print
    print(
      'DHT packet from ${packet.srcPeerId}, ${packet.datagram.length} bytes',
    );
    try {
      late final kad.Message message;
      late final DHTEnvelope envelope;
      // Kubo and other libp2p-kad-dht implementations send raw protobuf
      // messages without an envelope. Our internal transport uses a thin
      // DHTEnvelope for correlation. Try raw first; if it fails, fall back
      // to envelope parsing.
      try {
        message = kad.Message.fromBuffer(packet.datagram);
        envelope = DHTEnvelope(requestId: '', payload: packet.datagram);
        // ignore: avoid_print
        print(
          'DHT raw parsed: type=${message.type}, key=${message.key.length} bytes',
        );
      } catch (_) {
        try {
          envelope = DHTEnvelope.fromBytes(packet.datagram);
        } on FormatException {
          envelope = DHTEnvelope(
            requestId: '',
            payload: Uint8List.fromList(packet.datagram),
          );
        }
        message = kad.Message.fromBuffer(envelope.payload);
      }

      // If this is a correlated response, complete the pending request.
      if (envelope.requestId.isNotEmpty) {
        final completer = _pendingRequests.remove(envelope.requestId);
        if (completer != null) {
          completer.complete(Uint8List.fromList(envelope.payload));
          return;
        }
      }

      final peerIdStr = packet.srcPeerId;
      final srcPeerId = PeerId.fromBase58(peerIdStr);

      // SEC-005: Verify PoW for DHT Sybil protection
      final difficulty = networkHandler.config.security.dhtDifficulty;
      if (difficulty > 0 && !srcPeerId.verifyPoW(difficulty: difficulty)) {
        _logger.warning(
          'Rejecting DHT message from $peerIdStr: Insufficient PoW',
        );
        _metrics?.recordSecurityEvent('dht_pow_reject');
        return;
      }

      // Update routing table with IP diversity check
      if (_initialized) {
        await _kademliaRoutingTable.addPeer(srcPeerId, srcPeerId);
      } else {
        return;
      }

      switch (message.type) {
        case kad.Message_MessageType.FIND_NODE:
          if (!_initialized) break;
          // Reply with closer peers
          final closer = _kademliaRoutingTable.findClosestPeers(
            PeerId(value: Uint8List.fromList(message.key)),
            20,
          );
          final response = kad.Message()
            ..type = kad.Message_MessageType.FIND_NODE
            ..closerPeers.addAll(closer.map((p) => _convertPeerIdToKadPeer(p)));
          _sendResponse(
            peerIdStr,
            envelope.requestId,
            response,
            packet.responder,
          );
          break;
        case kad.Message_MessageType.GET_VALUE:
          // Check local storage for record
          await _handleGetValue(
            peerIdStr,
            envelope.requestId,
            message,
            packet.responder,
          );
          break;
        case kad.Message_MessageType.PUT_VALUE:
          await _handlePutValue(
            peerIdStr,
            envelope.requestId,
            message,
            packet.responder,
          );
          break;
        case kad.Message_MessageType.GET_PROVIDERS:
          await _handleGetProviders(
            peerIdStr,
            envelope.requestId,
            message,
            packet.responder,
          );
          break;
        case kad.Message_MessageType.ADD_PROVIDER:
          await _handleAddProvider(peerIdStr, message);
          break;
        case kad.Message_MessageType.PING:
          final response = kad.Message()..type = kad.Message_MessageType.PING;
          _sendResponse(
            peerIdStr,
            envelope.requestId,
            response,
            packet.responder,
          );
          break;
        default:
          // ignore: avoid_print
          print('Unhandled DHT message type: ${message.type}');
          _logger.debug('Unhandled DHT message type: ${message.type}');
      }
    } catch (e, st) {
      _logger.error('Error handling DHT packet', e, st);
    }
  }

  Future<void> _handleGetValue(
    String peerIdStr,
    String requestId,
    kad.Message message,
    Future<void> Function(Uint8List)? send,
  ) async {
    final storage = node.dhtHandler?.storage;
    if (storage == null) {
      _sendResponse(
        peerIdStr,
        requestId,
        kad.Message()..type = message.type,
        send,
      );
      return;
    }

    try {
      final key = ds.Key(
        '/dht/values/${Base58().encode(Uint8List.fromList(message.key))}',
      );
      final data = await storage.get(key);
      final response = kad.Message()
        ..type = message.type
        ..key = message.key;
      // ignore: avoid_print
      print(
        'DHT GET_VALUE from $peerIdStr key=${message.key.length} found=${data != null && data.isNotEmpty}',
      );
      if (data != null && data.isNotEmpty) {
        response.record = dht_proto.Record()
          ..key = message.key
          ..value = data;
      } else {
        // Return closer peers as a fallback
        final closer = _kademliaRoutingTable.findClosestPeers(
          PeerId(value: Uint8List.fromList(message.key)),
          20,
        );
        response.closerPeers.addAll(
          closer.map((p) => _convertPeerIdToKadPeer(p)),
        );
      }
      _sendResponse(peerIdStr, requestId, response, send);
    } catch (e) {
      _logger.debug('Error handling GET_VALUE from $peerIdStr: $e');
      _sendResponse(
        peerIdStr,
        requestId,
        kad.Message()..type = message.type,
        send,
      );
    }
  }

  Future<void> _handleGetProviders(
    String peerIdStr,
    String requestId,
    kad.Message message,
    Future<void> Function(Uint8List)? send,
  ) async {
    final handler = node.dhtHandler;
    final response = kad.Message()
      ..type = message.type
      ..key = message.key;

    if (handler != null) {
      try {
        final cidStr = Base58().encode(Uint8List.fromList(message.key));
        final providers = await handler.findProviders(CID.decode(cidStr));
        for (final peerInfo in providers) {
          response.providerPeers.add(
            kad.Peer()..id = Uint8List.fromList(peerInfo.peerId),
          );
        }
      } catch (e) {
        _logger.debug('Error handling GET_PROVIDERS from $peerIdStr: $e');
      }
    }

    // Always include closer peers for iterative expansion.
    final closer = _kademliaRoutingTable.findClosestPeers(
      PeerId(value: Uint8List.fromList(message.key)),
      20,
    );
    response.closerPeers.addAll(closer.map((p) => _convertPeerIdToKadPeer(p)));

    _sendResponse(peerIdStr, requestId, response, send);
  }

  Future<void> _handleAddProvider(String peerIdStr, kad.Message message) async {
    final handler = node.dhtHandler;
    if (handler == null) return;

    try {
      final cidStr = Base58().encode(Uint8List.fromList(message.key));
      // ignore: avoid_print
      print(
        'ADD_PROVIDER from $peerIdStr for $cidStr, ${message.providerPeers.length} peers',
      );
      final cid = CID.decode(cidStr);
      for (final provider in message.providerPeers) {
        final providerId = _convertKadPeerToPeerId(provider);
        // ignore: avoid_print
        print(
          '  provider ${providerId.toBase58()}, addrs=${provider.addrs.length}',
        );
        if (_isValidProviderRecord(provider)) {
          await handler.handleProvideRequest(cid, providerId);
          // ignore: avoid_print
          print('  stored provider for $cidStr');
        } else {
          _metrics?.recordSecurityEvent('invalid_provider_record');
          // ignore: avoid_print
          print('  rejected invalid ADD_PROVIDER from $peerIdStr for $cidStr');
          _logger.debug(
            'Rejected invalid ADD_PROVIDER from $peerIdStr for $cidStr',
          );
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error handling ADD_PROVIDER from $peerIdStr: $e');
      _logger.debug('Error handling ADD_PROVIDER from $peerIdStr: $e');
    }
  }

  Future<void> _handlePutValue(
    String peerIdStr,
    String requestId,
    kad.Message message,
    Future<void> Function(Uint8List)? send,
  ) async {
    final storage = node.dhtHandler?.storage;
    if (storage == null) return;

    try {
      if (message.hasRecord()) {
        final key = ds.Key(
          '/dht/values/${Base58().encode(Uint8List.fromList(message.key))}',
        );
        await storage.put(key, Uint8List.fromList(message.record.value));
        _logger.debug(
          'Stored DHT value for key ${Base58().encode(Uint8List.fromList(message.key))}',
        );
      }

      final response = kad.Message()
        ..type = message.type
        ..key = message.key;
      if (message.hasRecord()) {
        response.record = dht_proto.Record()
          ..key = message.key
          ..value = message.record.value;
      }
      _sendResponse(peerIdStr, requestId, response, send);
    } catch (e) {
      _logger.debug('Error handling PUT_VALUE from $peerIdStr: $e');
    }
  }

  void _sendResponse(
    String peerIdStr,
    String requestId,
    kad.Message msg,
    Future<void> Function(Uint8List)? send,
  ) {
    final payload = msg.writeToBuffer();
    final Uint8List bytesToSend;
    if (requestId.isEmpty) {
      // Interop with Kubo: raw Kademlia messages, no envelope.
      bytesToSend = payload;
    } else {
      bytesToSend = DHTEnvelope(
        requestId: requestId,
        payload: payload,
      ).toBytes();
    }
    if (send != null) {
      unawaited(send(bytesToSend));
    } else {
      node.dhtHandler?.router.sendMessage(peerIdStr, bytesToSend);
    }
  }

  /// Starts the DHT client and initializes necessary components.
  Future<void> start() async {
    try {
      // Ensure client is initialized before starting
      await initialize();

      // Router should already be initialized by IPFSNode
      await _router.start();

      // Register protocol handlers
      node.dhtHandler?.router.registerProtocol(protocolDht);

      // Initialize routing table
      await _initializeRoutingTable();

      _logger.info('DHT client started successfully (Standard Kademlia)');
    } catch (e, st) {
      _logger.error('Error starting DHT client', e, st);
      rethrow;
    }
  }

  /// Stops the DHT client and cleans up resources.
  Future<void> stop() async {
    try {
      // Clean up any active requests or connections
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('DHT client stopped'));
        }
      }
      _pendingRequests.clear();

      // Clear routing table
      if (_initialized) {
        _kademliaRoutingTable.clear();
      }
      _initialized = false;
      _bootstrappedPeers.clear();
      await _connectionEventSub?.cancel();
      _connectionEventSub = null;

      _logger.info('DHT client stopped successfully');
    } catch (e, st) {
      _logger.error('Error stopping DHT client', e, st);
      rethrow;
    }
  }

  /// Bootstraps a single connected peer by adding it to the routing table and
  /// sending a self-lookup FIND_NODE so that the peer learns about us.
  Future<void> _bootstrapConnectedPeer(String peerIdStr) async {
    if (!_initialized) return;
    // ignore: avoid_print
    print('DHT bootstrap connected peer $peerIdStr');
    try {
      final peer = PeerId.fromBase58(peerIdStr);
      if (_bootstrappedPeers.add(peerIdStr)) {
        await _kademliaRoutingTable.addPeer(peer, peer);
        await _bootstrapPeer(peer);
      }
    } catch (e) {
      _logger.debug('Error bootstrapping connected peer $peerIdStr: $e');
    }
  }

  /// Initialize the routing table with bootstrap and already-connected peers.
  Future<void> _initializeRoutingTable() async {
    final bootstrapPeers = networkHandler.config.network.bootstrapPeers;
    for (final peerAddr in bootstrapPeers) {
      try {
        final peer = await _connectToPeer(peerAddr);
        if (peer != null) {
          await _kademliaRoutingTable.addPeer(peer, peer);
        }
      } catch (e) {
        _logger.debug('Error connecting to bootstrap peer $peerAddr: $e');
      }
    }

    // In small/private networks there may be no bootstrap list, but the node
    // is already connected to peers via swarmConnect. Seed the routing table
    // with them so that provide/find operations have somewhere to send.
    await _seedConnectedPeers();
  }

  /// Adds currently connected peers to the Kademlia routing table and sends
  /// a self-lookup FIND_NODE to each newly-seeded peer so that they learn about
  /// us (bootstrap) and we learn about their closest peers.
  Future<void> _seedConnectedPeers() async {
    try {
      for (final peerIdStr in _router.connectedPeers) {
        if (!_bootstrappedPeers.add(peerIdStr)) continue;
        try {
          final peer = PeerId.fromBase58(peerIdStr);
          await _kademliaRoutingTable.addPeer(peer, peer);
          unawaited(_bootstrapPeer(peer));
        } catch (e) {
          _logger.debug(
            'Error adding connected peer $peerIdStr to DHT table: $e',
          );
        }
      }
    } catch (e) {
      _logger.debug('Error seeding DHT routing table from connected peers: $e');
    }
  }

  /// Sends a FIND_NODE for our own peer ID to [peer]. This is a minimal
  /// bootstrap interaction: the peer will add us to its routing table on receipt.
  Future<void> _bootstrapPeer(PeerId peer) async {
    // ignore: avoid_print
    print('DHT bootstrap FIND_NODE to ${peer.toBase58()}');
    try {
      final request = kad.Message()
        ..type = kad.Message_MessageType.FIND_NODE
        ..key = peerId.value;
      final p2plibRouter = node.dhtHandler?.router;
      if (p2plibRouter != null) {
        await p2plibRouter.sendMessage(
          peer.toBase58(),
          request.writeToBuffer(),
          protocolId: protocolDht,
        );
      }
    } catch (e) {
      _logger.debug('Error bootstrapping DHT peer ${peer.toBase58()}: $e');
    }
  }

  /// Helper method to connect to a peer given their multiaddr.
  Future<PeerId?> _connectToPeer(String multiaddr) async {
    try {
      // Implementation of peer connection logic
      // This would use the router to establish connection
      return null; // Replace with actual peer connection logic
    } catch (e) {
      _logger.debug('Error connecting to peer $multiaddr: $e');
      return null;
    }
  }

  /// The Kademlia routing table for peer management.
  KademliaRoutingTable get kademliaRoutingTable => _kademliaRoutingTable;

  /// Compares two byte lists for equality.
  bool listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Returns all stored DHT keys.
  Future<List<String>> getAllStoredKeys() async {
    _checkInitialized();
    try {
      // Get all keys from the DHT storage
      final List<String> storedKeys = [];

      // Query the datastore for all DHT keys using query
      final query = ds.Query(prefix: '/dht/values/', keysOnly: true);
      // Use nullable handler access and default to empty stream
      final stream =
          node.dhtHandler?.storage.query(query) ?? const Stream.empty();
      await for (final entry in stream) {
        final key = entry.key.toString();
        // Remove the prefix to get the actual key
        final actualKey = key.substring('/dht/values/'.length);
        storedKeys.add(actualKey);
      }

      // Sort keys for consistent ordering
      storedKeys.sort();

      // Add key metadata to the routing table
      for (var key in storedKeys) {
        try {
          final targetPeerId = PeerId(value: Base58().base58Decode(key));

          // Update routing table with key information
          _kademliaRoutingTable.addKeyProvider(
            targetPeerId,
            peerId,
            DateTime.now(),
          );
        } catch (e) {
          // Continue processing other keys
        }
      }

      return storedKeys;
    } catch (e) {
      return [];
    }
  }

  /// Reprovide sweep hook.
  ///
  /// The detailed reprovide strategy is defined in `REPROVIDE_SPEC.md`. This
  /// method provides the primitive DHT hook that a reprovider can call. It
  /// enumerates locally stored keys and records reprovide metrics.
  Future<void> reprovide() async {
    _checkInitialized();
    _logger.info('Reprovide sweep started');
    final stopwatch = Stopwatch()..start();
    try {
      final keys = await getAllStoredKeys();
      _logger.debug('Reproviding ${keys.length} keys');
      // Actual reprovide strategy is implemented by REPROVIDE_SPEC.md.
      // This method provides the primitive hook and records metrics.
      stopwatch.stop();
      _metrics?.recordReprovide('default', true, stopwatch.elapsed);
      _logger.info('Reprovide sweep completed (${keys.length} keys)');
    } catch (e, st) {
      _logger.error('Reprovide sweep failed', e, st);
      stopwatch.stop();
      _metrics?.recordReprovide('default', false, stopwatch.elapsed);
      rethrow;
    }
  }

  /// Updates the republish timestamp for a key.
  Future<void> updateKeyRepublishTime(String key) async {
    _checkInitialized();
    try {
      // Create metadata key for storing republish time
      final metadataKey = ds.Key('/dht/metadata/$key/last_republish');

      // Store current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final timestampData = Uint8List.fromList(
        utf8.encode(timestamp.toString()),
      );

      // Update the timestamp in DHT storage
      await node.dhtHandler?.storage.put(metadataKey, timestampData);

      // Update routing table metadata
      try {
        final targetPeerId = PeerId.fromBase58(key);

        // Update the key provider timestamp in routing table
        _kademliaRoutingTable.updateKeyProviderTimestamp(
          targetPeerId,
          peerId,
          DateTime.now(),
        );
      } catch (e) {
        // Continue even if routing table update fails
      }

      // Emit key republish event for monitoring
      final event = ipfs_node_network_events.DHTValueProvidedEvent()
        ..key = key
        ..value = utf8.encode(timestamp.toString());

      node.dhtHandler?.router.emitEvent(
        'dht:key:republished',
        event.writeToBuffer(),
      );
    } catch (e) {
      rethrow;
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'DHTClient not initialized. Did you forget to call start() or initialize()?',
      );
    }
  }

  /// The underlying P2P router.
  RouterInterface get router => _router;

  /// Whether the DHT client has been initialized.
  bool get isInitialized => _initialized;
}

/// Sorted queue of peers by XOR distance to a target.
class _SortedPeerQueue {
  _SortedPeerQueue(this.target, this.routingTable);

  final PeerId target;
  final KademliaRoutingTable routingTable;
  final List<PeerId> _peers = [];

  bool get isEmpty => _peers.isEmpty;
  bool get isNotEmpty => _peers.isNotEmpty;

  void add(PeerId peer) {
    if (_peers.contains(peer)) return;
    _peers.add(peer);
    _peers.sort(
      (a, b) => routingTable
          .calculateDistance(target, a)
          .compareTo(routingTable.calculateDistance(target, b)),
    );
  }

  void addAll(Iterable<PeerId> peers) {
    for (final peer in peers) {
      add(peer);
    }
  }

  /// Returns up to [count] peers from the queue that are not in [queried].
  List<PeerId> takeUnqueried(int count, Set<PeerId> queried) {
    final result = <PeerId>[];
    for (final peer in _peers) {
      if (!queried.contains(peer)) {
        result.add(peer);
        if (result.length == count) break;
      }
    }
    return result;
  }
}
