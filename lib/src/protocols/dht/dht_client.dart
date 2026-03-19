// src/protocols/dht/dht_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart'; // For SHA256
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_proto;
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart'
    as ipfs_node_network_events;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';

/// Kademlia DHT client implementation for IPFS.
///
/// Implements the [IPFS Kademlia DHT specification](https://github.com/libp2p/specs/tree/master/kad-dht)
/// for distributed peer discovery and content routing.
///
/// **Core Operations:**
/// - [findProviders]: Locate peers providing content
/// - [findPeer]: Discover peer addresses
/// - [addProvider]: Announce content availability
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
  DHTClient({required this.networkHandler, required RouterInterface router})
    : _router = router;

  /// The IPFS node this client belongs to.
  IPFSNode get node => networkHandler.ipfsNode;

  /// Handler for network operations.
  final NetworkHandler networkHandler;

  final RouterInterface _router;

  /// The local peer ID.
  late final PeerId peerId;

  /// The associated peer ID.
  late final PeerId associatedPeerId;

  late final KademliaRoutingTable _kademliaRoutingTable;
  bool _initialized = false;

  /// Protocol identifier for Kademlia DHT.
  static const String protocolDht = '/ipfs/kad/1.0.0';

  /// Initializes the DHT client.
  Future<void> initialize() async {
    if (_initialized) return;

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

    // Register protocols and handlers
    _registerProtocols();
    _setupHandlers();

    _initialized = true;
  }

  void _registerProtocols() {
    // Add protocol registration logic here
    _router.registerProtocol(protocolDht);
  }

  void _setupHandlers() {
    // Register handlers for each protocol
    _router.registerProtocolHandler(protocolDht, _handlePacket);
  }

  // Helper: Convert kad.Peer to PeerId
  PeerId _convertKadPeerToPeerId(kad.Peer kadPeer) {
    return PeerId(value: Uint8List.fromList(kadPeer.id));
  }

  // Helper: Convert PeerId to kad.Peer
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
        addresses.map((a) => Uint8List.fromList(utf8.encode(a))),
      ); // Sending string addrs as bytes? Proto expects bytes.
    // Note: Traditionally IPFS sends multiaddr bytes.
    // Since resolvePeer returns List<String>, we have to encode if protocol expects bytes.
    // Let's assume standard IPFS expects multiaddr bytes.
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

    // DHT keys are usually 32 bytes (SHA256).
    // Our new PeerId is just bytes wrapper.
    // If the DHT requires 256-bit keys, we use 32 bytes.
    return PeerId(value: hashBytes);
  }

  // Content Routing API: Find Providers (GET_PROVIDERS)
  /// Finds providers for a CID in the DHT.
  Future<List<PeerId>> findProviders(String cid) async {
    _checkInitialized();
    final msg = kad.Message()
      ..type = kad.Message_MessageType.GET_PROVIDERS
      // The key sent on wire is the raw Multihash bytes for GET_PROVIDERS
      ..key = CID.decode(cid).multihash.toBytes()
      ..clusterLevelRaw = 0;

    // Used for routing in Kademlia table (XOR distance)
    final targetPeerId = getRoutingKey(cid);

    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );
    final providers = <PeerId>[];

    for (final peer in closestPeers) {
      try {
        final responseBytes = await _sendRequest(
          peer,
          protocolDht,
          msg.writeToBuffer(),
        );
        final response = kad.Message.fromBuffer(responseBytes);

        // Extract providers
        for (final provider in response.providerPeers) {
          final peerId = _convertKadPeerToPeerId(provider);

          // Register addresses in router if present (Platform abstract way?)
          // We can't easily parse multiaddr bytes without p2plib on generic platform yet.
          // Skipping detailed address update for now, relying on router to discover.

          providers.add(peerId);
        }
        // Also checks closerPeers for iterative query (not implemented loop here yet)
      } catch (e) {
        // print(
        //   'Error querying peer ${Base58().encode(peer.value)} for providers: $e',
        // );
      }
    }

    return providers;
  }

  /// Finds a peer by its ID in the DHT.
  Future<PeerId?> findPeer(PeerId id) async {
    _checkInitialized();
    final msg = kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = id.value; // PeerId is already the key

    final closestPeers = _kademliaRoutingTable.findClosestPeers(id, 20);

    for (final peer in closestPeers) {
      try {
        final responseBytes = await _sendRequest(
          peer,
          protocolDht,
          msg.writeToBuffer(),
        );
        final response = kad.Message.fromBuffer(responseBytes);

        // Check if target is in closerPeers
        final found = response.closerPeers.any(
          (p) => listsEqual(p.id, id.value),
        );
        if (found) {
          return id;
        }
        // Iterate...
      } catch (e) {
        // print(
        //   'Error querying peer ${Base58().encode(peer.value)} for peer lookup: $e',
        // );
      }
    }
    return null;
  }

  /// Adds a provider (ADD_PROVIDER)
  Future<void> addProvider(String cid, String providerId) async {
    _checkInitialized();
    final msg = kad.Message()
      ..type = kad.Message_MessageType.ADD_PROVIDER
      ..key = CID
          .decode(cid)
          .multihash
          .toBytes() // Raw multihash bytes
      ..providerPeers.add(
        _convertPeerIdToKadPeer(PeerId.fromBase58(providerId)),
      );

    final targetPeerId = getRoutingKey(cid);
    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    for (final peer in closestPeers) {
      try {
        await _sendRequest(peer, protocolDht, msg.writeToBuffer());
      } catch (e) {
        // print(
        //   'Error adding provider to peer ${Base58().encode(peer.value)}: $e',
        // );
      }
    }
  }

  /// Stores a value in the DHT (PUT_VALUE)
  ///
  /// Sends the value to the K closest peers to the key.
  /// Returns true if at least one peer successfully stored the value.
  Future<bool> storeValue(Uint8List key, Uint8List value) async {
    _checkInitialized();
    final targetPeerId = getRoutingKey(Base58().encode(key));
    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    int successCount = 0;
    for (final peer in closestPeers) {
      if (await storeValueToPeer(peer, key, value)) {
        successCount++;
      }
    }

    return successCount > 0;
  }

  /// Stores a value directly on a specific peer.
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
      // print('Error storing value with peer ${Base58().encode(peer.value)}: $e');
      return false;
    }
  }

  /// Retrieves a value from the DHT (GET_VALUE)
  ///
  /// Queries the K closest peers to the key and returns the first value found.
  Future<Uint8List?> getValue(Uint8List key) async {
    _checkInitialized();
    final msg = kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;

    final targetPeerId = getRoutingKey(Base58().encode(key));
    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    for (final peer in closestPeers) {
      try {
        final responseBytes = await _sendRequest(
          peer,
          protocolDht,
          msg.writeToBuffer(),
        );
        final response = kad.Message.fromBuffer(responseBytes);

        if (response.hasRecord() && response.record.value.isNotEmpty) {
          return Uint8List.fromList(response.record.value);
        }
      } catch (e) {
        // print(
        //   'Error getting value from peer ${Base58().encode(peer.value)}: $e',
        // );
      }
    }

    return null;
  }

  /// Checks if a value exists on a specific peer
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
      return false;
    }
  }

  // Helper method for sending protocol requests
  Future<Uint8List> _sendRequest(
    PeerId peer,
    String protocol,
    Uint8List data,
  ) async {
    final completer = Completer<Uint8List>();

    final p2plibRouter = node.dhtHandler?.router;
    if (p2plibRouter == null) {
      throw Exception('DHT Offline: Router not available');
    }

    // Register a one-time message handler for the response
    // Note: this logic is brittle if multiple requests flight to same peer.
    // Ideally we match request IDs.
    // For now we assume the next packet from this peer on this protocol is the response.
    void responseHandler(NetworkPacket packet) {
      if (packet.srcPeerId == peer.toBase58() && !completer.isCompleted) {
        completer.complete(packet.datagram);
      }
    }

    p2plibRouter.registerProtocolHandler(protocol, responseHandler);

    try {
      await p2plibRouter.sendMessage(peer.toBase58(), data);

      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      // p2plibRouter.removeMessageHandler(protocol); // implementation dependent
    }
  }

  // Main Handle Packet
  void _handlePacket(NetworkPacket packet) async {
    try {
      final message = kad.Message.fromBuffer(packet.datagram);
      final peerIdStr = packet.srcPeerId;
      final srcPeerId = PeerId.fromBase58(peerIdStr);

      // SEC-005: Verify PoW for DHT Sybil protection
      final difficulty = networkHandler.config.security.dhtDifficulty;
      if (difficulty > 0 && !srcPeerId.verifyPoW(difficulty: difficulty)) {
        // print('Rejecting DHT message from $peerIdStr: Insufficient PoW');
        return;
      }

      // Update routing table with IP diversity check
      // Ensure we check/init table access even inside handlers?
      // Handlers are setup in initialize(), so technically _kademliaRoutingTable should be ready.
      // But if stop() is called, handlers might still be active briefly.
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
          _sendResponse(peerIdStr, response);
          break;
        case kad.Message_MessageType.GET_VALUE:
          // Check local storage for record
          // For now return empty or closer peers
          break;
        case kad.Message_MessageType.PING:
          final response = kad.Message()..type = kad.Message_MessageType.PING;
          _sendResponse(peerIdStr, response);
          break;
        default:
        // print('Unhandled DHT message type: ${message.type}');
      }
    } catch (e) {
      // print('Error handling DHT packet: $e');
    }
  }

  void _sendResponse(String peerIdStr, kad.Message msg) {
    node.dhtHandler?.router.sendMessage(peerIdStr, msg.writeToBuffer());
  }

  /// Starts the DHT client and initializes necessary components
  Future<void> start() async {
    try {
      // Ensure client is initialized before starting
      await initialize();

      // Router should already be initialized by IPFSNode
      await _router
          .start(); // This will be safe now with the updated RouterInterface

      // Register protocol handlers
      node.dhtHandler?.router.registerProtocol(protocolDht);

      // Initialize routing table
      await _initializeRoutingTable();

      // print('DHT client started successfully (Standard Kademlia)');
    } catch (e) {
      // print('Error starting DHT client: $e');
      rethrow;
    }
  }

  /// Stops the DHT client and cleans up resources
  Future<void> stop() async {
    try {
      // Clean up any active requests or connections
      // Clear routing table
      if (_initialized) {
        _kademliaRoutingTable.clear();
      }
      _initialized = false;

      // print('DHT client stopped successfully');
    } catch (e) {
      // print('Error stopping DHT client: $e');
      rethrow;
    }
  }

  /// Initialize the routing table with bootstrap peers
  Future<void> _initializeRoutingTable() async {
    final bootstrapPeers = networkHandler.config.network.bootstrapPeers;
    for (final peerAddr in bootstrapPeers) {
      try {
        final peer = await _connectToPeer(peerAddr);
        if (peer != null) {
          await _kademliaRoutingTable.addPeer(peer, peer);
        }
      } catch (e) {
        // print('Error connecting to bootstrap peer $peerAddr: $e');
      }
    }
  }

  /// Helper method to connect to a peer given their multiaddr
  Future<PeerId?> _connectToPeer(String multiaddr) async {
    try {
      // Implementation of peer connection logic
      // This would use the router to establish connection
      return null; // Replace with actual peer connection logic
    } catch (e) {
      // print('Error connecting to peer $multiaddr: $e');
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

  /*
  Future<bool> checkValue(p2p.PeerId peer, String key) async {
    final request = FindValueRequest()..key = utf8.encode(key);

    try {
      final response = await _sendRequest(
        peer,
        PROTOCOL_GET_VALUE,
        request.writeToBuffer(),
      );

      final findValueResponse = FindValueResponse.fromBuffer(response);
      return findValueResponse.hasValue();
    } catch (e) {
      return false;
    }
  }

  Future<bool> storeValue(
      p2p.PeerId peer, Uint8List key, Uint8List value) async {
    final request = PutValueRequest()
      ..key = key
      ..value = value;

    try {
      final response = await _sendRequest(
        peer,
        PROTOCOL_PUT_VALUE,
        request.writeToBuffer(),
      );

      final putValueResponse = PutValueResponse.fromBuffer(response);
      return putValueResponse.success;
    } catch (e) {
      // print('Error storing value with peer ${Base58().encode(peer.value)}: $e');
      return false;
    }
  }
  */

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
