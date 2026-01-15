// lib/src/transport/libp2p_router.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_libp2p/config/config.dart' as config;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as crypto;
import 'package:dart_libp2p/dart_libp2p.dart' as libp2p;
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';

/// Native libp2p router implementation.
///
/// Uses dart_libp2p directly for P2P networking with standard IPFS protocols:
/// - Ed25519 for identity (no legacy secp256k1 workarounds)
/// - Noise protocol for encryption
/// - TCP transport
///
/// This implements [RouterInterface] and provides standard IPFS networking.
class Libp2pRouter implements RouterInterface {
  /// Creates a Libp2pRouter with the given configuration.
  Libp2pRouter(this._config, {Uint8List? seed}) : _seed = seed {
    _logger = Logger(
      'Libp2pRouter',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }

  final IPFSConfig _config;
  final Uint8List? _seed;
  late final Logger _logger;

  libp2p.Host? _host;
  libp2p.KeyPair? _keyPair;
  bool _hasStarted = false;
  bool _isInitialized = false;

  final Set<String> _connectedPeers = {};
  final Set<String> _registeredProtocols = {};
  final Map<String, void Function(NetworkPacket)> _protocolHandlers = {};
  final Map<String, List<void Function(dynamic)>> _eventHandlers = {};
  final Map<String, StreamController<Uint8List>> _peerMessageStreams = {};

  // Stream controllers for events
  final _messagePacketController = StreamController<NetworkPacket>.broadcast();
  final _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();
  final _messageEventsController = StreamController<MessageEvent>.broadcast();

  @override
  String get peerID {
    if (_host != null) return _host!.id.toString();
    if (_keyPair != null) {
      return libp2p.PeerId.fromPublicKey(_keyPair!.publicKey).toString();
    }
    return '';
  }

  @override
  bool get hasStarted => _hasStarted;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Set<String> get connectedPeers => _connectedPeers;

  @override
  List<String> get listeningAddresses => _config.network.listenAddresses;

  @override
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  @override
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;

  @override
  Stream<Uint8List> receiveMessages(String peerId) {
    return _peerMessageStreams
        .putIfAbsent(peerId, () => StreamController<Uint8List>.broadcast())
        .stream;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.warning('Libp2pRouter already initialized');
      return;
    }

    _logger.debug('Initializing Libp2pRouter...');

    try {
      // Generate or derive key pair
      if (_seed != null) {
        _logger.debug('Deriving Ed25519 identity from seed');
        _keyPair = await crypto.generateEd25519KeyPairFromSeed(_seed);
      } else {
        _logger.debug('Generating new Ed25519 identity');
        _keyPair = await crypto.generateEd25519KeyPair();
      }

      _isInitialized = true;
      _logger.debug('Libp2pRouter initialized with identity');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Libp2pRouter', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    if (_hasStarted) {
      _logger.warning('Libp2pRouter already started');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    _logger.debug('Starting Libp2pRouter...');

    try {
      // Determine listen address from config
      int port = 4001; // Default IPFS port
      for (final addr in _config.network.listenAddresses) {
        final parts = addr.split('/');
        final tcpIndex = parts.indexOf('tcp');
        if (tcpIndex != -1 && tcpIndex + 1 < parts.length) {
          port = int.tryParse(parts[tcpIndex + 1]) ?? port;
          break;
        }
      }

      final listenAddr = libp2p.MultiAddr('/ip4/0.0.0.0/tcp/$port');
      final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());

      _host = await config.Libp2p.new_([
        ..._buildTransports(resourceManager),
        config.Libp2p.listenAddrs([listenAddr]),
        config.Libp2p.identity(_keyPair!),
        config.Libp2p.userAgent('dart_ipfs/1.9.0'),
      ]);

      await _host!.start();

      // Listen for connection events to maintain _connectedPeers
      _host!.network.notify(
        libp2p.NotifyBundle(
          connectedF: (net, conn) {
            final remotePeerId = conn.remotePeer.toString();
            _connectedPeers.add(remotePeerId);
            _connectionEventsController.add(
              ConnectionEvent(
                peerId: remotePeerId,
                type: ConnectionEventType.connected,
              ),
            );
            _logger.debug('Peer connected: $remotePeerId');
          },
          disconnectedF: (net, conn) {
            final remotePeerId = conn.remotePeer.toString();
            _connectedPeers.remove(remotePeerId);
            _connectionEventsController.add(
              ConnectionEvent(
                peerId: remotePeerId,
                type: ConnectionEventType.disconnected,
              ),
            );
            _logger.debug('Peer disconnected: $remotePeerId');
          },
        ),
      );

      _hasStarted = true;
      _logger.info('Libp2pRouter started on $listenAddr with ID: ${_host!.id}');

      // Connect to bootstrap peers
      await _connectToBootstrapPeers();
    } catch (e, stackTrace) {
      _logger.error('Failed to start Libp2pRouter', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _connectToBootstrapPeers() async {
    for (final peer in _config.network.bootstrapPeers) {
      try {
        await connect(peer);
      } catch (e) {
        _logger.warning('Failed to connect to bootstrap peer $peer: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    if (!_hasStarted) {
      _logger.warning('Libp2pRouter already stopped');
      return;
    }

    _logger.debug('Stopping Libp2pRouter...');

    try {
      unawaited(_host?.close());
      _connectedPeers.clear();
      _hasStarted = false;
      await _messagePacketController.close();
      _logger.info('Libp2pRouter stopped');
    } catch (e, stackTrace) {
      _logger.error('Error stopping Libp2pRouter', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> connect(String multiaddress) async {
    _checkStarted();

    try {
      _logger.debug('Connecting to $multiaddress');

      // Extract peer ID from multiaddress
      final peerIdStr = _extractPeerIdFromMultiaddr(multiaddress);
      if (peerIdStr == null) {
        throw ArgumentError('Multiaddress must contain /p2p/<peerId>');
      }

      // Strip the /p2p/<id> suffix for the transport address
      final transportAddrStr = multiaddress.split('/p2p/')[0];
      final addr = libp2p.MultiAddr(transportAddrStr);
      final peerId = libp2p.PeerId.fromString(peerIdStr);

      // Explicitly add address to peer store to ensure dial can find it
      await _host!.peerStore.addrBook.addAddrs(peerId, [
        addr,
      ], const Duration(minutes: 10));

      final addrInfo = libp2p.AddrInfo(peerId, [addr]);
      await _host!.connect(addrInfo);

      // _connectedPeers is updated via NotifyBundle in start()
      _logger.debug('Connected to peer $peerIdStr');
    } catch (e) {
      _logger.error('Failed to connect to $multiaddress', e);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    _checkStarted();

    final peerId = peerIdOrMultiaddress.contains('/p2p/')
        ? _extractPeerIdFromMultiaddr(peerIdOrMultiaddress)
        : peerIdOrMultiaddress;

    if (peerId != null) {
      _connectedPeers.remove(peerId);
      _logger.debug('Disconnected from $peerId');
    }
  }

  @override
  List<String> listConnectedPeers() => _connectedPeers.toList();

  @override
  bool isConnectedPeer(String peerIdStr) => _connectedPeers.contains(peerIdStr);

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    _checkStarted();

    final protocol = protocolId ?? '/ipfs/1.0.0';
    _logger.verbose('Sending message to $peerIdStr via protocol $protocol');

    try {
      final peerId = libp2p.PeerId.fromString(peerIdStr);
      final context = libp2p.Context(timeout: const Duration(seconds: 15));
      final stream = await _host!.newStream(peerId, [protocol], context);

      // Write length-prefixed message
      final lengthPrefix = _encodeLengthPrefix(message.length);
      await stream.write(Uint8List.fromList([...lengthPrefix, ...message]));
      await stream.close();

      _logger.verbose('Message sent successfully to $peerIdStr');
    } catch (e) {
      _logger.error('Failed to send message to $peerIdStr', e);
      rethrow;
    }
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    _checkStarted();

    try {
      final pid = libp2p.PeerId.fromString(peerId);
      final context = libp2p.Context(timeout: const Duration(seconds: 15));
      final stream = await _host!.newStream(pid, [protocolId], context);

      // Write request
      final lengthPrefix = _encodeLengthPrefix(request.length);
      await stream.write(Uint8List.fromList([...lengthPrefix, ...request]));

      // Read response
      final response = await _readLengthPrefixedMessage(stream);
      await stream.close();

      return response;
    } catch (e) {
      _logger.error('Request to $peerId failed', e);
      return null;
    }
  }

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _protocolHandlers[protocolId] = handler;
    _registeredProtocols.add(protocolId);

    if (_host != null) {
      _host!.setStreamHandler(protocolId, (stream, remotePeerId) async {
        try {
          final data = await _readLengthPrefixedMessage(stream);
          if (data != null) {
            final packet = NetworkPacket(
              srcPeerId: remotePeerId.toString(),
              datagram: data,
              responder: (response) async {
                final lengthPrefix = _encodeLengthPrefix(response.length);
                await stream.write(
                  Uint8List.fromList([...lengthPrefix, ...response]),
                );
              },
            );
            handler(packet);
            _messagePacketController.add(packet);
          }
        } catch (e) {
          _logger.error('Error handling stream for $protocolId', e);
        }
      });
    }

    _logger.debug('Registered protocol handler for $protocolId');
  }

  @override
  void removeMessageHandler(String protocolId) {
    _protocolHandlers.remove(protocolId);
    _logger.debug('Removed protocol handler for $protocolId');
  }

  @override
  void registerProtocol(String protocolId) {
    _registeredProtocols.add(protocolId);
    _logger.debug('Registered protocol $protocolId');
  }

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {
    _checkStarted();

    for (final peerId in _connectedPeers) {
      try {
        await sendMessage(peerId, message, protocolId: protocolId);
      } catch (e) {
        _logger.warning('Failed to broadcast to $peerId: $e');
      }
    }
  }

  @override
  void emitEvent(String topic, Uint8List data) {
    final handlers = _eventHandlers[topic];
    if (handlers != null) {
      for (final handler in handlers) {
        handler(NetworkMessage(data));
      }
    }
  }

  @override
  void onEvent(String topic, void Function(dynamic) handler) {
    _eventHandlers.putIfAbsent(topic, () => []).add(handler);
  }

  @override
  void offEvent(String topic, void Function(dynamic) handler) {
    _eventHandlers[topic]?.remove(handler);
  }

  @override
  dynamic parseMultiaddr(String multiaddr) {
    try {
      return libp2p.MultiAddr(multiaddr);
    } catch (e) {
      _logger.warning('Failed to parse multiaddr: $multiaddr');
      return null;
    }
  }

  @override
  List<String> resolvePeerId(String peerIdStr) {
    // standard libp2p doesn't have a built-in peer resolution cache here.
    // Return empty for now - DHT can be used for resolution
    return [];
  }

  // Helper methods

  void _checkStarted() {
    if (!_hasStarted) {
      throw StateError('Libp2pRouter not started');
    }
  }

  String? _extractPeerIdFromMultiaddr(String multiaddr) {
    final parts = multiaddr.split('/');
    final p2pIndex = parts.indexOf('p2p');
    if (p2pIndex != -1 && p2pIndex + 1 < parts.length) {
      return parts[p2pIndex + 1];
    }
    return null;
  }

  Uint8List _encodeLengthPrefix(int length) {
    // Simple varint encoding for length prefix
    final result = <int>[];
    var n = length;
    while (n >= 0x80) {
      result.add((n & 0x7F) | 0x80);
      n >>= 7;
    }
    result.add(n);
    return Uint8List.fromList(result);
  }

  Future<Uint8List?> _readLengthPrefixedMessage(
    libp2p.P2PStream<dynamic> stream,
  ) async {
    // Read varint length prefix
    final lengthBytes = <int>[];
    while (true) {
      final byte = await _readByte(stream);
      if (byte == null) return null;
      lengthBytes.add(byte);
      if ((byte & 0x80) == 0) break;
    }

    final length = _decodeVarint(Uint8List.fromList(lengthBytes));
    if (length == 0) return Uint8List(0);

    // Read message body
    final result = <int>[];
    for (var i = 0; i < length; i++) {
      final byte = await _readByte(stream);
      if (byte == null) return null;
      result.add(byte);
    }

    return Uint8List.fromList(result);
  }

  Future<int?> _readByte(libp2p.P2PStream<dynamic> stream) async {
    try {
      final data = await stream.read(1);
      if (data.isEmpty) return null;
      return data[0];
    } catch (e) {
      return null;
    }
  }

  int _decodeVarint(Uint8List bytes) {
    var result = 0;
    var shift = 0;
    for (final byte in bytes) {
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  /// Builds a list of libp2p transports based on configuration.
  ///
  /// Currently supports TCP. Phase 1 will expand this to include
  /// WebTransport and WebRTC.
  List<config.Option> _buildTransports(libp2p.ResourceManager resourceManager) {
    final transports = <config.Option>[];

    // Always include TCP for now (standard IPFS / Amino compatibility)
    transports.add(
      config.Libp2p.transport(TCPTransport(resourceManager: resourceManager)),
    );

    // TODO: Add WebTransport and WebRTC based on config (Phase 1)
    /*
    if (_config.network.useWebTransport) {
      transports.add(config.Libp2p.transport(WebTransport()));
    }
    */

    return transports;
  }
}
