// src/core/ipfs_node/network_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart' as dht;
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:p2plib/p2plib.dart' as p2p;

import 'ipfs_node.dart';

// lib/src/core/ipfs_node/network_handler.dart

/// Handles network operations for an IPFS node.
class NetworkHandler {
  /// Creates a network handler with config and optional router.
  NetworkHandler(this._config, {P2plibRouter? router})
    : _router = router ?? P2plibRouter(_config),
      _networkEventController = StreamController<NetworkEvent>.broadcast() {
    // Initialize logger
    _logger = Logger(
      'NetworkHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );

    _logger.debug('Initializing NetworkHandler...');

    // Initialize CircuitRelayClient after _router is initialized
    _logger.verbose('Creating CircuitRelayClient with router instance');
    _circuitRelayClient = CircuitRelayClient(_router);

    _logger.verbose('Setting up network event listeners');
    _listenForNetworkEvents();
    _logger.debug('NetworkHandler initialization complete');
  }
  late final CircuitRelayClient _circuitRelayClient;
  final P2plibRouter _router;

  /// Reference to the parent IPFS node.
  late final IPFSNode ipfsNode;
  late final StreamController<NetworkEvent> _networkEventController;
  final IPFSConfig _config;
  late final Logger _logger;

  /// Starts the network services.
  Future<void> start() async {
    try {
      _logger.debug('Starting network services...');
      _logger.verbose('Initializing router...');
      await _router.start();
      _logger.verbose('Router started successfully');

      _logger.verbose('Initializing circuit relay client...');
      await _circuitRelayClient.start();
      _logger.verbose('Circuit relay client started successfully');

      _logger.info('Network services started successfully');
    } catch (e, stackTrace) {
      _logger.error('Error starting network services', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the network services.
  Future<void> stop() async {
    try {
      _logger.debug('Stopping network services...');
      await _circuitRelayClient.stop();
      _logger.verbose('Circuit relay client stopped');

      await _router.stop();
      _logger.verbose('Router stopped');

      await _networkEventController.close();
      _logger.verbose('Network event controller closed');

      _logger.info('Network services stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Error stopping network services', e, stackTrace);
      rethrow;
    }
  }

  /// Access network events stream
  Stream<NetworkEvent> get networkEvents => _networkEventController.stream;

  /// Connects to a peer using its multiaddress.
  Future<void> connectToPeer(String multiaddress) async {
    try {
      await _router.connect(multiaddress);
      // print('Connected to peer at $multiaddress.');
    } catch (e) {
      // print('Error connecting to peer at $multiaddress: $e');
    }
  }

  /// Disconnects from a peer using its multiaddress.
  Future<void> disconnectFromPeer(String multiaddress) async {
    try {
      await _router.disconnect(multiaddress);
      // print('Disconnected from peer at $multiaddress.');
    } catch (e) {
      // print('Error disconnecting from peer at $multiaddress: $e');
    }
  }

  /// Lists all connected peers.
  Future<List<String>> listConnectedPeers() async {
    try {
      final peers = _router.listConnectedPeers();
      // print('Connected peers: ${peers.length}');
      return peers;
    } catch (e) {
      // print('Error listing connected peers: $e');
      return [];
    }
  }

  /// Sends a message to a specific peer.
  Future<void> sendMessage(String peerId, String message) async {
    try {
      // Convert String message to Uint8List
      Uint8List messageBytes = Uint8List.fromList(utf8.encode(message));

      await _router.sendMessage(peerId, messageBytes);
      // print('Message sent to peer $peerId.');
    } catch (e) {
      // print('Error sending message to peer $peerId: $e');
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
      // print('Error receiving messages from peer $peerId: $e');
      return const Stream.empty();
    }
  }

  /// Listens for network events and handles them appropriately.
  void _listenForNetworkEvents() {
    _logger.verbose('Setting up network event stream listener');
    _networkEventController.stream.listen(
      (event) {
        try {
          if (event.hasPeerConnected()) {
            final peerId = event.peerConnected.peerId;
            final multiaddress = event.peerConnected.multiaddress;
            _logger.info('Peer connected: $peerId at address: $multiaddress');

            final peerIdBytes = Uint8List.fromList(utf8.encode(peerId));
            final peer = dht.PeerId(value: peerIdBytes);
            try {
              _logger.verbose('Adding peer to routing table: $peerId');
              ipfsNode.dhtHandler.dhtClient.kademliaRoutingTable.addPeer(
                peer,
                peer,
              );
            } catch (e) {
              _logger.debug('DHT not ready yet, skipping routing table update');
            }
          } else if (event.hasPeerDisconnected()) {
            final peerIdStr = event.peerDisconnected.peerId;
            final reason = event.peerDisconnected.reason;
            _logger.info('Peer disconnected: $peerIdStr. Reason: $reason');

            final peerIdBytes = Uint8List.fromList(utf8.encode(peerIdStr));
            final peerId = dht.PeerId(value: peerIdBytes);
            try {
              _logger.verbose('Removing peer from routing table: $peerIdStr');
              ipfsNode.dhtHandler.dhtClient.kademliaRoutingTable.removePeer(
                peerId,
              );
            } catch (e) {
              _logger.debug('DHT not ready yet, skipping routing table update');
            }
          } else if (event.hasMessageReceived()) {
            final messageContent = utf8.decode(
              event.messageReceived.messageContent,
            );
            final senderId = event.messageReceived.peerId;
            _logger.debug('Message received from $senderId: $messageContent');
          } else {
            _logger.warning('Unhandled event type: ${event.runtimeType}');
          }
        } catch (e, stackTrace) {
          _logger.error('Error processing network event', e, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.error('Error in network event stream', error, stackTrace);
      },
      onDone: () {
        _logger.debug('Network event stream closed');
      },
    );
  }

  /// Returns a Router instance.
  Router get router => Router(_config);

  /// Sets the parent IPFS node reference.
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  /// Sends a request to a peer and waits for a response
  Future<Uint8List> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    try {
      // Create a completer to handle the async response
      final completer = Completer<Uint8List>();

      // Generate request ID
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add request ID to message
      final messageWithId = Uint8List.fromList([
        ...request,
        ...utf8.encode(requestId),
      ]);

      // Set up one-time response handler
      _router.registerProtocolHandler(protocolId, (packet) {
        if (packet.srcPeerId.toString() == peerId.toString() &&
            _extractRequestId(packet.datagram) == requestId) {
          _router.removeMessageHandler(protocolId);
          completer.complete(packet.datagram);
        }
      });

      // Send the request
      await _router.sendMessage(peerId.toString(), messageWithId);

      // Wait for response with timeout
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _router.removeMessageHandler(protocolId);
          throw TimeoutException('Request to peer timed out');
        },
      );
    } catch (e) {
      // print('Error sending request to peer ${peerId.toString()}: $e');
      rethrow;
    }
  }

  /// Extracts the request ID from a datagram
  String _extractRequestId(Uint8List datagram) {
    try {
      // The request ID is appended at the end of the datagram
      // Convert the last portion to UTF-8 string
      final requestIdBytes = datagram.sublist(
        datagram.length - 36,
      ); // UUID is 36 chars
      return utf8.decode(requestIdBytes);
    } catch (e) {
      // print('Error extracting request ID: $e');
      return ''; // Return empty string on error
    }
  }

  /// Gets the P2plibRouter instance
  P2plibRouter get p2pRouter => _router;

  /// Returns the circuit relay client.
  CircuitRelayClient get circuitRelayClient => _circuitRelayClient;

  /// Initializes the network handler.
  Future<void> initialize() async {
    _logger.debug('Initializing NetworkHandler...');

    try {
      await _router.initialize();
      _logger.verbose('Router initialized successfully');

      _setupEventHandlers();
      _logger.verbose('Event handlers configured');

      _logger.debug('NetworkHandler initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize NetworkHandler', e, stackTrace);
      rethrow;
    }
  }

  void _setupEventHandlers() {
    _logger.verbose('Setting up network event handlers');

    _router.connectionEvents.listen((event) {
      _logger.debug('Connection event: ${event.type} - Peer: ${event.peerId}');
      _handleConnectionEvent(event);
    });

    _router.messageEvents.listen((event) {
      _logger.verbose('Message received from: ${event.peerId}');
      _handleMessageEvent(event);
    });
  }

  void _handleConnectionEvent(ConnectionEvent event) {
    try {
      final networkEvent = NetworkEvent();

      switch (event.type) {
        case ConnectionEventType.connected:
          _logger.debug('Handling peer connected event for: ${event.peerId}');
          networkEvent.peerConnected = PeerConnectedEvent()
            ..peerId = event.peerId
            ..multiaddress = event.peerId;
          break;

        case ConnectionEventType.disconnected:
          _logger.debug(
            'Handling peer disconnected event for: ${event.peerId}',
          );
          networkEvent.peerDisconnected = PeerDisconnectedEvent()
            ..peerId = event.peerId
            ..reason = 'Peer disconnected';
          break;
      }

      _networkEventController.add(networkEvent);
      _logger.verbose('Network event dispatched: ${event.type}');
    } catch (e, stackTrace) {
      _logger.error('Error handling connection event', e, stackTrace);
    }
  }

  void _handleMessageEvent(MessageEvent event) {
    try {
      _logger.debug('Handling message from peer: ${event.peerId}');

      final networkEvent = NetworkEvent();
      networkEvent.messageReceived = MessageReceivedEvent()
        ..peerId = event.peerId
        ..messageContent = event.message;

      _networkEventController.add(networkEvent);
      _logger.verbose(
        'Message event dispatched, size: ${event.message.length} bytes',
      );
    } catch (e, stackTrace) {
      _logger.error('Error handling message event', e, stackTrace);
    }
  }

  /// Tests if a direct connection can be established with a peer
  Future<bool> canConnectDirectly(String peerAddress) async {
    try {
      _logger.verbose('Testing direct connection to: $peerAddress');

      // Attempt to establish a direct connection
      await _router.connect(peerAddress);

      //    unawaited(connection.close());ucceeds, immediately disconnect
      await _router.disconnect(peerAddress);

      _logger.debug('Successfully tested direct connection to: $peerAddress');
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to establish direct connection to: $peerAddress',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Tests a connection using a specific source port
  Future<String> testConnection({required int sourcePort}) async {
    late final p2p.TransportUdp tempTransport;

    try {
      _logger.verbose('Testing connection from source port: $sourcePort');

      // Initialize the transport
      tempTransport = p2p.TransportUdp(
        bindAddress: p2p.FullAddress(
          address: InternetAddress.anyIPv4,
          port: sourcePort,
        ),
        ttl: _router.routerL0.messageTTL.inSeconds,
      );

      // Add the transport to the router
      _router.routerL0.transports.add(tempTransport);

      final bootstrapPeer = _config.network.bootstrapPeers.first;
      await _router.connect(bootstrapPeer);

      final peerId = _router.routerL0.routes.values
          .firstWhere((r) => r.peerId.toString() == bootstrapPeer)
          .peerId;

      final addresses = _router.routerL0.resolvePeerId(peerId);
      if (addresses.isEmpty) {
        throw StateError('No addresses found for peer');
      }
      final externalPort = addresses.first.port.toString();

      await _router.disconnect(bootstrapPeer);

      _logger.debug('Connection test completed. External port: $externalPort');
      return externalPort;
    } catch (e, stackTrace) {
      _logger.error('Error testing connection', e, stackTrace);
      return '';
    } finally {
      // Now tempTransport is accessible here
      _router.routerL0.transports.remove(tempTransport);
    }
  }

  /// Tests if the node is reachable from the outside network through dialback
  Future<bool> testDialback() async {
    try {
      _logger.verbose('Starting dialback test');

      // Get a random bootstrap peer to test dialback
      if (_config.network.bootstrapPeers.isEmpty) {
        _logger.debug('No bootstrap peers available for dialback test');
        return false;
      }
      final bootstrapPeer =
          _config.network.bootstrapPeers[Random().nextInt(
            _config.network.bootstrapPeers.length,
          )];

      // Try to establish connection
      await _router.connect(bootstrapPeer);

      // Send dialback request and wait for response
      final response = await _sendDialbackRequest(bootstrapPeer);

      // Clean up connection
      await _router.disconnect(bootstrapPeer);

      _logger.debug('Dialback test completed successfully');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Error performing dialback test', e, stackTrace);
      return false;
    }
  }

  /// Sends a dialback request to a peer
  Future<bool> _sendDialbackRequest(String peerAddr) async {
    try {
      final response = await _router.sendRequest(
        peerAddr,
        '/ipfs/autonat/1.0.0/dialback',
        Uint8List(0), // Empty payload for dialback request
      );

      return response.isNotEmpty;
    } catch (e) {
      _logger.error('Error sending dialback request', e);
      return false;
    }
  }

  /// Gets the IPFS configuration
  IPFSConfig get config => _config;

  /// Gets the peer ID of this node
  String get peerID => _router.peerID;
}
