import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart' as dht;
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

import 'ipfs_node.dart';

// lib/src/core/ipfs_node/network_handler.dart

/// Handles network operations for an IPFS node.
class NetworkHandler {
  /// Creates a network handler with config and optional router.
  ///
  /// If [router] is not provided, defaults to [Libp2pRouter].
  NetworkHandler(this._config, {RouterInterface? router})
    : _router = router ?? Libp2pRouter(_config),
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
  final RouterInterface _router;

  /// Reference to the parent IPFS node.
  late final IPFSNode ipfsNode;
  late final StreamController<NetworkEvent> _networkEventController;
  final IPFSConfig _config;
  late final Logger _logger;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Returns the router for protocol use.
  RouterInterface get router => _router;

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

      // Register AutoNAT dialback protocol handler
      _registerDialbackHandler();

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

      // Cancel all stream subscriptions
      for (final sub in _subscriptions) {
        await sub.cancel();
      }
      _subscriptions.clear();
      _logger.verbose('Network event subscriptions canceled');

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
    final sub = _networkEventController.stream.listen(
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
              ipfsNode.dhtHandler?.dhtClient.kademliaRoutingTable.addPeer(
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
              ipfsNode.dhtHandler?.dhtClient.kademliaRoutingTable.removePeer(
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
          _logger.error('Error running network event listener', e, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.error('Error in network event stream', error, stackTrace);
      },
      onDone: () {
        _logger.debug('Network event stream closed');
      },
    );
    _subscriptions.add(sub);
  }

  /// Returns a high-level Router instance (for DHT operations).
  Router get dhtRouter => Router(_config);

  /// Sets the parent IPFS node reference.
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  /// Sends a request to a peer and waits for a response
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    return _router.sendRequest(peerId, protocolId, request);
  }

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

    _subscriptions.add(
      _router.connectionEvents.listen((event) {
        _logger.debug(
          'Connection event: ${event.type} - Peer: ${event.peerId}',
        );
        _handleConnectionEvent(event);
      }),
    );

    _subscriptions.add(
      _router.messageEvents.listen((event) {
        _logger.verbose('Message received from: ${event.peerId}');
        _handleMessageEvent(event);
      }),
    );
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
          _config.network.bootstrapPeers[Random.secure().nextInt(
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
      // Extract Peer ID from Multiaddr string
      String targetPeerId = peerAddr;
      if (peerAddr.contains('/p2p/')) {
        targetPeerId = peerAddr.split('/p2p/').last;
      } else if (peerAddr.contains('/ipfs/')) {
        targetPeerId = peerAddr.split('/ipfs/').last;
      }
      if (targetPeerId.contains('/')) {
        targetPeerId = targetPeerId.split('/').first;
      }

      final response = await _router.sendRequest(
        targetPeerId,
        _dialbackProtocolId,
        Uint8List(0), // Empty payload for dialback request
      );

      return response != null && response.isNotEmpty;
    } catch (e) {
      _logger.error('Error sending dialback request', e);
      return false;
    }
  }

  /// Gets the IPFS configuration
  IPFSConfig get config => _config;

  /// Gets the peer ID of this node
  String get peerID => _router.peerID;

  /// Protocol ID for AutoNAT dialback
  static const String _dialbackProtocolId = '/ipfs/autonat/1.0.0/dialback';

  /// Registers the AutoNAT dialback protocol handler.
  ///
  /// This handler responds to incoming dialback requests from peers.
  /// When a peer sends a dialback request, we respond with a success
  /// message to confirm that they can reach us.
  ///
  /// The response must include the original request ID (last 13 bytes of
  /// the incoming datagram) so the sender can correlate the response.
  void _registerDialbackHandler() {
    _logger.verbose('Registering AutoNAT dialback protocol handler');

    _router.registerProtocolHandler(_dialbackProtocolId, (packet) {
      _logger.verbose('Received dialback request from ${packet.srcPeerId}');

      try {
        // Extract request ID from the incoming packet (last 13 chars = timestamp)
        String requestId = '';
        if (packet.datagram.length >= 13) {
          final requestIdBytes = packet.datagram.sublist(
            packet.datagram.length - 13,
          );
          requestId = utf8.decode(requestIdBytes, allowMalformed: true);
        }

        // Respond with success acknowledgment + request ID for correlation
        final responsePayload = utf8.encode('OK');
        final response = Uint8List.fromList([
          ...responsePayload,
          ...utf8.encode(requestId),
        ]);

        _router.sendMessage(
          packet.srcPeerId.toString(),
          response,
          protocolId: _dialbackProtocolId,
        );
        _logger.debug(
          'Sent dialback response to ${packet.srcPeerId} (requestId: $requestId)',
        );
      } catch (e) {
        _logger.error('Error responding to dialback request', e);
      }
    });

    _logger.debug('AutoNAT dialback handler registered');
  }
}
