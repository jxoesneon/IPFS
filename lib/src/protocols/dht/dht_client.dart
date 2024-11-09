import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart'
    as dht_messages;
import 'package:dart_ipfs/src/utils/base58.dart';
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

    // Register the general packet handler for DHT protocol
    node.dhtHandler.router.addMessageHandler(PROTOCOL_DHT, _handlePacket);

    // Add message handlers for specific protocols
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
  p2p.PeerId _convertProtoPeerToPeerId(dht_messages.Peer protoPeer) {
    return p2p.PeerId(value: Uint8List.fromList(protoPeer.peerId));
  }

  // Convert p2p.PeerId to protobuf Peer
  dht_messages.Peer _convertPeerIdToProtoPeer(p2p.PeerId peerId) {
    return dht_messages.Peer()
      ..peerId = peerId.value
      ..addresses.addAll([]); // Add addresses if needed
  }

  // Content Routing API
  Future<List<p2p.PeerId>> findProviders(String cid) async {
    final request = FindProvidersRequest()
      ..key = utf8.encode(cid)
      ..count = 20;

    final targetPeerId =
        p2p.PeerId(value: Uint8List.fromList(utf8.encode(cid)));
    final closestPeers =
        _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);
    final providers = <p2p.PeerId>[];

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_GET_PROVIDERS, request.writeToBuffer());
        final providerResponse = FindProvidersResponse.fromBuffer(response);

        // Convert DHTPeer to PeerId - Updated to use id instead of peerId
        for (final provider in providerResponse.providers) {
          providers.add(p2p.PeerId(value: Uint8List.fromList(provider.id)));
        }
      } catch (e) {
        print(
            'Error querying peer ${Base58().encode(peer.value)} for providers: $e');
      }
    }

    return providers;
  }

  // Peer Routing API
  Future<p2p.PeerId?> findPeer(p2p.PeerId id) async {
    final protoPeer = _convertPeerIdToProtoPeer(id);
    final request = FindNodeRequest()..peerId = protoPeer.peerId;
    final closestPeers = _kademliaRoutingTable.findClosestPeers(id, 20);

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_FIND_NODE, request.writeToBuffer());
        final nodeResponse = FindNodeResponse.fromBuffer(response);

        final foundPeer = nodeResponse.closerPeers.firstWhere(
            (p) => listsEqual(p.id, id.value),
            orElse: () => throw StateError('Not found'));

        return p2p.PeerId(value: Uint8List.fromList(foundPeer.id));
      } catch (e) {
        print(
            'Error querying peer ${Base58().encode(peer.value)} for peer lookup: $e');
      }
    }
    return null;
  }

  // Value Store API
  Future<void> putValue(String key, String value) async {
    final request = PutValueRequest()
      ..key = utf8.encode(key)
      ..value = utf8.encode(value);

    final targetPeerId = p2p.PeerId(value: Base58().base58Decode(key));
    final closestPeers =
        _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

    for (final peer in closestPeers) {
      try {
        await _sendRequest(peer, PROTOCOL_PUT_VALUE, request.writeToBuffer());
      } catch (e) {
        print(
            'Error storing value with peer ${Base58().encode(peer.value)}: $e');
      }
    }
  }

  // Helper method for sending protocol requests
  Future<Uint8List> _sendRequest(
      p2p.PeerId peer, String protocol, Uint8List data) async {
    final completer = Completer<Uint8List>();

    // Use the node's dhtHandler router instead of the raw RouterL0
    final p2plibRouter = node.dhtHandler.router;

    // Register a one-time message handler for the response
    p2plibRouter.addMessageHandler(protocol, (packet) {
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
      return await completer.future.timeout(Duration(seconds: 30));
    } finally {
      // Clean up the message handler
      p2plibRouter.removeMessageHandler(protocol);
    }
  }

  // Protocol message handlers
  void _handleFindNode(p2p.Packet packet) {
    try {
      final request = FindNodeRequest.fromBuffer(packet.datagram);
      final targetPeerId = _convertProtoPeerToPeerId(
          dht_messages.Peer()..peerId = request.peerId);

      final closestPeers =
          _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

      // Convert IPFSPeer to DHTPeer before sending
      final response = FindNodeResponse()
        ..closerPeers.addAll(
            closestPeers.map((peer) => _convertIPFSPeerToDHTPeer(IPFSPeer(
                id: peer,
                addresses: [], // Add addresses if available
                latency: 0,
                agentVersion: ''))));

      // Send response back using router's resolvePeerId
      node.dhtHandler.router.sendDatagram(
        addresses: node.dhtHandler.router.resolvePeerId(packet.srcPeerId),
        datagram: response.writeToBuffer(),
      );
    } catch (e) {
      print('Error handling find node request: $e');
    }
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
  Future<p2p.PeerId?> _connectToPeer(String multiaddr) async {
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
    final targetPeerId = p2p.PeerId(value: Base58().base58Decode(key));
    final closestPeers =
        _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

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
        print(
            'Error retrieving value from peer ${Base58().encode(peer.value)}: $e');
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
      final message = dht_messages.DHTMessage.fromBuffer(packet.datagram);
      final peerId = packet.srcPeerId;

      // Convert DHTPeer to IPFSPeer for internal use
      final dhtPeer = DHTPeer()
        ..id = peerId.value
        ..addrs.addAll([]); // Add addresses if available
      final ipfsPeer = _convertDHTPeerToIPFSPeer(dhtPeer);

      // Update routing table with the converted peer
      _kademliaRoutingTable.addPeer(ipfsPeer.id, ipfsPeer.id);

      // Handle the message based on its type
      switch (message.type) {
        case dht_messages.DHTMessage_MessageType.FIND_NODE:
          await _handleFindNodeResponse(message, peerId);
          break;
        case dht_messages.DHTMessage_MessageType.GET_VALUE:
          await _handleGetValueResponse(message, peerId);
          break;
        case dht_messages.DHTMessage_MessageType.PUT_VALUE:
          await _handlePutValueResponse(message, peerId);
          break;
        default:
          print('Unhandled DHT message type: ${message.type}');
      }
    } catch (e) {
      print('Error handling DHT packet: $e');
    }
  }

  Future<void> _handleFindNodeResponse(
      dht_messages.DHTMessage message, LibP2PPeerId sourcePeer) async {
    // Implementation using sourcePeer
  }

  Future<void> _handleGetValueResponse(
      dht_messages.DHTMessage message, LibP2PPeerId sourcePeer) async {
    // Implementation using sourcePeer
  }

  Future<void> _handlePutValueResponse(
      dht_messages.DHTMessage message, LibP2PPeerId sourcePeer) async {
    // Implementation using sourcePeer
  }

  /// Adds a provider for a given CID to the DHT network
  Future<void> addProvider(String cid, String providerId) async {
    final dhtPeer = DHTPeer()
      ..id = utf8.encode(providerId)
      ..addrs.addAll([]); // Optional: Add provider addresses if needed

    final request = ProvideRequest()
      ..key = utf8.encode(cid)
      ..provider = dhtPeer;

    final targetPeerId =
        p2p.PeerId(value: Uint8List.fromList(utf8.encode(cid)));
    final closestPeers =
        _kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

    for (final peer in closestPeers) {
      try {
        await _sendRequest(
          peer,
          PROTOCOL_ADD_PROVIDER,
          request.writeToBuffer(),
        );
      } catch (e) {
        print(
            'Error adding provider to peer ${Base58().encode(peer.value)}: $e');
      }
    }
  }

  // Add this helper method to compare Lists<int>
  bool listsEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
