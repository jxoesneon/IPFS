// lib/src/core/ipfs_node/network_handler.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '/../src/transport/circuit_relay_client.dart';
import '/../src/transport/p2plib_router.dart';
import 'ipfs_node_network_events.dart';
import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';

/// Handles network operations for an IPFS node.
class NetworkHandler {
  final CircuitRelayClient _circuitRelayClient;
  final P2plibRouter _router;
  late final IpfsNodeNetworkEvents _networkEvents;
  final StreamController<String> _peerJoinedController = StreamController<String>.broadcast();
  final StreamController<String> _peerLeftController = StreamController<String>.broadcast();

  NetworkHandler(config)
      : _circuitRelayClient = CircuitRelayClient(config),
        _router = P2plibRouter(config) {
    _networkEvents = IpfsNodeNetworkEvents(_circuitRelayClient, _router);
  }

  /// Starts the network services.
  Future<void> start() async {
    try {
      await _router.start();
      await _circuitRelayClient.start();
      _networkEvents.start(); // Start listening for network events
      _listenForNetworkEvents(); // Listen for peer joined/left events
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
      _networkEvents.dispose(); // Dispose of network events listener
      _peerJoinedController.close(); // Close controllers
      _peerLeftController.close();
      print('Network services stopped.');
    } catch (e) {
      print('Error stopping network services: $e');
    }
  }

  /// Access network events stream
  Stream<NetworkEvent> get networkEvents => _networkEvents.networkEvents;

  /// Access peer joined events stream
  Stream<String> get onPeerJoined => _peerJoinedController.stream;

  /// Access peer left events stream
  Stream<String> get onPeerLeft => _peerLeftController.stream;

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
      Uint8List messageBytes = Uint8List.fromList(utf8.encode(message)); // Convert String to Uint8List
      await _router.sendMessage(peerId, messageBytes); // Ensure sendMessage accepts Uint8List
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
    networkEvents.listen((event) {
      if (event.hasPeerConnected()) {
        final peerId = event.peerConnected.peerId;
        print('Peer joined: $peerId');
        _peerJoinedController.add(peerId);
      } else if (event.hasPeerDisconnected()) {
        final peerId = event.peerDisconnected.peerId;
        print('Peer left: $peerId');
        _peerLeftController.add(peerId);
      }
    });
  }
}