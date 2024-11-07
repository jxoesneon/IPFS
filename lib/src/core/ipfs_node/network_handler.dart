import 'dart:async';
import 'dart:convert';
import 'ipfs_node.dart';
import 'dart:typed_data';
import '/../src/protocols/dht/peer.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/transport/p2plib_router.dart';
import '/../src/protocols/dht/dht_client.dart';
import '/../src/protocols/dht/kademlia_routing_table.dart';
import '/../src/transport/circuit_relay_client.dart';
import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';
// lib/src/core/ipfs_node/network_handler.dart

/// Handles network operations for an IPFS node.
class NetworkHandler {
  final CircuitRelayClient _circuitRelayClient;
  final P2plibRouter _router;
  late final IPFSNode ipfsNode;
  late final StreamController<NetworkEvent> _networkEventController =
      StreamController<NetworkEvent>.broadcast();

  NetworkHandler(config)
      : _circuitRelayClient = CircuitRelayClient(config),
        _router = P2plibRouter(config) {
    // Start listening for network events
    _listenForNetworkEvents();
  }

  /// Starts the network services.
  Future<void> start() async {
    try {
      await _router.start();
      await _circuitRelayClient.start();
      print('Network services started.');
    } catch (e) {
      print('Error starting network services: $e');
    }
  }

  /// Stops the network services.
  Future<void> stop() async {
    try {
      await _circuitRelayClient.stop();
      await _router.stop();
      _networkEventController.close(); // Close the event controller
      print('Network services stopped.');
    } catch (e) {
      print('Error stopping network services: $e');
    }
  }

  /// Access network events stream
  Stream<NetworkEvent> get networkEvents => _networkEventController.stream;

  /// Connects to a peer using its multiaddress.
  Future<void> connectToPeer(String multiaddress) async {
    try {
      await _router.connect(multiaddress);
      print('Connected to peer at $multiaddress.');
    } catch (e) {
      print('Error connecting to peer at $multiaddress: $e');
    }
  }

  /// Disconnects from a peer using its multiaddress.
  Future<void> disconnectFromPeer(String multiaddress) async {
    try {
      await _router.disconnect(multiaddress);
      print('Disconnected from peer at $multiaddress.');
    } catch (e) {
      print('Error disconnecting from peer at $multiaddress: $e');
    }
  }

  /// Lists all connected peers.
  Future<List<String>> listConnectedPeers() async {
    try {
      final peers = await _router.listConnectedPeers();
      print('Connected peers: ${peers.length}');
      return peers;
    } catch (e) {
      print('Error listing connected peers: $e');
      return [];
    }
  }

  /// Sends a message to a specific peer.
  Future<void> sendMessage(String peerId, String message) async {
    try {
      Uint8List messageBytes = Uint8List.fromList(
          utf8.encode(message)); // Convert String to Uint8List
      await _router.sendMessage(
          peerId, messageBytes); // Ensure sendMessage accepts Uint8List
      print('Message sent to peer $peerId.');
    } catch (e) {
      print('Error sending message to peer $peerId: $e');
    }
  }

  /// Receives messages from a specific peer.
  Stream<String> receiveMessages(String peerId) {
    try {
      // Assuming _router.receiveMessage returns a Stream<Uint8List>
      return _router.receiveMessages(peerId).map((messageBytes) {
        // Convert Uint8List back to String
        return utf8.decode(messageBytes as List<int>);
      });
    } catch (e) {
      print('Error receiving messages from peer $peerId: $e');
      return Stream.empty();
    }
  }

  /// Listens for network events and handles them appropriately.
  void _listenForNetworkEvents() {
    _networkEventController.stream.listen((event) {
      try {
        if (event.hasPeerConnected()) {
          final peerId = event.peerConnected.peerId;
          final multiaddress = event.peerConnected.multiaddress;
          print('Peer joined: $peerId at address: $multiaddress');

          // Convert peerId to PeerId object and add to routing table with itself as associated peer
          final peerIdBytes = Uint8List.fromList(utf8.encode(peerId));
          final peer = p2p.PeerId(value: peerIdBytes);
          // Using the routing table's addPeer method
          ipfsNode.dhtHandler.dhtClient.routingTable.addPeer(peer, peer);
        } else if (event.hasPeerDisconnected()) {
          final peerIdStr = event.peerDisconnected.peerId;
          final reason = event.peerDisconnected.reason;
          print('Peer left: $peerIdStr. Reason: $reason');

          // Convert string to PeerId object before removing
          final peerIdBytes = Uint8List.fromList(utf8.encode(peerIdStr));
          final peerId = p2p.PeerId(value: peerIdBytes);
          
          // Using the routing table's removePeer method
          ipfsNode.dhtHandler.dhtClient.routingTable.removePeer(peerId);
        } else if (event.hasMessageReceived()) {
          final messageContent =
              utf8.decode(event.messageReceived.messageContent);
          final senderId = event.messageReceived.peerId;
          print('Message received from $senderId: $messageContent');
        } else {
          print('Unhandled event type: ${event.runtimeType}');
        }
      } catch (e, stackTrace) {
        print('Error processing network event: $e');
        print(stackTrace);
      }
    }, onError: (error) {
      print('Error in network event stream: $error');
    }, onDone: () {
      print('Network event stream closed.');
    });
  }

  // Update helper method to use public property
  p2p.PeerId _calculateClosestPeer(p2p.PeerId peerId) {
    return ipfsNode.dhtHandler.dhtClient.routingTable
            .findClosestPeers(peerId, 1)
            .firstOrNull
            ?.id ??
        peerId;
  }

  // Add setter method
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }
}
