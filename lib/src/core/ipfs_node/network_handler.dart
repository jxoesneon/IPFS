import 'dart:async';
import 'dart:convert';
import 'ipfs_node.dart';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/core/config/config.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';

// lib/src/core/ipfs_node/network_handler.dart

/// Handles network operations for an IPFS node.
class NetworkHandler {
  final CircuitRelayClient _circuitRelayClient;
  final P2plibRouter _router;
  late final IPFSNode ipfsNode;
  late final StreamController<NetworkEvent> _networkEventController =
      StreamController<NetworkEvent>.broadcast();

  final IPFSConfig _config;

  NetworkHandler(this._config)
      : _router = P2plibRouter(_config),
        _circuitRelayClient = CircuitRelayClient(P2plibRouter(_config)) {
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
      // Convert String peerId to PeerId object
      final peerIdBytes = Uint8List.fromList(utf8.encode(peerId));
      final peer = p2p.PeerId(value: peerIdBytes);

      // Convert String message to Uint8List
      Uint8List messageBytes = Uint8List.fromList(utf8.encode(message));

      await _router.sendMessage(peer, messageBytes);
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
          ipfsNode.dhtHandler.dhtClient.kademliaRoutingTable
              .addPeer(peer, peer);
        } else if (event.hasPeerDisconnected()) {
          final peerIdStr = event.peerDisconnected.peerId;
          final reason = event.peerDisconnected.reason;
          print('Peer left: $peerIdStr. Reason: $reason');

          // Convert string to PeerId object before removing
          final peerIdBytes = Uint8List.fromList(utf8.encode(peerIdStr));
          final peerId = p2p.PeerId(value: peerIdBytes);

          // Using the routing table's removePeer method
          ipfsNode.dhtHandler.dhtClient.kademliaRoutingTable.removePeer(peerId);
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

  // Create Router instance with the config
  Router get router => Router(_config);

  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  /// Sends a request to a peer and waits for a response
  Future<Uint8List> sendRequest(
    p2p.PeerId peer,
    String protocolId,
    Uint8List request,
  ) async {
    try {
      // Create a completer to handle the async response
      final completer = Completer<Uint8List>();

      // Generate request ID
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add request ID to message
      final messageWithId =
          Uint8List.fromList([...request, ...utf8.encode(requestId)]);

      // Set up one-time response handler
      _router.addMessageHandler(protocolId, (packet) {
        if (packet.srcPeerId.toString() == peer.toString() &&
            _extractRequestId(packet.datagram) == requestId) {
          _router.removeMessageHandler(protocolId);
          completer.complete(packet.datagram);
        }
      });

      // Send the request
      await _router.sendMessage(peer, messageWithId);

      // Wait for response with timeout
      return await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          _router.removeMessageHandler(protocolId);
          throw TimeoutException('Request to peer timed out');
        },
      );
    } catch (e) {
      print('Error sending request to peer ${peer.toString()}: $e');
      rethrow;
    }
  }

  /// Extracts the request ID from a datagram
  String _extractRequestId(Uint8List datagram) {
    try {
      // The request ID is appended at the end of the datagram
      // Convert the last portion to UTF-8 string
      final requestIdBytes =
          datagram.sublist(datagram.length - 36); // UUID is 36 chars
      return utf8.decode(requestIdBytes);
    } catch (e) {
      print('Error extracting request ID: $e');
      return ''; // Return empty string on error
    }
  }
}
