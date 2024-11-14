// src/transport/p2plib_router.dart
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '/../src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../protocols/dht/routing_table.dart';
import 'package:synchronized/synchronized.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import '../protocols/bitswap/message.dart' show Message;
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';

// lib/src/transport/p2plib_router.dart

/// A router implementation using the `p2plib` package.
class P2plibRouter {
  static P2plibRouter? _instance;
  static final p2p.Crypto _sharedCrypto = p2p.Crypto();
  static final _cryptoInitLock = Lock();
  bool _isInitialized = false;
  final Logger _logger;

  final IPFSConfig _config;
  final p2p.RouterL2 _router;
  RoutingTable? _routingTable;
  final Set<p2p.PeerId> _connectedPeers = {};

  bool _isCryptoInitialized = false;
  bool _hasStarted = false;

  // Stream controllers
  final _messageController = StreamController<p2p.Message>.broadcast();
  final _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();
  final _messageEventsController = StreamController<MessageEvent>.broadcast();
  final _dhtEventsController = StreamController<DHTEvent>.broadcast();
  final _pubSubEventsController = StreamController<PubSubEvent>.broadcast();
  final _errorEventsController = StreamController<ErrorEvent>.broadcast();
  final _streamEventsController = StreamController<StreamEvent>.broadcast();

  // Protocol handling
  final Set<String> _registeredProtocols = {};
  final Map<String, Function(p2p.Packet)> _protocolHandlers = {};

  factory P2plibRouter(IPFSConfig config) {
    if (_instance == null) {
      _instance = P2plibRouter._internal(config);
    }
    return _instance!;
  }

  P2plibRouter._internal(this._config)
      : _router = p2p.RouterL2(
          crypto: _sharedCrypto,
          keepalivePeriod: const Duration(seconds: 30),
        ),
        _logger = Logger('P2plibRouter',
            debug: _config.debug, verbose: _config.verboseLogging) {
    _setupRouter();
  }

  void _setupRouter() {
    // Initialize the router with the provided configuration
    _router.transports.clear();
    _router.transports.add(p2p.TransportUdp(
      bindAddress: p2p.FullAddress(
        address: InternetAddress.anyIPv4,
        port: p2p.TransportUdp.defaultPort,
      ),
      ttl: _router.messageTTL.inSeconds,
    ));
    _router.transports.add(p2p.TransportUdp(
      bindAddress: p2p.FullAddress(
        address: InternetAddress.anyIPv6,
        port: p2p.TransportUdp.defaultPort,
      ),
      ttl: _router.messageTTL.inSeconds,
    ));
    _router.messageTTL = const Duration(minutes: 1);
  }

  /// The peer ID of this node.
  String get peerID => Base58().encode(_router.selfId.value);

  /// The connected peers.
  List<p2p.Route> get connectedPeers => _router.routes.values.toList();

  /// Initializes the router with basic configuration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.debug('Initializing P2plibRouter...');
      await _cryptoInitLock.synchronized(() async {
        if (!_isCryptoInitialized) {
          _logger.verbose('Initializing crypto components');
          await _sharedCrypto.init();
          _isCryptoInitialized = true;
          _logger.verbose('Crypto components initialized successfully');
        }
      });

      _logger.verbose('Initializing router with peer ID');
      final randomBytes =
          List<int>.generate(32, (i) => Random.secure().nextInt(256));
      await _router.init(Uint8List.fromList(randomBytes));
      _logger.verbose(
          'Router initialized with peer ID: ${Base58().encode(_router.selfId.value)}');

      _isInitialized = true;
      _logger.debug('P2plibRouter initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Error initializing P2plibRouter', e, stackTrace);
      rethrow;
    }
  }

  /// Starts the router.
  Future<void> start() async {
    if (!_isInitialized) {
      _logger.debug('Router not initialized, initializing...');
      await initialize();
    }

    // Only start the router and connect to bootstrap peers once
    if (!_hasStarted) {
      if (!_router.isRun) {
        _logger.debug('Starting router...');
        await _router.start();
        _logger.verbose('Router started successfully');
      }

      // Only connect to bootstrap peers once
      if (_connectedPeers.isEmpty) {
        await _connectToBootstrapPeers();
      }

      _hasStarted = true;
    }
  }

  Future<void> _connectToBootstrapPeers() async {
    _logger.debug('Connecting to bootstrap peers...');
    for (final peer in _config.network.bootstrapPeers) {
      try {
        _logger.verbose('Attempting to connect to bootstrap peer: $peer');
        final peerIdBytes = Base58().base58Decode(peer);
        final peerId = p2p.PeerId(value: peerIdBytes);

        _router.addPeerAddress(
          peerId: peerId,
          address: p2p.FullAddress(
            address: InternetAddress.anyIPv4,
            port: p2p.TransportUdp.defaultPort,
          ),
          properties: p2p.AddressProperties(),
        );
        _connectedPeers.add(peerId);
        _connectionEventsController.add(
          ConnectionEvent(
            type: ConnectionEventType.connected,
            peerId: peer,
          ),
        );
      } catch (e, stackTrace) {
        _logger.error('Error adding bootstrap peer: $peer', e, stackTrace);
      }
    }
  }

  /// Stops the router.
  Future<void> stop() async {
    await _messageController.close();
    _router.stop();
    // Close all event controllers
    await _connectionEventsController.close();
    await _messageEventsController.close();
    await _dhtEventsController.close();
    await _pubSubEventsController.close();
    await _errorEventsController.close();
    await _streamEventsController.close();
  }

  /// Connects to a peer using its multiaddress.
  Future<void> connect(String multiaddress) async {
    try {
      final address = parseMultiaddr(multiaddress);
      final peerId =
          p2p.PeerId(value: _extractPeerIdFromMultiaddr(multiaddress));
      _router.addPeerAddress(
        peerId: peerId,
        address: address,
        properties: p2p.AddressProperties(),
      );
      _connectedPeers.add(peerId);
      _connectionEventsController.add(
        ConnectionEvent(
          type: ConnectionEventType.connected,
          peerId: multiaddress,
        ),
      );
    } catch (e) {
      _errorEventsController.add(
        ErrorEvent(
          type: ErrorEventType.connectionError,
          message: 'Failed to connect to $multiaddress: $e',
        ),
      );
      rethrow;
    }
  }

  /// Disconnects from a peer.
  Future<void> disconnect(String multiaddress) async {
    try {
      final peerIdBytes = _extractPeerIdFromMultiaddr(multiaddress);
      final peerId = p2p.PeerId(value: peerIdBytes);
      _router.removePeerAddress(peerId);
      _connectedPeers.remove(peerId);
      _connectionEventsController.add(
        ConnectionEvent(
          type: ConnectionEventType.disconnected,
          peerId: multiaddress,
        ),
      );
    } catch (e) {
      _errorEventsController.add(
        ErrorEvent(
          type: ErrorEventType.disconnectionError,
          message: 'Failed to disconnect from $multiaddress: $e',
        ),
      );
      rethrow;
    }
  }

  /// Lists all connected peers.
  List<String> listConnectedPeers() {
    return connectedPeers.map((route) => route.peerId.toString()).toList();
  }

  /// Sends a message to a peer.
  Future<void> sendMessage(p2p.PeerId peer, Uint8List message) {
    final addresses = _router.resolvePeerId(peer);
    if (addresses.isEmpty) {
      throw Exception('No addresses found for peer ${peer.toString()}');
    }

    _router.sendDatagram(
      addresses: addresses,
      datagram: message,
    );
    return Future.value();
  }

  /// Receives messages from a specific peer.
  Stream<String> receiveMessages(String peerId) async* {
    // Convert the messageStream to filter messages from specific peer
    await for (final message in _router.messageStream) {
      if (message.srcPeerId.toString() == peerId) {
        final payload = message.payload;
        if (payload != null && payload.isNotEmpty) {
          yield utf8.decode(payload);
        }
      }
    }
  }

  /// Resolves a peer ID to a list of addresses.
  List<String> resolvePeerId(p2p.PeerId peerId) {
    return _router
        .resolvePeerId(peerId)
        .map((address) => '${address.address.address}:${address.port}')
        .toList();
  }

  /// Registers a callback for handling incoming messages
  void onMessage(void Function(Message) handler) {
    _router.messageStream.listen((message) async {
      // Check if payload exists before converting
      if (message.payload != null) {
        try {
          final bitswapMessage = await Message.fromBytes(message.payload!);
          handler(bitswapMessage);
        } catch (e) {
          print('Error converting message payload: $e');
        }
      } else {
        print('Received message with null payload, skipping...');
      }
    });
  }

  /// Adds a message handler for a specific protocol
  void addMessageHandler(String protocolId, void Function(p2p.Packet) handler) {
    if (!_registeredProtocols.contains(protocolId)) {
      throw Exception('Protocol $protocolId not registered');
    }

    _protocolHandlers[protocolId] = handler;

    // Use the broadcast controller instead
    if (!_messageController.hasListener) {
      _router.messageStream.listen((message) {
        _messageController.add(message);
      });
    }

    _messageController.stream.listen((message) {
      final packet = p2p.Packet(
        datagram: message.payload ?? Uint8List(0),
        header: message.header,
        srcFullAddress: p2p.FullAddress(
          address: InternetAddress.anyIPv4,
          port: p2p.TransportUdp.defaultPort,
        ),
      );

      packet.srcPeerId = message.srcPeerId;
      packet.dstPeerId = message.dstPeerId;

      // Call the appropriate protocol handler
      if (_protocolHandlers.containsKey(protocolId)) {
        _protocolHandlers[protocolId]!(packet);
      }
    });
  }

  /// Removes a message handler for a specific protocol
  void removeMessageHandler(String protocolId) {
    _protocolHandlers.remove(protocolId);
  }

  /// Sends a datagram to the specified addresses.
  Future<void> sendDatagram({
    required List<String> addresses,
    required Uint8List datagram,
  }) {
    // Convert string addresses to FullAddress objects
    final fullAddresses = addresses.map((addr) {
      final parts = addr.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid address format: $addr');
      }
      return p2p.FullAddress(
        address: InternetAddress(parts[0]),
        port: int.parse(parts[1]),
      );
    });

    _router.sendDatagram(
      addresses: fullAddresses,
      datagram: datagram,
    );
    return Future.value();
  }

  /// Gets the routing table for DHT operations
  RoutingTable getRoutingTable() {
    // Create a new routing table if it doesn't exist
    _routingTable ??= RoutingTable(
      _router.selfId,
      DHTClient(
        networkHandler: NetworkHandler(_config),
        router: this,
      ),
    );
    return _routingTable!;
  }

  /// Emits a network event with the given topic and data
  Future<void> emitEvent(String topic, Uint8List data) async {
    // Create a network event message
    final eventMessage = NetworkMessage(data);

    // Broadcast to all connected peers
    for (final route in connectedPeers) {
      try {
        await sendMessage(route.peerId, data);
      } catch (e) {
        print('Error sending event to peer ${route.peerId}: $e');
      }
    }

    // Notify local event handlers if registered
    if (_eventHandlers.containsKey(topic)) {
      for (final handler in _eventHandlers[topic]!) {
        handler(eventMessage);
      }
    }
  }

  final Map<String, List<Function(NetworkMessage)>> _eventHandlers = {};

  /// Registers an event handler for a specific topic
  void onEvent(String topic, Function(NetworkMessage) handler) {
    _eventHandlers.putIfAbsent(topic, () => []).add(handler);
  }

  /// Removes an event handler for a specific topic
  void offEvent(String topic, Function(NetworkMessage) handler) {
    if (_eventHandlers.containsKey(topic)) {
      _eventHandlers[topic]!.remove(handler);
    }
  }

  /// Parses a multiaddress string into a FullAddress object
  p2p.FullAddress parseMultiaddr(String multiaddr) {
    // Multiaddr format: /ip4/127.0.0.1/tcp/4001/p2p/QmHash...
    final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();

    // Extract IP address and port
    String? ipAddress;
    int? port;

    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == 'ip4' || parts[i] == 'ip6') {
        ipAddress = parts[i + 1];
      } else if (parts[i] == 'tcp' || parts[i] == 'udp') {
        port = int.parse(parts[i + 1]);
      }
    }

    if (ipAddress == null || port == null) {
      throw FormatException('Invalid multiaddr format: $multiaddr');
    }

    return p2p.FullAddress(
      address: InternetAddress(ipAddress),
      port: port,
    );
  }

  /// Extracts the peer ID from a multiaddress string
  Uint8List _extractPeerIdFromMultiaddr(String multiaddr) {
    final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();
    final peerIdIndex = parts.indexOf('p2p') + 1;
    if (peerIdIndex >= parts.length) {
      throw FormatException('No peer ID found in multiaddr: $multiaddr');
    }
    return Base58().base58Decode(parts[peerIdIndex]);
  }

  // Add to P2plibRouter class
  bool isConnectedPeer(p2p.PeerId peerId) {
    // 1. Check if peer is in our connected peers set
    if (!_connectedPeers.contains(peerId)) {
      return false;
    }

    // 2. Check if peer exists in router's routes
    final route = _router.routes[peerId];
    if (route == null) {
      // If peer is in _connectedPeers but not in routes, clean up the inconsistency
      _connectedPeers.remove(peerId);
      return false;
    }

    // 3. Check if we have valid addresses for this peer
    final addresses = _router.resolvePeerId(peerId);
    if (addresses.isEmpty) {
      return false;
    }

    // 4. Check if the peer has been seen recently (within last 2 minutes)
    if (DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(route.lastSeen)) >
        const Duration(minutes: 2)) {
      // Clean up stale connection
      _connectedPeers.remove(peerId);
      _router.removePeerAddress(peerId);

      // Emit disconnection event
      _connectionEventsController.add(
        ConnectionEvent(
          type: ConnectionEventType.disconnected,
          peerId: Base58().encode(peerId.value),
        ),
      );
      return false;
    }

    // 5. Check if the peer's connection is active by checking if it's reachable
    try {
      final isReachable = _router.resolvePeerId(peerId).isNotEmpty;
      if (!isReachable) {
        _connectedPeers.remove(peerId);
        return false;
      }
    } catch (e) {
      _connectedPeers.remove(peerId);
      return false;
    }

    return true;
  }

  /// The PeerId instance for this node.
  p2p.PeerId get peerId => _router.selfId;

  /// Gets the routes from the underlying router
  Map<p2p.PeerId, p2p.Route> get routes => _router.routes;

  /// Registers a protocol with the router
  void registerProtocol(String protocolId) {
    if (_registeredProtocols.contains(protocolId)) {
      _logger.verbose('Protocol $protocolId already registered');
      return;
    }

    _registeredProtocols.add(protocolId);
    _logger.debug('Registered protocol: $protocolId');
  }

  /// Gets the underlying RouterL0 instance
  p2p.RouterL2 get routerL0 => _router;

  /// Stream of connection events
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  /// Stream of message events
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;

  /// Stream of DHT events
  Stream<DHTEvent> get dhtEvents => _dhtEventsController.stream;

  /// Stream of PubSub events
  Stream<PubSubEvent> get pubSubEvents => _pubSubEventsController.stream;

  /// Stream of stream events
  Stream<StreamEvent> get streamEvents => _streamEventsController.stream;

  /// Stream of error events
  Stream<ErrorEvent> get errorEvents => _errorEventsController.stream;

  /// Whether the router has been initialized
  bool get isInitialized => _isInitialized;

  /// Sends a request to a peer and waits for a response
  Future<Uint8List> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    try {
      // Convert peerId string to PeerId object
      final peerIdBytes = _extractPeerIdFromMultiaddr(peerId);
      final peer = p2p.PeerId(value: peerIdBytes);

      // Create a completer to handle the async response
      final completer = Completer<Uint8List>();
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add request ID to message
      final messageWithId =
          Uint8List.fromList([...request, ...utf8.encode(requestId)]);

      // Set up one-time response handler
      addMessageHandler(protocolId, (packet) {
        if (packet.srcPeerId.toString() == peerId &&
            _extractRequestId(packet.datagram) == requestId) {
          removeMessageHandler(protocolId);
          completer.complete(packet.datagram);
        }
      });

      // Send the request
      await sendMessage(peer, messageWithId);

      // Wait for response with timeout
      return await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          removeMessageHandler(protocolId);
          throw TimeoutException('Request to peer timed out');
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error sending request to peer $peerId', e, stackTrace);
      rethrow;
    }
  }

  String _extractRequestId(Uint8List datagram) {
    try {
      // The request ID is appended at the end of the datagram
      final requestIdBytes =
          datagram.sublist(datagram.length - 13); // Timestamp is 13 chars
      return utf8.decode(requestIdBytes);
    } catch (e) {
      _logger.error('Error extracting request ID', e);
      return '';
    }
  }

  p2p.PeerId get localPeerId => _router.selfId;
}

mixin MultiAddressHandler {
  String get multiaddr;
  void setMultiaddr(String addr);
}

class NetworkMessage {
  final Uint8List data;

  NetworkMessage(this.data);

  static NetworkMessage fromBytes(Uint8List bytes) {
    return NetworkMessage(bytes);
  }
}

// Event classes for type-safe event handling
class ConnectionEvent {
  final ConnectionEventType type;
  final String peerId;

  ConnectionEvent({required this.type, required this.peerId});
}

enum ConnectionEventType { connected, disconnected }

class MessageEvent {
  final String peerId;
  final Uint8List message;

  MessageEvent({required this.peerId, required this.message});
}

class DHTEvent {
  final DHTEventType type;
  final Map<String, dynamic> data;

  DHTEvent({required this.type, required this.data});
}

enum DHTEventType { valueFound, providerFound }

class PubSubEvent {
  final String topic;
  final Uint8List message;
  final String publisher;
  final String eventType;

  PubSubEvent({
    required this.topic,
    required this.message,
    required this.publisher,
    required this.eventType,
  });
}

class ErrorEvent {
  final ErrorEventType type;
  final String message;

  ErrorEvent({required this.type, required this.message});
}

enum ErrorEventType { connectionError, disconnectionError, messageError }

class StreamEvent {
  final StreamEventType type;
  final String streamId;
  final Uint8List? data;

  StreamEvent({required this.type, required this.streamId, this.data});
}

enum StreamEventType { opened, closed, data }
