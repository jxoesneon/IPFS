import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '/../src/utils/base58.dart';
import '/../src/utils/varint.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/core/ipfs_node/ipfs_node.dart';
import '../../proto/generated/dht/dht.pb.dart';
import '/../src/core/ipfs_node/ipfs_node.dart';
import '../../core/ipfs_node/network_handler.dart';
import '../../proto/generated/unixfs/unixfs.pb.dart';
import '/../src/core/ipfs_node/network_handler.dart';
import '../../proto/generated/dht/routing_table.pb.dart';
import '/../src/proto/generated/bitswap/bitswap.pb.dart';

// lib/src/protocols/dht/dht_client.dart

/// Implementation of the Kademlia DHT protocol for IPFS
/// Following specs from: https://github.com/libp2p/specs/tree/master/kad-dht
class DHTClient {
  final IPFSNode node;
  final p2p.RouterL0 router;
  late final RoutingTable routingTable;
  final NetworkHandler networkHandler;
  final p2p.PeerId peerId;
  final p2p.PeerId associatedPeerId;
  
  // Protocol identifiers as per IPFS spec
  static const String PROTOCOL_DHT = '/ipfs/kad/1.0.0';
  static const String PROTOCOL_FIND_NODE = '/ipfs/kad/find-node/1.0.0';
  static const String PROTOCOL_FIND_PEERS = '/ipfs/kad/find-peers/1.0.0';
  static const String PROTOCOL_GET_PROVIDERS = '/ipfs/kad/get-providers/1.0.0';
  static const String PROTOCOL_ADD_PROVIDER = '/ipfs/kad/add-provider/1.0.0';
  static const String PROTOCOL_GET_VALUE = '/ipfs/kad/get-value/1.0.0';
  static const String PROTOCOL_PUT_VALUE = '/ipfs/kad/put-value/1.0.0';

  DHTClient({required this.networkHandler})
      : node = networkHandler.ipfsNode,
        router = networkHandler.ipfsNode.dhtHandler.router.routerL0,
        peerId = networkHandler.ipfsNode.dhtHandler.router.routerL0.routes.values.first.peerId,
        associatedPeerId = networkHandler.ipfsNode.dhtHandler.router.routerL0.routes.values.first.peerId {
    // Initialize routing table with this instance
    routingTable = RoutingTable();
    routingTable.initialize(this);
    
    // Register DHT protocols
    node.dhtHandler.router.registerProtocol(PROTOCOL_DHT);
    node.dhtHandler.router.registerProtocol(PROTOCOL_FIND_NODE);
    node.dhtHandler.router.registerProtocol(PROTOCOL_FIND_PEERS);
    node.dhtHandler.router.registerProtocol(PROTOCOL_GET_PROVIDERS);
    node.dhtHandler.router.registerProtocol(PROTOCOL_ADD_PROVIDER);
    node.dhtHandler.router.registerProtocol(PROTOCOL_GET_VALUE);
    node.dhtHandler.router.registerProtocol(PROTOCOL_PUT_VALUE);

    // Add message handlers for each protocol
    node.dhtHandler.router
        .addMessageHandler(PROTOCOL_FIND_NODE, _handleFindNode);
    node.dhtHandler.router
        .addMessageHandler(PROTOCOL_GET_PROVIDERS, _handleGetProviders);
    node.dhtHandler.router
        .addMessageHandler(PROTOCOL_ADD_PROVIDER, _handleAddProvider);
    node.dhtHandler.router
        .addMessageHandler(PROTOCOL_GET_VALUE, _handleGetValue);
    node.dhtHandler.router
        .addMessageHandler(PROTOCOL_PUT_VALUE, _handlePutValue);
  }

  // Content Routing API
  Future<List<p2p.PeerId>> findProviders(String cid) async {
    final request = FindProvidersRequest()
      ..key = utf8.encode(cid)
      ..count = 20;

    // Convert CID to PeerId for routing table lookup
    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(utf8.encode(cid)));
    
    // Get closest peers from routing table using KademliaTree's findClosestPeers
    final closestPeers = routingTable.findClosestPeers(targetPeerId, 20);

    final providers = <p2p.PeerId>[];

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_GET_PROVIDERS, request.writeToBuffer());
        final providerResponse = FindProvidersResponse.fromBuffer(response);
        providers.addAll(
          providerResponse.providers.map((p) => p2p.PeerId(value: p.id))
        );
      } catch (e) {
        print('Error querying peer ${peer.toBase58String()} for providers: $e');
      }
    }

    return providers;
  }

  // Peer Routing API
  Future<p2p.PeerId?> findPeer(p2p.PeerId id) async {
    final request = FindNodeRequest()..peerId = id.toBytes();
    final closestPeers = routingTable.findClosestPeers(id, 20);

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_FIND_NODE, request.writeToBuffer());
        final foundPeer = FindNodeResponse.fromBuffer(response)
            .closerPeers
            .firstWhere((p) => p.id == id.toBytes(), orElse: () => null);
        if (foundPeer != null) {
          return p2p.Peer.fromProto(foundPeer);
        }
      } catch (e) {
        print('Error querying peer ${peer.id} for peer lookup: $e');
      }
    }
    return null;
  }

  // Value Store API
  Future<void> putValue(String key, String value) async {
    final request = PutValueRequest()
      ..key = utf8.encode(key)
      ..value = utf8.encode(value);

    final closestPeers =
        routingTable.findClosestPeers(p2p.PeerId.fromString(key), 20);

    for (final peer in closestPeers) {
      try {
        await _sendRequest(peer, PROTOCOL_PUT_VALUE, request.writeToBuffer());
      } catch (e) {
        print('Error storing value with peer ${peer.id}: $e');
      }
    }
  }

  // Helper method for sending protocol requests
  Future<Uint8List> _sendRequest(
      p2p.Peer peer, String protocol, Uint8List data) async {
    final response = await router.sendRequest(
      peer.id,
      protocol,
      data,
      timeout: Duration(seconds: 30),
    );
    return response;
  }

  // Protocol message handlers
  void _handleFindNode(p2p.Packet packet) {
    // Implementation
  }

  void _handleGetProviders(p2p.Packet packet) {
    // Implementation
  }

  void _handleAddProvider(p2p.Packet packet) {
    // Implementation
  }

  void _handleGetValue(p2p.Packet packet) {
    // Implementation
  }

  void _handlePutValue(p2p.Packet packet) {
    // Implementation
  }

  /// Starts the DHT client and initializes necessary components
  Future<void> start() async {
    try {
      // Register protocol handlers
      for (final protocol in [
        PROTOCOL_DHT,
        PROTOCOL_FIND_NODE,
        PROTOCOL_FIND_PEERS,
        PROTOCOL_GET_PROVIDERS,
        PROTOCOL_ADD_PROVIDER,
        PROTOCOL_GET_VALUE,
        PROTOCOL_PUT_VALUE,
      ]) {
        node.dhtHandler.router.registerProtocol(protocol);
      }

      // Initialize routing table
      await _initializeRoutingTable();
      
      print('DHT client started successfully');
    } catch (e) {
      print('Error starting DHT client: $e');
      rethrow;
    }
  }

  /// Stops the DHT client and cleans up resources
  Future<void> stop() async {
    try {
      // Clean up any active requests or connections
      // Clear routing table
      routingTable.clear();
      
      print('DHT client stopped successfully');
    } catch (e) {
      print('Error stopping DHT client: $e');
      rethrow;
    }
  }

  /// Initialize the routing table with bootstrap peers
  Future<void> _initializeRoutingTable() async {
    // Add bootstrap peers to routing table
    final bootstrapPeers = node.config.bootstrapPeers;
    for (final peerAddr in bootstrapPeers) {
      try {
        final peer = await _connectToPeer(peerAddr);
        if (peer != null) {
          routingTable.addPeer(peer);
        }
      } catch (e) {
        print('Error connecting to bootstrap peer $peerAddr: $e');
      }
    }
  }

  /// Helper method to connect to a peer given their multiaddr
  Future<p2p.Peer?> _connectToPeer(String multiaddr) async {
    try {
      // Implementation of peer connection logic
      // This would use the router to establish connection
      return null; // Replace with actual peer connection logic
    } catch (e) {
      print('Error connecting to peer $multiaddr: $e');
      return null;
    }
  }

  /// Retrieves a value from the DHT network by its key
  Future<String?> getValue(String key) async {
    final request = FindValueRequest()..key = utf8.encode(key);
    final closestPeers = routingTable.findClosestPeers(p2p.PeerId.fromString(key), 20);

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
          peer,
          PROTOCOL_GET_VALUE,
          request.writeToBuffer(),
        );
        
        final findValueResponse = FindValueResponse.fromBuffer(response);
        if (findValueResponse.hasValue()) {
          return utf8.decode(findValueResponse.value);
        }
      } catch (e) {
        print('Error retrieving value from peer ${peer.id}: $e');
      }
    }
    return null;
  }
}
