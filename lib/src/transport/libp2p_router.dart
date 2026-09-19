// lib/src/transport/libp2p_router.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ipfs_libp2p/config/config.dart' as config;
import 'package:ipfs_libp2p/core/crypto/ed25519.dart' as crypto;
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:ipfs_libp2p/p2p/transport/tcp_transport.dart';
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_transport;
import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart';

import '../core/config/ipfs_config.dart';
import '../core/crypto/ecdsa_signer.dart';
import '../core/crypto/rsa_signer.dart';
import '../platform/platform.dart';
import '../protocols/dht/dht_routing_table_interface.dart';
import '../utils/logger.dart';
import '../version.dart';
import 'inbound_message_bounds.dart' as inbound;
import 'pnet/pnet_transport_wrapper.dart';
import 'pnet/swarm_key_loader.dart';
import 'quic_transport_probe.dart'
    if (dart.library.html) 'quic_transport_probe_web.dart'
    as quic_probe;
import 'router_interface.dart';
import 'webrtc/signaling_protocol.dart';
import 'webrtc/webrtc_direct_transport.dart';
import 'webrtc/webrtc_transport.dart';
import 'webtransport/webtransport_transport.dart';

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
  ///
  /// [_config] - The IPFS configuration.
  /// [seed] - Optional seed for generating the peer identity.
  Libp2pRouter(this._config, {Uint8List? seed}) : _seed = seed {
    _logger = Logger(
      'Libp2pRouter',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }

  final IPFSConfig _config;
  final Uint8List? _seed;
  Uint8List? _identitySeed;
  late final Logger _logger;

  libp2p.Host? _host;
  libp2p.KeyPair? _keyPair;
  bool _hasStarted = false;
  bool _isInitialized = false;
  libp2p_transport.Transport? _quicTransport;

  /// Key type for peer identity (ed25519, rsa, ecdsa).
  final String _keyType = 'ed25519';

  /// Test-only factory override for the QUIC transport dependency.
  ///
  /// When non-null, [supportsQuic] and address synthesis use this factory
  /// instead of probing the actual `package:ipfs_libp2p` dependency.
  static libp2p_transport.Transport? Function()? _quicTransportFactory;

  /// Set the QUIC transport factory used for testing.
  ///
  /// Passing `null` clears any override and restores the runtime probe.
  static void setQuicTransportFactoryForTesting(
    libp2p_transport.Transport? Function()? factory,
  ) {
    _quicTransportFactory = factory;
  }

  final Set<String> _connectedPeers = {};
  final Map<String, List<String>> _peerAddresses = {};
  final Set<String> _registeredProtocols = {};
  final Map<String, void Function(NetworkPacket)> _protocolHandlers = {};
  final Map<String, List<void Function(dynamic)>> _eventHandlers = {};
  final Map<String, StreamController<Uint8List>> _peerMessageStreams = {};

  // DHT routing table for distance-based peer selection
  DHTRoutingTable? _dhtRoutingTable;

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

  /// The underlying libp2p host, available after [start] completes.
  ///
  /// Exposed for protocol handlers (e.g. DCUtR) that need direct access to
  /// host services such as the hole-punch service.
  libp2p.Host? get host => _host;

  /// Raw public key bytes of this node's identity, or null before
  /// [initialize] has derived the key pair.
  Uint8List? get identityPublicKeyBytes {
    final keyPair = _keyPair;
    if (keyPair == null) return null;
    return Uint8List.fromList(keyPair.publicKey.raw);
  }

  /// Marshalled peer ID bytes of this node's identity, or null before
  /// [initialize] has derived the key pair.
  Uint8List? get peerIdBytes {
    final keyPair = _keyPair;
    if (keyPair == null) return null;
    return libp2p.PeerId.fromPublicKey(keyPair.publicKey).toBytes();
  }

  /// The seed backing this node's identity (32 bytes for Ed25519), or null
  /// when the identity is ephemeral or not seed-derived.
  ///
  /// Exposed so node services (e.g. PubSub signing) can reconstruct the same
  /// identity key material under `package:cryptography` types.
  Uint8List? get identitySeed {
    final seed = _identitySeed;
    if (seed == null) return null;
    return Uint8List.fromList(seed);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Set<String> get connectedPeers => _connectedPeers;

  @override
  List<String> get listeningAddresses {
    if (_hasStarted && _host != null) {
      return _host!.network.listenAddresses.map((a) => a.toString()).toList();
    }
    return _buildListenAddresses().map((a) => a.toString()).toList();
  }

  /// True when the QUIC transport is enabled in config and available at runtime.
  ///
  /// This is `false` when [NetworkConfig.enableQuic] is false, or when the
  /// current `package:ipfs_libp2p` dependency does not expose a QUIC transport
  /// class (the current state for ipfs_libp2p 0.5.6, which only ships UDX and
  /// TCP transports).
  bool get supportsQuic => _config.network.enableQuic && _quicTransport != null;

  /// True when the current platform provides working backends for the
  /// browser-based transports (WebTransport, WebRTC, and WebRTC-direct).
  ///
  /// These transports rely on browser APIs, so on platforms without a
  /// backend (such as the Dart VM/IO platform) the `enableWebTransport` and
  /// `enableWebRtc` flags are ignored and the transports are skipped at
  /// startup instead of being registered as stubs that throw
  /// `TransportUnavailableException` on use.
  bool get supportsBrowserTransports {
    final override = _browserTransportsSupportedOverride;
    if (override != null) return override;
    try {
      return getPlatform().isWeb;
    } catch (_) {
      // No platform implementation resolved; there is no usable backend.
      return false;
    }
  }

  /// Test-only override for the browser-transport platform check.
  ///
  /// When non-null, [supportsBrowserTransports] returns this value instead
  /// of probing the platform, allowing tests to exercise both the
  /// registration and the skip paths.
  static bool? _browserTransportsSupportedOverride;

  /// Sets the browser-transport availability override used for testing.
  ///
  /// Passing `null` clears any override and restores platform detection.
  static void setBrowserTransportsSupportedForTesting(bool? supported) {
    _browserTransportsSupportedOverride = supported;
  }

  @override
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  @override
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;

  @override
  DHTRoutingTable? get dhtRoutingTable => _dhtRoutingTable;

  /// Sets the DHT routing table for distance-based peer selection.
  ///
  /// This should be called by the DHT protocol handler when it initializes
  /// its routing table, allowing the router to expose it via the interface.
  void setDHTRoutingTable(DHTRoutingTable routingTable) {
    _dhtRoutingTable = routingTable;
    _logger.debug('DHT routing table set on router');
  }

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
      // Generate or derive key pair based on key type
      if (_seed != null) {
        _logger.debug('Deriving $_keyType identity from seed');
        _identitySeed = _seed;
        _keyPair = await _generateKeyPairFromSeed(_seed);
      } else {
        // Without an explicit seed, reuse the persisted identity seed so the
        // peer ID is stable across restarts (Kubo 'ipfs init' semantics).
        final persistedSeed = await _loadOrCreateIdentitySeed();
        if (persistedSeed != null) {
          _identitySeed = persistedSeed;
          _keyPair = await _generateKeyPairFromSeed(persistedSeed);
        } else {
          _logger.debug('Generating new $_keyType identity');
          _keyPair = await _generateKeyPair();
        }
      }

      // Probe for an available QUIC transport from the libp2p dependency.
      // This is done during initialization so that [supportsQuic] is stable
      // before [start()] builds the listen-address list.
      _quicTransport = await _probeQuicTransport();

      _isInitialized = true;
      _logger.debug('Libp2pRouter initialized with identity: $peerID');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Libp2pRouter', e, stackTrace);
      throw StateError('Router initialization failed: $e');
    }
  }

  /// Loads the persisted identity seed, generating and storing one on first
  /// start.
  ///
  /// Returns `null` when persistence is unavailable (web platform or I/O
  /// failure); the caller then falls back to an ephemeral identity.
  Future<Uint8List?> _loadOrCreateIdentitySeed() async {
    final platform = getPlatform();
    if (platform.isWeb) return null;

    final seedPath = '${_config.dataPath}/identity';
    try {
      if (await platform.exists(seedPath)) {
        final encoded = (await platform.readString(seedPath))?.trim();
        if (encoded != null && encoded.isNotEmpty) {
          try {
            final seed = base64Decode(encoded);
            if (seed.length == 32) {
              _logger.debug('Loaded persisted identity seed from $seedPath');
              return Uint8List.fromList(seed);
            }
          } on FormatException {
            // Malformed file: fall through and replace it below.
          }
          _logger.warning('Replacing malformed identity seed at $seedPath');
        }
      }

      // First start: generate a fresh seed and persist it so subsequent
      // launches derive the same peer identity.
      final seed = Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await platform.writeStringRestricted(seedPath, base64Encode(seed));
      _logger.debug('Persisted new identity seed to $seedPath');
      return seed;
    } catch (e) {
      _logger.warning('Identity seed persistence unavailable: $e');
      return null;
    }
  }

  /// Generates a key pair based on the configured key type.
  Future<libp2p.KeyPair> _generateKeyPair() async {
    switch (_keyType.toLowerCase()) {
      case 'rsa':
        _logger.warning(
          'RSA keys not directly supported by ipfs_libp2p, using Ed25519',
        );
        return await crypto.generateEd25519KeyPair();
      case 'ecdsa':
        _logger.warning(
          'ECDSA keys not directly supported by ipfs_libp2p, using Ed25519',
        );
        return await crypto.generateEd25519KeyPair();
      case 'ed25519':
      default:
        return await crypto.generateEd25519KeyPair();
    }
  }

  /// Derives a key pair from a seed based on the configured key type.
  Future<libp2p.KeyPair> _generateKeyPairFromSeed(Uint8List seed) async {
    switch (_keyType.toLowerCase()) {
      case 'rsa':
        _logger.warning(
          'RSA keys not directly supported by ipfs_libp2p, using Ed25519',
        );
        return await crypto.generateEd25519KeyPairFromSeed(seed);
      case 'ecdsa':
        _logger.warning(
          'ECDSA keys not directly supported by ipfs_libp2p, using Ed25519',
        );
        return await crypto.generateEd25519KeyPairFromSeed(seed);
      case 'ed25519':
      default:
        return await crypto.generateEd25519KeyPairFromSeed(seed);
    }
  }

  /// Derives a peer ID from an RSA public key.
  ///
  /// This is a utility method for interoperability with peers using RSA keys.
  /// The router itself uses Ed25519, but can validate RSA peer IDs from other peers.
  String derivePeerIdFromRSA(RSAPublicKey publicKey) {
    final signer = RsaSigner();
    return signer.derivePeerId(publicKey);
  }

  /// Derives a peer ID from an ECDSA public key.
  ///
  /// This is a utility method for interoperability with peers using ECDSA keys.
  /// The router itself uses Ed25519, but can validate ECDSA peer IDs from other peers.
  String derivePeerIdFromECDSA(ECPublicKey publicKey) {
    final signer = EcdsaSigner();
    return signer.derivePeerId(publicKey);
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
      final psk = await _loadPrivateNetworkPsk();
      if (psk != null) {
        _logger.info(
          'Private network PNET pre-shared key loaded; TCP transport will be wrapped',
        );
      } else {
        _logger.info(
          'No private network PNET key configured; using public TCP',
        );
      }

      final listenAddresses = _buildListenAddresses();
      final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());

      // Assemble transports. TCP is always present; QUIC is added only when
      // enabled and the dependency actually exposes a transport class.
      final tcpTransport = TCPTransport(resourceManager: resourceManager);
      final wrappedTcpTransport = psk != null
          ? PnetTransportWrapper(inner: tcpTransport, psk: psk)
          : tcpTransport;
      final transports = <config.Option>[
        config.Libp2p.transport(wrappedTcpTransport),
      ];

      if (_config.network.enableQuic) {
        if (supportsQuic) {
          _logger.debug('Adding QUIC transport to Libp2p host');
          transports.add(config.Libp2p.transport(_quicTransport!));
        } else {
          _logger.warning(
            'QUIC enabled but no QUIC transport is available in '
            'package:ipfs_libp2p; falling back to TCP-only mode.',
          );
        }
      }

      // The WebTransport/WebRTC transports are browser-based and only have
      // working backends on the web platform. On platforms without a backend
      // they are skipped even when enabled so that the default-on flags do
      // not register stubs that throw TransportUnavailableException on use.
      WebRTCTransport? webrtcTransport;

      if (_config.network.enableWebTransport) {
        if (supportsBrowserTransports) {
          transports.add(config.Libp2p.transport(WebTransportTransport()));
        } else {
          _logger.info(
            'WebTransport enabled but no backend exists on this platform; '
            'skipping transport registration.',
          );
        }
      }
      if (_config.network.enableWebRtc) {
        if (supportsBrowserTransports) {
          webrtcTransport = WebRTCTransport(networkConfig: _config.network);
          transports.add(config.Libp2p.transport(webrtcTransport));
          transports.add(
            config.Libp2p.transport(
              WebRTCDirectTransport(networkConfig: _config.network),
            ),
          );
        } else {
          _logger.info(
            'WebRTC enabled but no backend exists on this platform; '
            'skipping transport registration.',
          );
        }
      }

      _host = await config.Libp2p.new_([
        ...transports,
        config.Libp2p.listenAddrs(listenAddresses),
        config.Libp2p.identity(_keyPair!),
        config.Libp2p.userAgent(agentVersion),
      ]);

      // Wire up the WebRTC host dependency and register the signaling
      // protocol only when the transport was actually registered.
      if (webrtcTransport != null) {
        webrtcTransport.host = _host;
        SignalingProtocol.register(this);
      }

      await _host!.start();

      // Listen for connection events to maintain _connectedPeers
      _host!.network.notify(
        libp2p.NotifyBundle(
          connectedF: (net, conn, {dialLatency}) {
            final remotePeerId = conn.remotePeer.toString();
            _connectedPeers.add(remotePeerId);
            try {
              _peerAddresses[remotePeerId] = [conn.remoteMultiaddr.toString()];
            } catch (_) {
              // Remote address may not always be available.
            }
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
            _peerAddresses.remove(remotePeerId);
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

      // Attach any protocol handlers registered before the host existed.
      for (final protocolId in _protocolHandlers.keys.toList()) {
        _attachStreamHandler(protocolId);
      }

      _hasStarted = true;
      _logger.info(
        'Libp2pRouter started on ${listenAddresses.first} with ID: ${_host!.id}',
      );

      // Connect to bootstrap peers
      await _connectToBootstrapPeers();
    } catch (e, stackTrace) {
      _logger.error('Failed to start Libp2pRouter', e, stackTrace);
      throw StateError('Router failed to start: $e');
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
      if (_host != null) {
        await _host!.close().timeout(
          const Duration(seconds: 5),
          onTimeout: () => _logger.warning('Host close timed out'),
        );
        // Clear the reference so nothing attaches handlers to the closed
        // host between stop() and the next start().
        _host = null;
      }
      _connectedPeers.clear();
      _hasStarted = false;

      // Close per-peer stream controllers. The long-lived event controllers
      // stay open: they are `final`, emit nothing while stopped, and must
      // keep working if the router is started again.
      final controllers = [..._peerMessageStreams.values];

      for (final controller in controllers) {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
      _peerMessageStreams.clear();

      _logger.info('Libp2pRouter stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Error stopping Libp2pRouter', e, stackTrace);
      // Don't rethrow here to allow cleanup to continue in other components
    }
  }

  @override
  Future<void> connect(String multiaddress) async {
    _checkStarted();

    _logger.debug('Connecting to $multiaddress');

    // Extract peer ID from multiaddress
    final peerIdStr = _extractPeerIdFromMultiaddr(multiaddress);
    if (peerIdStr == null) {
      throw ArgumentError(
        'Multiaddress must contain /p2p/<peerId>: $multiaddress',
      );
    }

    // Strip the /p2p/<id> suffix for the transport address
    final transportAddrStr = multiaddress.split('/p2p/')[0];
    final addr = libp2p.MultiAddr(transportAddrStr);
    final peerId = libp2p.PeerId.fromString(peerIdStr);

    // Snapshot the peer's previously known addresses. Host.connect seeds the
    // addrbook with the supplied address to perform the dial; if the
    // handshake fails, that unverified address must not persist — otherwise
    // any caller (e.g. an AutoNAT dialback request) could poison the
    // addrbook with arbitrary addresses for this peer.
    final priorAddrs = await _host!.peerStore.addrBook.addrs(peerId);

    try {
      final addrInfo = libp2p.AddrInfo(peerId, [addr]);
      await _host!
          .connect(addrInfo)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Connection to $multiaddress timed out'),
          );

      _connectedPeers.add(peerIdStr);
      _peerAddresses[peerIdStr] = [multiaddress];
      _logger.debug('Connected to peer $peerIdStr');
    } catch (e, stackTrace) {
      // The dial failed: undo the addrbook seeding performed during
      // Host.connect and restore only addresses learned from verified
      // handshakes.
      try {
        await _host!.peerStore.addrBook.clearAddrs(peerId);
        if (priorAddrs.isNotEmpty) {
          await _host!.peerStore.addrBook.addAddrs(
            peerId,
            priorAddrs,
            const Duration(minutes: 10),
          );
        }
      } catch (restoreError) {
        _logger.warning(
          'Failed to restore addrbook for $peerIdStr after failed dial: '
          '$restoreError',
        );
      }
      _logger.error('Failed to connect to $multiaddress', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    _checkStarted();

    final peerIdStr = peerIdOrMultiaddress.contains('/p2p/')
        ? _extractPeerIdFromMultiaddr(peerIdOrMultiaddress)
        : peerIdOrMultiaddress;

    if (peerIdStr != null) {
      try {
        // libp2p Host doesn't have a direct 'disconnect' for PeerId,
        // usually handled via Connection Manager or closing streams.
        // We remove it from our tracked set.
        _connectedPeers.remove(peerIdStr);

        // Close the peer's message stream controller to emit done event.
        final controller = _peerMessageStreams.remove(peerIdStr);
        if (controller != null) {
          await controller.close();
        }

        _logger.debug('Disconnected from $peerIdStr');
      } catch (e) {
        _logger.warning('Error while disconnecting from $peerIdStr: $e');
      }
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

      try {
        // Write length-prefixed message
        final lengthPrefix = _encodeLengthPrefix(message.length);
        await stream.write(Uint8List.fromList([...lengthPrefix, ...message]));
      } finally {
        await stream.close();
      }

      _logger.verbose('Message sent successfully to $peerIdStr');
    } catch (e, stackTrace) {
      _logger.error('Failed to send message to $peerIdStr', e, stackTrace);
      throw NetworkException('Failed to send message: $e');
    }
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    _checkStarted();

    _logger.verbose('Sending request to $peerId via $protocolId');
    try {
      final pid = libp2p.PeerId.fromString(peerId);
      final context = libp2p.Context(timeout: const Duration(seconds: 15));
      final stream = await _host!.newStream(pid, [protocolId], context);

      try {
        // Write request
        final lengthPrefix = _encodeLengthPrefix(request.length);
        await stream.write(Uint8List.fromList([...lengthPrefix, ...request]));

        // Read response
        final response = await _readLengthPrefixedMessage(stream);
        return response;
      } finally {
        await stream.close();
      }
    } catch (e, stackTrace) {
      _logger.error('Request to $peerId failed', e, stackTrace);
      return null;
    }
  }

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    _checkStarted();

    final protocol = protocolId ?? '/ipfs/1.0.0';
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);

    _logger.verbose('Sending message with response to $peerId via $protocol');
    try {
      final pid = libp2p.PeerId.fromString(peerId);
      final context = libp2p.Context(timeout: effectiveTimeout);
      final stream = await _host!.newStream(pid, [protocol], context);

      try {
        // Write request
        final lengthPrefix = _encodeLengthPrefix(message.length);
        await stream.write(Uint8List.fromList([...lengthPrefix, ...message]));

        // Read response
        final response = await _readLengthPrefixedMessage(stream);
        if (response == null) {
          throw TimeoutException('No response received from $peerId');
        }
        return response;
      } finally {
        await stream.close();
      }
    } catch (e, stackTrace) {
      _logger.error('Message with response to $peerId failed', e, stackTrace);
      rethrow;
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
      _attachStreamHandler(protocolId);
    }

    _logger.debug('Registered protocol handler for $protocolId');
  }

  /// Wires [protocolId] into the live libp2p host so inbound streams dispatch
  /// to the registered handler. Called from [registerProtocolHandler] when the
  /// host already exists, and replayed for all registered handlers after the
  /// host is created in [start].
  void _attachStreamHandler(String protocolId) {
    final handler = _protocolHandlers[protocolId];
    final host = _host;
    if (handler == null || host == null) return;

    host.setStreamHandler(protocolId, (stream, remotePeerId) async {
      final remoteIdStr = remotePeerId.toString();
      _logger.verbose(
        'Incoming stream from $remoteIdStr for protocol $protocolId',
      );

      Future<void> respond(Uint8List response) async {
        try {
          final lengthPrefix = _encodeLengthPrefix(response.length);
          await stream.write(
            Uint8List.fromList([...lengthPrefix, ...response]),
          );
        } catch (e) {
          _logger.error('Failed to send response to $remoteIdStr', e);
        }
      }

      final streamDeadline = DateTime.now().add(_maxStreamLifetime);
      try {
        // Some protocols (e.g. libp2p identify) speak response-first: the
        // dialer opens the stream and waits without sending a request.
        // Dispatch a synthetic empty packet so the handler can respond;
        // the read loop still runs for peers that send follow-ups.
        if (_respondFirstProtocols.contains(protocolId)) {
          final packet = NetworkPacket(
            srcPeerId: remoteIdStr,
            datagram: Uint8List(0),
            responder: respond,
          );
          handler(packet);
          _messagePacketController.add(packet);
        }

        // Some protocols (e.g. Bitswap) send multiple length-prefixed
        // messages on a single stream, so read until the stream is closed.
        while (true) {
          if (DateTime.now().isAfter(streamDeadline)) {
            _logger.warning(
              'Closing stream from $remoteIdStr on $protocolId: '
              'exceeded maximum stream lifetime',
            );
            break;
          }
          final data = await _readLengthPrefixedMessage(stream);
          if (data == null) {
            break;
          }
          if (data.isEmpty) {
            _logger.warning(
              'Received empty message from $remoteIdStr on $protocolId',
            );
            continue;
          }

          final packet = NetworkPacket(
            srcPeerId: remoteIdStr,
            datagram: data,
            responder: respond,
          );
          handler(packet);
          _messagePacketController.add(packet);
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Error handling stream for $protocolId from $remoteIdStr',
          e,
          stackTrace,
        );
      } finally {
        // Close the stream once the peer is done sending messages.
        try {
          await stream.close();
        } catch (_) {}
      }
    });
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    _protocolHandlers.remove(protocolId);
    _registeredProtocols.remove(protocolId);
    _logger.debug('Unregistered protocol handler for $protocolId');
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
  Set<String> get supportedProtocols => Set.unmodifiable(_registeredProtocols);

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
  Object? parseMultiaddr(String multiaddr) {
    try {
      return libp2p.MultiAddr(multiaddr);
    } catch (e) {
      _logger.warning('Failed to parse multiaddr: $multiaddr - $e');
      return null;
    }
  }

  @override
  List<String> resolvePeerId(String peerIdStr) {
    if (peerIdStr == peerID) {
      return listeningAddresses;
    }
    final addrs = _peerAddresses[peerIdStr];
    if (addrs != null && addrs.isNotEmpty) {
      return List.unmodifiable(addrs);
    }
    return [];
  }

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {
    _connectedPeers.add(targetPeerId);
    _logger.debug(
      'Registered relayed connection to $targetPeerId via $relayAddr',
    );
  }

  // Helper methods

  void _checkStarted() {
    if (!_hasStarted) {
      throw StateError('Libp2pRouter not started. Call start() first.');
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

  /// Idle deadline applied to each read on an inbound stream.
  static const Duration _inboundReadIdleTimeout =
      inbound.InboundMessageBounds.readIdleTimeout;

  /// Total lifetime of an inbound stream. Without this, a peer can hold a
  /// stream open indefinitely by sending a byte inside each idle window
  /// (drip-feed DoS). Multi-message protocols get a generous bound.
  static const Duration _maxStreamLifetime =
      inbound.InboundMessageBounds.maxStreamLifetime;

  /// Protocols where the responder speaks first — the dialer opens the
  /// stream and waits for a message without sending a request. Inbound
  /// streams on these protocols get a synthetic empty packet dispatched
  /// immediately so the handler can respond.
  static const Set<String> _respondFirstProtocols = {'/ipfs/id/1.0.0'};

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
    try {
      return await readLengthPrefixedMessage(
        (size) => _readChunk(stream, size),
      );
    } on FormatException catch (e) {
      _logger.warning('Rejected malformed inbound message: $e');
      return null;
    } catch (e) {
      _logger.error('Error reading length-prefixed message', e);
      return null;
    }
  }

  /// Reads one varint-length-prefixed message, pulling body bytes through
  /// [read]. Returns `null` when the source closes before a complete
  /// message arrives. Throws [FormatException] when the varint prefix or
  /// the advertised length exceeds the shared
  /// [inbound.InboundMessageBounds].
  @visibleForTesting
  static Future<Uint8List?> readLengthPrefixedMessage(
    Future<Uint8List?> Function(int size) read,
  ) => inbound.readLengthPrefixedMessage(read);

  Future<Uint8List?> _readChunk(
    libp2p.P2PStream<dynamic> stream,
    int size,
  ) async {
    try {
      final data = await stream.read(size).timeout(_inboundReadIdleTimeout);
      if (data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (e) {
      return null;
    }
  }

  /// Decodes a u64 varint. Throws [FormatException] when the encoding
  /// would exceed 64 bits.
  @visibleForTesting
  static int decodeVarint(Uint8List bytes) => inbound.decodeVarint(bytes);

  /// Probes for an available QUIC transport.
  ///
  /// Returns the pure-Dart QUIC transport adapter backed by [quic_lib] on
  /// native platforms. On the web the probe always returns `null` so the router
  /// falls back to TCP-only mode as documented in QUIC_SPEC.
  Future<libp2p_transport.Transport?> _probeQuicTransport() async {
    final transport = await quic_probe.probeQuicTransport(
      _quicTransportFactory,
    );
    if (transport == null && _config.network.enableQuic) {
      _logger.warning(
        'QUIC transport is not available on this platform; falling back to TCP.',
      );
    }
    return transport;
  }

  /// Loads the private-network pre-shared key if one is configured.
  ///
  /// The key source precedence is:
  /// 1. [NetworkConfig.privateNetworkPsk] if already populated.
  /// 2. [NetworkConfig.swarmKeyPath] if set.
  /// 3. The default `/data/ipfs/swarm.key` path if it exists.
  ///
  /// On success the loaded bytes are stored on [NetworkConfig.privateNetworkPsk]
  /// so subsequent logic can inspect the same value.
  Future<Uint8List?> _loadPrivateNetworkPsk() async {
    if (_config.network.privateNetworkPsk != null) {
      return _config.network.privateNetworkPsk;
    }

    final path = _config.network.swarmKeyPath;
    if (path != null && path.isNotEmpty) {
      _logger.info('Loading swarm key from $path');
      final psk = await loadSwarmKey(path);
      if (psk != null) {
        _config.network.privateNetworkPsk = psk;
        _logger.info('Loaded swarm key from $path');
        return psk;
      }
      _logger.warning('Failed to load swarm key from configured path: $path');
    }

    const defaultPath = '/data/ipfs/swarm.key';
    _logger.info('Checking default swarm key path: $defaultPath');
    final defaultPsk = await loadSwarmKey(defaultPath);
    if (defaultPsk != null) {
      _config.network.privateNetworkPsk = defaultPsk;
      _logger.info('Loaded default swarm key from $defaultPath');
      return defaultPsk;
    }

    return null;
  }

  /// Builds the list of listen addresses that will be passed to the libp2p host.
  ///
  /// - Parses the configured [NetworkConfig.listenAddresses].
  /// - Ensures a default TCP address is present if no valid TCP address is
  ///   configured.
  /// - Synthesizes `/ip4/0.0.0.0/udp/$quicListenPort/quic-v1` and
  ///   `/ip6/::/udp/$quicListenPort/quic-v1` when [supportsQuic] is true and
  ///   they are not already present.
  List<libp2p.MultiAddr> _buildListenAddresses() {
    final addresses = <libp2p.MultiAddr>[];
    var hasTcp = false;

    // `network.listenAddresses` is canonical; `libp2pListenAddress` is the
    // legacy single-address surface (e.g. CLI --swarm-addr) and is honored
    // only when the network list is empty.
    final configured = _config.network.listenAddresses.isNotEmpty
        ? _config.network.listenAddresses
        : [_config.libp2pListenAddress];

    for (final addrStr in configured) {
      try {
        final addr = libp2p.MultiAddr(addrStr);
        addresses.add(addr);
        if (addr.hasProtocol('tcp')) hasTcp = true;
      } catch (e) {
        _logger.warning('Skipping invalid listen address: $addrStr');
      }
    }

    // Ensure a TCP listen address is always present.
    if (!hasTcp) {
      addresses.add(libp2p.MultiAddr('/ip4/0.0.0.0/tcp/4001'));
    }

    // Synthesize QUIC addresses when the transport is available.
    if (supportsQuic) {
      final quicPort = _config.network.quicListenPort;
      final synthesized = [
        '/ip4/0.0.0.0/udp/$quicPort/quic-v1',
        '/ip6/::/udp/$quicPort/quic-v1',
      ];

      for (final addrStr in synthesized) {
        final addr = libp2p.MultiAddr(addrStr);
        if (!addresses.any((existing) => existing.equals(addr))) {
          addresses.add(addr);
        }
      }
    }

    return addresses;
  }
}

/// Exception thrown when a network operation fails in the transport layer.
class NetworkException implements Exception {
  /// Creates a [NetworkException] with a [message].
  NetworkException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
