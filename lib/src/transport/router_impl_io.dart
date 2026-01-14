// src/transport/p2plib_router.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' show Message;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/routing_table.dart';
import 'package:dart_ipfs/src/transport/libp2p_transport.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:p2plib/p2plib.dart' as p2p;

import 'simple_crypto.dart';

/// Low-level P2P networking router using the p2plib package.
///
/// P2plibRouter provides the transport layer for IPFS networking,
/// handling peer connections, message routing, and protocol dispatch.
/// It wraps the [p2plib](https://pub.dev/packages/p2plib) library
/// to provide IPFS-specific networking functionality.
///
/// **Key Features:**
/// - UDP transport with IPv4/IPv6 support
/// - Peer discovery and connection management
/// - Protocol-based message routing
/// - Event streams for connection and message monitoring
///
/// Example:
/// ```dart
/// final router = P2plibRouter(config);
/// await router.initialize();
/// await router.start();
///
/// // Connect to a peer
/// await router.connect('/ip4/127.0.0.1/tcp/4001/p2p/Qm...');
///
/// // Send a message
/// await router.sendMessage(peerId, messageBytes);
/// ```
///
/// See also:
/// - [NetworkHandler] for higher-level network operations
/// - [DHTClient] for DHT protocol integration
class P2plibRouter {
  /// Creates a [P2plibRouter] instance for the given [config].
  P2plibRouter(this._config, {p2p.RouterL2? router})
    : _router =
          router ??
          p2p.RouterL2(
            crypto: SimpleCrypto(),
            keepalivePeriod: const Duration(seconds: 30),
            transports: [],
          ),
      _logger = Logger('P2plibRouter', debug: true, verbose: true) {
    _setupRouter();
    // Increase peer TTL to be more robust against packet loss
    _router.peerAddressTTL = const Duration(minutes: 10);
  }
  bool _isInitialized = false;
  final Logger _logger;

  final IPFSConfig _config;
  final p2p.RouterL2 _router;
  RoutingTable? _routingTable;
  final Set<p2p.PeerId> _connectedPeers = {};

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
  final Map<String, void Function(NetworkPacket)> _protocolHandlers = {};
  StreamSubscription<p2p.Message>? _dispatcherSubscription;

  void _setupRouter() {
    // Initialize the router with the provided configuration
    _router.transports.clear();

    // Default port if none found in addresses
    int port = p2p.TransportUdp.defaultPort;

    // Try to extract port from the first listen address
    // Format: /ip4/0.0.0.0/udp/4001 or /ip4/0.0.0.0/tcp/4001
    for (final addr in _config.network.listenAddresses) {
      final parts = addr.split('/');
      final ipIndex = parts.indexOf('ip4');
      final ip6Index = parts.indexOf('ip6');
      final udpIndex = parts.indexOf('udp');
      final tcpIndex = parts.indexOf('tcp');
      final portIndex = (udpIndex != -1 ? udpIndex : tcpIndex) + 1;

      InternetAddress bindIp = InternetAddress.anyIPv4;
      if (ipIndex != -1 && ipIndex + 1 < parts.length) {
        bindIp = InternetAddress(parts[ipIndex + 1]);
      } else if (ip6Index != -1 && ip6Index + 1 < parts.length) {
        bindIp = InternetAddress(parts[ip6Index + 1]);
      }

      if (portIndex > 0 && portIndex < parts.length) {
        port = int.tryParse(parts[portIndex]) ?? port;
      }
      _router.transports.add(
        p2p.TransportUdp(
          bindAddress: p2p.FullAddress(address: bindIp, port: port),
          ttl: _router.messageTTL.inSeconds,
        ),
      );
    }

    // Libp2p Bridge Transport is now added during initialize() after crypto is ready.

    _router.messageTTL = const Duration(minutes: 1);
  }

  /// The peer ID of this node.
  String get peerID => Base58().encode(_router.selfId.value);

  /// The connected peers (List of PeerID strings).
  List<String> get connectedPeers =>
      _router.routes.keys.map((pid) => Base58().encode(pid.value)).toList();

  /// Get the addresses this router is listening on
  List<String> get listeningAddresses {
    // Current p2plib doesn't expose bound addresses easily via public API of RouterL2
    // But since we created the transports, we know what we bound to.
    // However, if port was 0, we'd need the actual port.
    // Assuming defaultPort for now or reconstruction.

    // A proper implementation would query the transports.
    // Since RouterL2 exposes 'transports', we can iterate them.
    return _router.transports.map((t) {
      final addr = t.bindAddress.address;
      final port = t.bindAddress.port;
      final protocol = addr.type == InternetAddressType.IPv4 ? 'ip4' : 'ip6';
      // p2plib uses UDP by default in our setup
      return '/$protocol/${addr.address}/udp/$port/p2p/$peerID';
    }).toList();
  }

  /// Resolves a peer ID to a list of multiaddresses (strings).
  List<String> resolvePeer(String peerIdStr) {
    try {
      final peerId = p2p.PeerId(value: Base58().base58Decode(peerIdStr));
      return _router.resolvePeerId(peerId).map((fullAddr) {
        final addr = fullAddr.address;
        final protocol = addr.type == InternetAddressType.IPv4 ? 'ip4' : 'ip6';
        return '/$protocol/${addr.address}/udp/${fullAddr.port}/p2p/$peerIdStr';
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Initializes the router with basic configuration
  Future<void> initialize() async {
    _logger.debug('Initializing P2plibRouter...');
    if (_isInitialized) return;

    try {
      _logger.debug('Initializing P2plibRouter...');
      _logger.verbose('Initializing crypto components');

      // Use the nodeId from config as the seed.
      // This ensures Libp2p ID and p2plib ID represent the same node.
      final seed = Base58().base58Decode(_config.nodeId);

      await _router.crypto.init(seed);
      _logger.verbose('Crypto components initialized successfully');

      _logger.verbose('Initializing router with peer ID');
      await _router.init(seed);
      _logger.verbose(
        'Router initialized with peer ID: ${Base58().encode(_router.selfId.value)}',
      );

      // Add Libp2p Bridge Transport if enabled
      if (_config.enableLibp2pBridge) {
        _logger.debug('Enabling Libp2p Bridge Transport...');
        final libp2pParts = _config.libp2pListenAddress.split('/');
        final libp2pPortIndex = libp2pParts.indexOf('tcp') + 1;
        int libp2pPort = 4001;
        if (libp2pPortIndex > 0 && libp2pPortIndex < libp2pParts.length) {
          libp2pPort = int.tryParse(libp2pParts[libp2pPortIndex]) ?? 4001;
        }

        final libp2pTransport = Libp2pTransport(
          bindAddress: p2p.FullAddress(
            address: InternetAddress.anyIPv4,
            port: libp2pPort,
          ),
          // Use the same seed decoded from nodeId
          seed: seed,
          listenAddress: _config.libp2pListenAddress,
          logger: (msg) => _logger.info('Libp2pBridge: $msg'),
        );
        libp2pTransport.onMessage = (packet) async {
          // Re-stamp destination ID to match our actual selfId
          // This fixes mismatches between padded 32-byte IDs and derived 64-byte IDs
          // Offset 80: PacketHeader.length(16) + PeerId.length(64)
          if (packet.datagram.length >= 144) {
            packet.datagram.setRange(80, 144, _router.selfId.value);
          }
          packet.dstPeerId = _router.selfId;
          await _router.onMessage(packet);
        };
        _router.transports.add(libp2pTransport);
        // Explicitly start the transport
        unawaited(libp2pTransport.start());
      }

      _isInitialized = true;
      _logger.debug('P2plibRouter initialization complete');

      // Setup central protocol dispatcher
      _dispatcherSubscription = _router.messageStream.listen((message) {
        if (!_messageController.isClosed) {
          _messageController.add(message);
        }

        if (message.payload == null || message.payload!.isEmpty) return;

        try {
          var datagram = message.payload!;
          // If payload contains the p2plib header/IDs (144 bytes), skip them.
          // This happens because RouterL1/L2's onMessage unseals the whole datagram
          // and passes it as the payload.
          if (datagram.length > 144) {
            // Check if it looks like a p2plib message (optional but safer)
            // For now, assume if it's long enough, skip the header.
            datagram = datagram.sublist(144);
          }
          // Format: [1 byte protocol length][N bytes protocol ID][Rest: payload]
          if (datagram.isEmpty) {
            _logger.verbose('Dispatcher: Received empty datagram, skipping');
            return;
          }
          final protocolLen = datagram[0];
          if (protocolLen > 0 && protocolLen < datagram.length) {
            final protocolId = utf8.decode(
              datagram.sublist(1, 1 + protocolLen),
            );
            final payload = datagram.sublist(1 + protocolLen);

            _logger.verbose(
              'Dispatcher: Received packet for protocol $protocolId',
            );

            if (_protocolHandlers.containsKey(protocolId)) {
              final packet = NetworkPacket(
                srcPeerId: Base58().encode(message.srcPeerId.value),
                datagram: payload,
              );
              _protocolHandlers[protocolId]!(packet);
            } else {
              _logger.verbose(
                'Dispatcher: No handler for protocol $protocolId',
              );
            }
          } else {
            _logger.verbose(
              'Dispatcher: Received legacy/unwrapped packet (first byte: ${datagram.isNotEmpty ? datagram[0] : "empty"})',
            );
            // DISABLED legacy broadcast to avoid interfering with strict handlers like Bitswap
            /*
            _protocolHandlers.forEach((id, handler) => handler(packet));
            */
          }
        } catch (e) {
          _logger.verbose('Dispatcher: Error processing packet: $e');
          // If unwrapping fails, it might be a raw message
          _logger.verbose(
            'Dispatcher: Failed to unwrap packet, trying raw broadcast',
          );
          final packet = NetworkPacket(
            srcPeerId: Base58().encode(message.srcPeerId.value),
            datagram: message.payload!,
          );
          _protocolHandlers.forEach((id, handler) => handler(packet));
        }
      });
    } catch (e, stackTrace) {
      _logger.error('Error initializing P2plibRouter', e, stackTrace);
      rethrow;
    }
  }

  /// Starts the router.
  Future<void> start() async {
    _logger.debug('Starting router...');

    if (!_isInitialized) {
      _logger.debug('Router not initialized, initializing...');
      await initialize();
    }

    // Only start the router and connect to bootstrap peers once
    if (!_hasStarted) {
      _logger.debug('Starting router...');
      await _router.start();
      _logger.verbose('Router started successfully');

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

        // Check if it's a multiaddr or just a PeerID
        try {
          if (peer.startsWith('/')) {
            await connect(peer);
          } else {
            // Assume just PeerID (Base58)
            // connect() handles parsing.
            await connect(peer);
          }
        } catch (e) {
          _logger.warning(
            'Skipping incompatible bootstrap peer: $peer (Protocol Mismatch)',
          );
        }
      } catch (e, stackTrace) {
        _logger.error('Error adding bootstrap peer: $peer', e, stackTrace);
      }
    }
  }

  /// Stops the router.
  Future<void> stop() async {
    await _dispatcherSubscription?.cancel();
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
      final peerId = p2p.PeerId(
        value: _extractPeerIdFromMultiaddr(multiaddress),
      );
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
    return connectedPeers;
  }

  /// Sends a message to a peer with an optional protocolId for multiplexing.
  /// This ensures the message is correctly wrapped, signed, and encrypted by p2plib.
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    final peer = p2p.PeerId(value: Base58().base58Decode(peerIdStr));

    Uint8List finalPayload = message;
    if (protocolId != null) {
      final protocolBytes = utf8.encode(protocolId);
      final builder = BytesBuilder(copy: false)
        ..addByte(protocolBytes.length)
        ..add(protocolBytes)
        ..add(message);
      finalPayload = builder.toBytes();
    }

    // High-level p2plib sendMessage ensures proper encapsulation, signing, and encryption.
    // L2 messaging is required for the receiver's RouterL1/L2 to accept and verify the packet.
    await _router.sendMessage(dstPeerId: peer, payload: finalPayload);
  }

  /// Receives messages from a specific peer.
  Stream<String> receiveMessages(String peerId) async* {
    // Convert the messageStream to filter messages from specific peer
    await for (final message in _messageController.stream) {
      if (message.srcPeerId.toString() == peerId) {
        final payload = message.payload;
        if (payload != null && payload.isNotEmpty) {
          yield utf8.decode(payload);
        }
      }
    }
  }

  /// Resolves a peer ID to a list of addresses.
  List<String> resolvePeerId(String peerIdStr) {
    try {
      final peerId = p2p.PeerId(value: Base58().base58Decode(peerIdStr));
      return _router
          .resolvePeerId(peerId)
          .map((address) => '${address.address.address}:${address.port}')
          .toList();
    } catch (e) {
      return [];
    }
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
          // Ignore malformed messages
        }
      } else {
        // Received message with null payload, skipping...
      }
    });
  }

  /// Adds a message handler for a specific protocol
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    if (!_registeredProtocols.contains(protocolId)) {
      registerProtocol(protocolId);
    }

    _protocolHandlers[protocolId] = handler;

    // The central dispatcher in initialize() already handles routing messages
    // to these handlers via _protocolHandlers. No need for an additional listener here.
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

    _router.sendDatagram(addresses: fullAddresses, datagram: datagram);
    return Future.value();
  }

  /// Gets the routing table for DHT operations
  RoutingTable getRoutingTable() {
    // Create a new routing table if it doesn't exist
    _routingTable ??= RoutingTable(
      PeerId(value: _router.selfId.value),
      DHTClient(networkHandler: NetworkHandler(_config), router: this),
    );
    return _routingTable!;
  }

  /// Emits a network event with the given topic and data
  Future<void> emitEvent(String topic, Uint8List data) async {
    // Create a network event message
    final eventMessage = NetworkMessage(data);

    // Broadcast to all connected peers
    for (final peerId in connectedPeers) {
      if (!isConnectedPeer(peerId)) continue;

      try {
        await sendMessage(peerId, data);
      } catch (e) {
        // Error sending event to peer
      }
    }

    // Notify local event handlers if registered
    if (_eventHandlers.containsKey(topic)) {
      for (final handler in _eventHandlers[topic]!) {
        handler(eventMessage);
      }
    }
  }

  final Map<String, List<void Function(NetworkMessage)>> _eventHandlers =
      <String, List<void Function(NetworkMessage)>>{};

  /// Registers an event handler for a specific topic
  void onEvent(String topic, void Function(NetworkMessage) handler) {
    _eventHandlers.putIfAbsent(topic, () => []).add(handler);
  }

  /// Removes an event handler for a specific topic
  void offEvent(String topic, void Function(NetworkMessage) handler) {
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
        if (i + 1 < parts.length) {
          ipAddress = parts[i + 1];
        }
      } else if (parts[i] == 'tcp' || parts[i] == 'udp') {
        if (i + 1 < parts.length) {
          port = int.tryParse(parts[i + 1]);
        }
      }
    }

    // Default to localhost/defaultPort if parsing fails
    ipAddress ??= '127.0.0.1';
    port ??= p2p.TransportUdp.defaultPort;

    return p2p.FullAddress(address: InternetAddress(ipAddress), port: port);
  }

  /// Extracts the peer ID from a multiaddress string
  Uint8List _extractPeerIdFromMultiaddr(String multiaddr) {
    final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();
    final peerIdIndex = parts.indexOf('p2p') + 1;
    if (peerIdIndex >= parts.length) {
      throw FormatException('No peer ID found in multiaddr: $multiaddr');
    }
    final decoded = Base58().base58Decode(parts[peerIdIndex]);
    if (decoded.length == 32) {
      // Pad 32-byte ID to 64 bytes by repeating it.
      // This matches how p2plib LocalCrypto usually works when same key is used for both.
      final padded = Uint8List(64);
      padded.setRange(0, 32, decoded);
      padded.setRange(32, 64, decoded);
      return padded;
    }
    return decoded;
  }

  // Add to P2plibRouter class
  /// Checks if a peer is currently connected and active.
  bool isConnectedPeer(String peerIdStr) {
    // Convert string to PeerId for internal checks
    p2p.PeerId peerId;
    try {
      peerId = p2p.PeerId(value: Base58().base58Decode(peerIdStr));
    } catch (e) {
      return false;
    }

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
    if (DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(route.lastSeen),
        ) >
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

  /// Gets the underlying RouterL2 instance
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
      // Create a completer to handle the async response
      final completer = Completer<Uint8List>();
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add request ID to message
      final messageWithId = Uint8List.fromList([
        ...request,
        ...utf8.encode(requestId),
      ]);

      // Set up one-time response handler
      registerProtocolHandler(protocolId, (packet) {
        if (packet.srcPeerId == peerId &&
            _extractRequestId(packet.datagram) == requestId) {
          removeMessageHandler(protocolId);
          completer.complete(packet.datagram);
        }
      });

      // Send the request
      await sendMessage(peerId, messageWithId, protocolId: protocolId);

      // Wait for response with timeout
      return await completer.future.timeout(
        const Duration(seconds: 30),
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
      final requestIdBytes = datagram.sublist(
        datagram.length - 13,
      ); // Timestamp is 13 chars
      return utf8.decode(requestIdBytes);
    } catch (e) {
      _logger.error('Error extracting request ID', e);
      return '';
    }
  }

  /// The local node's PeerID.
  p2p.PeerId get localPeerId => _router.selfId;

  /// Broadcasts a [message] to all connected peers using the given [protocolId].
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {
    if (!_registeredProtocols.contains(protocolId)) {
      throw Exception('Protocol $protocolId not registered');
    }

    final failures = <String>[];

    // Broadcast to all connected peers
    for (final peerId in _connectedPeers) {
      if (!isConnectedPeer(peerId.toString())) continue;

      try {
        await sendMessage(peerId.toString(), message);
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to send message to peer ${peerId.toString()}',
          e,
          stackTrace,
        );
        failures.add(peerId.toString());
      }
    }

    if (failures.isNotEmpty) {
      _errorEventsController.add(
        ErrorEvent(
          type: ErrorEventType.messageError,
          message: 'Failed to broadcast to peers: ${failures.join(", ")}',
        ),
      );
    }
  }
}
