// src/protocols/dht/dht_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart'; // For SHA256
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_proto;
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart'
    as ipfs_node_network_events;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;

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
  DHTClient({required this.networkHandler, required P2plibRouter router})
    : _router = router;
  /// The IPFS node this client belongs to.
  IPFSNode get node => networkHandler.ipfsNode;

  /// Handler for network operations.
  final NetworkHandler networkHandler;

  final P2plibRouter _router;
  late final LibP2PPeerId peerId;
  late final LibP2PPeerId associatedPeerId;
  late final KademliaRoutingTable _kademliaRoutingTable;
  bool _initialized = false;

  /// Protocol identifier for Kademlia DHT.
  static const String PROTOCOL_DHT = '/ipfs/kad/1.0.0';

  Future<void> initialize() async {
    if (_initialized) return;

    // Start the router if it hasn't been started
    await _router.initialize();
    await _router.start();

    int retries = 0;
    const maxRetries = 5;

    while (_router.routes.isEmpty && retries < maxRetries) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (_router.routes.isEmpty) {
      throw StateError(
        'No routes available to initialize DHT client after $maxRetries retries',
      );
    }

    peerId = _router.routerL0.routes.values.first.peerId;
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
    _router.registerProtocol(PROTOCOL_DHT);
  }

  void _setupHandlers() {
    // Register handlers for each protocol
    _router.registerProtocolHandler(PROTOCOL_DHT, _handlePacket);
  }

  // Helper: Convert kad.Peer to p2p.PeerId
  p2p.PeerId _convertKadPeerToPeerId(kad.Peer kadPeer) {
    return p2p.PeerId(value: Uint8List.fromList(kadPeer.id));
  }

  // Helper: Convert p2p.PeerId to kad.Peer
  kad.Peer _convertPeerIdToKadPeer(p2p.PeerId peerId) {
    var addresses = <p2p.FullAddress>[];
    try {
      addresses = _router.routerL0.resolvePeerId(peerId).toList();
    } catch (_) {
      // Ignore if peer not found in router
    }
    return kad.Peer()
      ..id = peerId.value
      ..addrs.addAll(addresses.map(multiaddrToBytes));
  }

  // Helper: Get Routing Key (SHA-256 of Multihash)
  p2p.PeerId getRoutingKey(String cidStr) {
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

    // PeerId in p2plib requires 64 bytes (likely due to internal assumptions or crypto size)
    // Pad the 32-byte SHA-256 hash to 64 bytes with trailing zeros
    if (hashBytes.length < 64) {
      final padded = Uint8List(64);
      padded.setAll(0, hashBytes);
      return p2p.PeerId(value: padded);
    }
    return p2p.PeerId(value: hashBytes);
  }

  // Content Routing API: Find Providers (GET_PROVIDERS)
  Future<List<p2p.PeerId>> findProviders(String cid) async {
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
    final providers = <p2p.PeerId>[];

    for (final peer in closestPeers) {
      try {
        final responseBytes = await _sendRequest(
          peer,
          PROTOCOL_DHT,
          msg.writeToBuffer(),
        );
        final response = kad.Message.fromBuffer(responseBytes);

        // Extract providers
        for (final provider in response.providerPeers) {
          final peerId = _convertKadPeerToPeerId(provider);

          // Register addresses in router if present
          if (provider.addrs.isNotEmpty) {
            for (final addrBytes in provider.addrs) {
              try {
                final fullAddr = multiaddrFromBytes(
                  Uint8List.fromList(addrBytes),
                );
                if (fullAddr != null) {
                  _router.routerL0.addPeerAddress(
                    peerId: peerId,
                    address: fullAddr,
                    properties: p2p.AddressProperties(),
                  );
                }
              } catch (e) {
                // Ignore invalid addresses
              }
            }
          }

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

  // Peer Routing API: Find Peer (FIND_NODE)
  Future<p2p.PeerId?> findPeer(p2p.PeerId id) async {
    final msg = kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = id.value; // PeerId is already the key

    final closestPeers = _kademliaRoutingTable.findClosestPeers(id, 20);

    for (final peer in closestPeers) {
      try {
        final responseBytes = await _sendRequest(
          peer,
          PROTOCOL_DHT,
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
    final msg = kad.Message()
      ..type = kad.Message_MessageType.ADD_PROVIDER
      ..key = CID
          .decode(cid)
          .multihash
          .toBytes() // Raw multihash bytes
      ..providerPeers.add(
        _convertPeerIdToKadPeer(
          p2p.PeerId(value: Base58().base58Decode(providerId)),
        ),
      );

    final targetPeerId = getRoutingKey(cid);
    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    for (final peer in closestPeers) {
      try {
        await _sendRequest(peer, PROTOCOL_DHT, msg.writeToBuffer());
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
    final record = dht_proto.Record()
      ..key = key
      ..value = value;

    final msg = kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = record;

    final targetPeerId = getRoutingKey(Base58().encode(key));
    final closestPeers = _kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    int successCount = 0;
    for (final peer in closestPeers) {
      try {
        await _sendRequest(peer, PROTOCOL_DHT, msg.writeToBuffer());
        successCount++;
      } catch (e) {
        // print('Error storing value on peer ${Base58().encode(peer.value)}: $e');
      }
    }

    return successCount > 0;
  }

  /// Retrieves a value from the DHT (GET_VALUE)
  ///
  /// Queries the K closest peers to the key and returns the first value found.
  Future<Uint8List?> getValue(Uint8List key) async {
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
          PROTOCOL_DHT,
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
  Future<bool> checkValueOnPeer(p2p.PeerId peer, Uint8List key) async {
    final msg = kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;

    try {
      final responseBytes = await _sendRequest(
        peer,
        PROTOCOL_DHT,
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
    p2p.PeerId peer,
    String protocol,
    Uint8List data,
  ) async {
    final completer = Completer<Uint8List>();

    // Use the node's dhtHandler router instead of the raw RouterL0
    final p2plibRouter = node.dhtHandler.router;

    // Register a one-time message handler for the response
    p2plibRouter.registerProtocolHandler(protocol, (packet) {
      if (!completer.isCompleted) {
        completer.complete(packet.datagram);
      }
    });

    // Send the request using sendDatagram
    await p2plibRouter.sendDatagram(
      addresses: p2plibRouter.resolvePeerId(peer),
      datagram: data,
    );

    // Wait for response with timeout
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      // Clean up the message handler
      p2plibRouter.removeMessageHandler(protocol);
    }
  }

  // Main Handle Packet
  void _handlePacket(LibP2PPacket packet) async {
    try {
      final message = kad.Message.fromBuffer(packet.datagram);
      final peerId = packet.srcPeerId;

      // Update routing table with IP diversity check
      await _kademliaRoutingTable.addPeer(
        peerId,
        peerId,
        address: packet.srcFullAddress,
      );

      switch (message.type) {
        case kad.Message_MessageType.FIND_NODE:
          // Reply with closer peers
          final closer = _kademliaRoutingTable.findClosestPeers(
            p2p.PeerId(value: Uint8List.fromList(message.key)),
            20,
          );
          final response = kad.Message()
            ..type = kad.Message_MessageType.FIND_NODE
            ..closerPeers.addAll(closer.map((p) => _convertPeerIdToKadPeer(p)));
          _sendResponse(peerId, response);
          break;
        case kad.Message_MessageType.GET_VALUE:
          // Check local storage for record
          // For now return empty or closer peers
          break;
        case kad.Message_MessageType.PING:
          final response = kad.Message()..type = kad.Message_MessageType.PING;
          _sendResponse(peerId, response);
          break;
        default:
        // print('Unhandled DHT message type: ${message.type}');
      }
    } catch (e) {
      // print('Error handling DHT packet: $e');
    }
  }

  void _sendResponse(p2p.PeerId peer, kad.Message msg) {
    node.dhtHandler.router.sendDatagram(
      addresses: node.dhtHandler.router.resolvePeerId(peer),
      datagram: msg.writeToBuffer(),
    );
  }

  /// Starts the DHT client and initializes necessary components
  Future<void> start() async {
    try {
      // Router should already be initialized by IPFSNode
      await _router
          .start(); // This will be safe now with the updated P2plibRouter

      // Register protocol handlers
      node.dhtHandler.router.registerProtocol(PROTOCOL_DHT);

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
      _kademliaRoutingTable.clear();

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
  Future<p2p.PeerId?> _connectToPeer(String multiaddr) async {
    try {
      // Implementation of peer connection logic
      // This would use the router to establish connection
      return null; // Replace with actual peer connection logic
    } catch (e) {
      // print('Error connecting to peer $multiaddr: $e');
      return null;
    }
  }

  // Add a getter for the routing table
  KademliaRoutingTable get kademliaRoutingTable => _kademliaRoutingTable;

  /// Helper method to compare two lists for equality
  bool listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<String>> getAllStoredKeys() async {
    try {
      // Get all keys from the DHT storage
      final List<String> storedKeys = [];

      // Query the datastore for all DHT keys using query
      final query = ds.Query(prefix: '/dht/values/', keysOnly: true);
      await for (final entry in node.dhtHandler.storage.query(query)) {
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
          final targetPeerId = p2p.PeerId(value: Base58().base58Decode(key));

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

  Future<void> updateKeyRepublishTime(String key) async {
    try {
      // Create metadata key for storing republish time
      final metadataKey = ds.Key('/dht/metadata/$key/last_republish');

      // Store current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final timestampData = Uint8List.fromList(
        utf8.encode(timestamp.toString()),
      );

      // Update the timestamp in DHT storage
      await node.dhtHandler.storage.put(metadataKey, timestampData);

      // Update routing table metadata
      try {
        final targetPeerId = p2p.PeerId(value: Base58().base58Decode(key));

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

      await node.dhtHandler.router.emitEvent(
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

  P2plibRouter get router => _router;
}
