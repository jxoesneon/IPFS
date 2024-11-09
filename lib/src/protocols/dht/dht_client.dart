import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
// lib/src/protocols/dht/dht_client.dart

/// Implementation of the Kademlia DHT protocol for IPFS
/// Following specs from: https://github.com/libp2p/specs/tree/master/kad-dht
class DHTClient {
  final IPFSNode node;
  final LibP2PRouterL0 router;
  late final KademliaRoutingTable _kademliaRoutingTable;
  final NetworkHandler networkHandler;
  final LibP2PPeerId peerId;
  final LibP2PPeerId associatedPeerId;

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
        peerId = networkHandler
            .ipfsNode.dhtHandler.router.routerL0.routes.values.first.peerId,
        associatedPeerId = networkHandler
            .ipfsNode.dhtHandler.router.routerL0.routes.values.first.peerId {
    // Initialize routing table with this instance
    _kademliaRoutingTable = KademliaRoutingTable();
    _kademliaRoutingTable.initialize(this);

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

  // Convert protobuf Peer to p2p.PeerId
  p2p.PeerId _convertProtoPeerToPeerId(Peer protoPeer) {
    return p2p.PeerId(value: Uint8List.fromList(protoPeer.id));
  }

  // Convert p2p.PeerId to protobuf Peer
  Peer _convertPeerIdToProtoPeer(p2p.PeerId peerId) {
    return Peer()
      ..id = peerId.value
      ..addrs = []; // Add addresses if needed
  }

  // Content Routing API
  Future<List<p2p.PeerId>> findProviders(String cid) async {
    final request = FindProvidersRequest()
      ..key = utf8.encode(cid)
      ..count = 20;

    final targetPeerId =
        p2p.PeerId(value: Uint8List.fromList(utf8.encode(cid)));
    final closestPeers = _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);
    final providers = <p2p.PeerId>[];

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_GET_PROVIDERS, request.writeToBuffer());
        final providerResponse = FindProvidersResponse.fromBuffer(response);

        // Convert protobuf Peers to p2p.PeerIds
        providers
            .addAll(providerResponse.providers.map(_convertProtoPeerToPeerId));
      } catch (e) {
        print('Error querying peer ${peer.toBase58String()} for providers: $e');
      }
    }

    return providers;
  }

  // Peer Routing API
  Future<p2p.PeerId?> findPeer(p2p.PeerId id) async {
    final request = FindNodeRequest()..peerId = id.value;
    final closestPeers = _kademliaRoutingTable.findClosestPeers(id, 20);

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_FIND_NODE, request.writeToBuffer());
        final nodeResponse = FindNodeResponse.fromBuffer(response);

        // Find matching peer in response
        final foundPeer = nodeResponse.closerPeers
            .firstWhere((p) => p.id.equals(id.value), orElse: () => null);

        if (foundPeer != null) {
          return _convertProtoPeerToPeerId(foundPeer);
        }
      } catch (e) {
        print(
            'Error querying peer ${peer.toBase58String()} for peer lookup: $e');
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
        _kademliaRoutingTable.findClosestPeers(p2p.PeerId.fromString(key), 20);

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
      _kademliaRoutingTable.clear();

      print('DHT client stopped successfully');
    } catch (e) {
      print('Error stopping DHT client: $e');
      rethrow;
    }
  }

  /// Initialize the routing table with bootstrap peers
  Future<void> _initializeRoutingTable() async {
    final bootstrapPeers = node.config.bootstrapPeers;
    for (final peerAddr in bootstrapPeers) {
      try {
        final peer = await _connectToPeer(peerAddr);
        if (peer != null) {
          _kademliaRoutingTable.addPeer(peer, peer);
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
    final closestPeers =
        _kademliaRoutingTable.findClosestPeers(p2p.PeerId.fromString(key), 20);

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

  // Add a getter for the routing table
  KademliaRoutingTable get kademliaRoutingTable => _kademliaRoutingTable;

  // Update method signatures to use IPFSPeer
  IPFSPeer _convertDHTPeerToIPFSPeer(DHTPeer protoPeer) {
    return IPFSPeer.fromDHTPeer(protoPeer);
  }

  DHTPeer _convertIPFSPeerToDHTPeer(IPFSPeer peer) {
    return peer.toDHTPeer();
  }

  /// Handles incoming packets from peers.
  void _handlePacket(LibP2PPacket packet) async {
    try {
      final message = await Message.fromBytes(packet.datagram);
      final peerId = packet.srcPeerId;

      // Handle blocks if present
      if (message.hasBlocks()) {
        for (final block in message.getBlocks()) {
          await _handleReceivedBlock(peerId, block);
        }
      }

      // Handle wantlist if present
      if (message.hasWantlist()) {
        final wantlist = message.getWantlist();
        for (final entry in wantlist.entries.values) {
          await handleWantBlock(peerId, entry);
        }
      }

      // Handle block presences if present
      if (message.hasBlockPresences()) {
        for (final presence in message.getBlockPresences()) {
          if (presence.type == BlockPresenceType.have) {
            print('Peer $peerId has block ${presence.cid}');
          } else {
            print('Peer $peerId does not have block ${presence.cid}');
          }
        }
      }
    } catch (e) {
      print('Error handling BitSwap packet: $e');
    }
  }

  /// Adds a provider for a given CID to the DHT network
  Future<void> addProvider(String cid, String providerId) async {
    final request = AddProviderRequest()
      ..key = utf8.encode(cid)
      ..providerId = utf8.encode(providerId);

    final targetPeerId =
        p2p.PeerId(value: Uint8List.fromList(utf8.encode(cid)));
    final closestPeers = _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

    for (final peer in closestPeers) {
      try {
        await _sendRequest(
          peer,
          PROTOCOL_ADD_PROVIDER,
          request.writeToBuffer(),
        );
      } catch (e) {
        print('Error adding provider to peer ${peer.toBase58String()}: $e');
      }
    }
  }
}
