import 'dart:math';
import 'dart:async';
import 'dart:convert';
import '/../src/utils/base58.dart';
import '/../src/utils/varint.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/core/ipfs_node/ipfs_node.dart';
import '../../proto/generated/dht/dht.pb.dart';
import '../../core/ipfs_node/network_handler.dart';
import '../../proto/generated/unixfs/unixfs.pb.dart';
import '../../proto/generated/dht/routing_table.pb.dart';
import '/../src/proto/generated/bitswap/bitswap.pb.dart';
import '/../src/core/network_handler/network_handler.dart';
// lib/src/protocols/dht/dht_client.dart

/// Implementation of the Kademlia DHT protocol for IPFS
/// Following specs from: https://github.com/libp2p/specs/tree/master/kad-dht
class DHTClient {
  final IPFSNode node;
  final p2p.RouterL0 router;

  // Make routing table public as it's a core DHT component
  final RoutingTable routingTable;

  final NetworkHandler networkHandler;

  // Protocol identifiers as per IPFS spec
  static const String PROTOCOL_DHT = '/ipfs/kad/1.0.0';
  static const String PROTOCOL_FIND_NODE = '/ipfs/kad/find-node/1.0.0';
  static const String PROTOCOL_FIND_PEERS = '/ipfs/kad/find-peers/1.0.0';
  static const String PROTOCOL_GET_PROVIDERS = '/ipfs/kad/get-providers/1.0.0';
  static const String PROTOCOL_ADD_PROVIDER = '/ipfs/kad/add-provider/1.0.0';
  static const String PROTOCOL_GET_VALUE = '/ipfs/kad/get-value/1.0.0';
  static const String PROTOCOL_PUT_VALUE = '/ipfs/kad/put-value/1.0.0';

  DHTClient(this.networkHandler)
      : node = networkHandler.ipfsNode,
        router = networkHandler.ipfsNode.dhtHandler.router.routerL0,
        routingTable = RoutingTable() {
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

  p2p.PeerId get peerId => null;

  // Content Routing API
  Future<List<p2p.PeerId>> findProviders(String cid) async {
    final request = FindProvidersRequest()
      ..key = utf8.encode(cid)
      ..count = 20;

    final closestPeers =
        routingTable.findClosestPeers(p2p.PeerId.fromString(cid), 20);
    final providers = <p2p.Peer>[];

    for (final peer in closestPeers) {
      try {
        final response = await _sendRequest(
            peer, PROTOCOL_GET_PROVIDERS, request.writeToBuffer());
        providers.addAll(FindProvidersResponse.fromBuffer(response).providers);
      } catch (e) {
        print('Error querying peer ${peer.id} for providers: $e');
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
}
