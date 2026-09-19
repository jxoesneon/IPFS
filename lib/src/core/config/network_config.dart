// src/core/config/network_config.dart
import 'dart:math';
import 'dart:typed_data';
import '../../utils/base58.dart';

/// Network configuration for the IPFS node.
///
/// Defines listen addresses, bootstrap peers, connection limits,
/// STUN/TURN servers for WebRTC, and other networking parameters.
///
/// Example:
/// ```dart
/// final config = NetworkConfig(
///   listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
/// );
/// ```
class NetworkConfig {
  /// Creates a network configuration with the given options.
  NetworkConfig({
    this.listenAddresses = defaultListenAddresses,
    this.bootstrapPeers = defaultBootstrapPeers,
    @Deprecated(
      'No connection-limit enforcement exists; this option is ignored.',
    )
    this.maxConnections = 50,
    @Deprecated('Dial timeouts are not configurable; this option is ignored.')
    this.connectionTimeout = const Duration(seconds: 30),
    this.enableNatTraversal = false,
    this.enableMDNS = true,
    this.enableWebTransport = true,
    this.enableWebRtc = true,
    this.enableQuic = false,
    this.quicListenPort = 4002,
    @Deprecated('No QUIC transport exists; this option is ignored.')
    this.quicMaxStreams = 100,
    @Deprecated('No QUIC transport exists; this option is ignored.')
    this.preferQuic = false,
    this.circuitRelay = const CircuitRelayConfig(),
    this.stunServers = const [],
    this.turnServers = const [],
    @Deprecated(
      'Node identity is derived from the libp2p keypair; '
      'IPFSConfig.nodeId names the mDNS instance. This option is ignored.',
    )
    String? nodeId,
    this.delegatedRoutingEndpoint,
    this.ipniEndpoints = const <String>[],
    this.reframeEndpoints = const <String>[],
    this.swarmKeyPath,
    this.privateNetworkPsk,
    // ignore: deprecated_member_use_from_same_package
  }) : nodeId = nodeId ?? _generateDefaultNodeId();

  /// Creates a network configuration with the given options and a generated Peer ID.
  factory NetworkConfig.withGeneratedId({
    List<String> listenAddresses = defaultListenAddresses,
    List<String> bootstrapPeers = defaultBootstrapPeers,
    @Deprecated(
      'No connection-limit enforcement exists; this option is ignored.',
    )
    int maxConnections = 50,
    @Deprecated('Dial timeouts are not configurable; this option is ignored.')
    Duration connectionTimeout = const Duration(seconds: 30),
    bool enableNatTraversal = false,
    bool enableMDNS = true,
    bool enableWebTransport = true,
    bool enableWebRtc = true,
    bool enableQuic = false,
    int quicListenPort = 4002,
    @Deprecated('No QUIC transport exists; this option is ignored.')
    int quicMaxStreams = 100,
    @Deprecated('No QUIC transport exists; this option is ignored.')
    bool preferQuic = false,
    CircuitRelayConfig? circuitRelay,
    List<String> stunServers = const [],
    List<TurnServer> turnServers = const [],
    String? swarmKeyPath,
    Uint8List? privateNetworkPsk,
  }) {
    return NetworkConfig(
      listenAddresses: listenAddresses,
      bootstrapPeers: bootstrapPeers,
      // ignore: deprecated_member_use_from_same_package
      maxConnections: maxConnections,
      // ignore: deprecated_member_use_from_same_package
      connectionTimeout: connectionTimeout,
      enableNatTraversal: enableNatTraversal,
      enableMDNS: enableMDNS,
      enableWebTransport: enableWebTransport,
      enableWebRtc: enableWebRtc,
      enableQuic: enableQuic,
      quicListenPort: quicListenPort,
      // ignore: deprecated_member_use_from_same_package
      quicMaxStreams: quicMaxStreams,
      // ignore: deprecated_member_use_from_same_package
      preferQuic: preferQuic,
      circuitRelay: circuitRelay ?? const CircuitRelayConfig(),
      stunServers: stunServers,
      turnServers: turnServers,
      // ignore: deprecated_member_use_from_same_package
      nodeId: _generateDefaultNodeId(),
      swarmKeyPath: swarmKeyPath,
      privateNetworkPsk: privateNetworkPsk,
    );
  }

  /// Creates a network configuration from a JSON map.
  ///
  /// Keys absent from [json] fall back to the constructor defaults (including
  /// [defaultListenAddresses] and [defaultBootstrapPeers]); an explicitly
  /// empty list stays empty.
  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses:
          (json['listenAddresses'] as List?)?.cast<String>() ??
          defaultListenAddresses,
      bootstrapPeers:
          (json['bootstrapPeers'] as List?)?.cast<String>() ??
          defaultBootstrapPeers,
      // ignore: deprecated_member_use_from_same_package
      maxConnections: json['maxConnections'] as int? ?? 50,
      // ignore: deprecated_member_use_from_same_package
      connectionTimeout: json['connectionTimeoutSeconds'] != null
          ? Duration(seconds: json['connectionTimeoutSeconds'] as int)
          : const Duration(seconds: 30),
      enableNatTraversal: json['enableNatTraversal'] as bool? ?? false,
      enableMDNS: json['enableMDNS'] as bool? ?? true,
      enableWebTransport: json['enableWebTransport'] as bool? ?? true,
      enableWebRtc: json['enableWebRtc'] as bool? ?? true,
      enableQuic: json['enableQuic'] as bool? ?? false,
      quicListenPort: json['quicListenPort'] as int? ?? 4002,
      // ignore: deprecated_member_use_from_same_package
      quicMaxStreams: json['quicMaxStreams'] as int? ?? 100,
      // ignore: deprecated_member_use_from_same_package
      preferQuic: json['preferQuic'] as bool? ?? false,
      circuitRelay: json['circuitRelay'] != null
          ? CircuitRelayConfig.fromJson(
              Map<String, dynamic>.from(json['circuitRelay'] as Map),
            )
          : const CircuitRelayConfig(),
      stunServers: (json['stunServers'] as List?)?.cast<String>() ?? const [],
      turnServers:
          (json['turnServers'] as List?)
              ?.map(
                (e) => TurnServer.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      // ignore: deprecated_member_use_from_same_package
      nodeId: json['nodeId'] as String?,
      delegatedRoutingEndpoint: json['delegatedRoutingEndpoint'] as String?,
      ipniEndpoints:
          (json['ipniEndpoints'] as List?)?.cast<String>() ?? const [],
      reframeEndpoints:
          (json['reframeEndpoints'] as List?)?.cast<String>() ??
          const <String>[],
      swarmKeyPath: json['swarmKeyPath'] as String?,
      privateNetworkPsk: null,
    );
  }

  /// Default IPNI endpoints used when no custom endpoints are configured.
  static const defaultIpniEndpoints = ['https://cid.contact'];

  /// Default Reframe endpoints used when no custom endpoints are configured.
  static const defaultReframeEndpoints = <String>[];

  /// Default multiaddr listen addresses for TCP.
  static const defaultListenAddresses = [
    '/ip4/0.0.0.0/tcp/4001',
    '/ip6/::/tcp/4001',
    '/ip4/0.0.0.0/udp/4002/quic-v1/webtransport',
  ];

  /// Default IPFS bootstrap peers.
  static const defaultBootstrapPeers = [
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt',
  ];

  /// Addresses to listen on for incoming connections.
  final List<String> listenAddresses;

  /// Peers to connect to on startup.
  final List<String> bootstrapPeers;

  /// Maximum number of concurrent connections.
  ///
  /// Ignored: no connection-limit enforcement exists.
  final int maxConnections;

  /// Timeout for connection attempts.
  ///
  /// Ignored: dial timeouts are not configurable.
  final Duration connectionTimeout;

  /// Whether to enable NAT traversal (UPnP/NAT-PMP). Defaults to false for security.
  final bool enableNatTraversal;

  /// Whether to enable mDNS for local peer discovery. Defaults to true.
  final bool enableMDNS;

  /// Whether to enable WebTransport.
  final bool enableWebTransport;

  /// Whether to enable WebRTC.
  final bool enableWebRtc;

  /// Whether to enable the native QUIC transport.
  ///
  /// Defaults to `false` because the current `package:ipfs_libp2p` dependency
  /// does not expose a QUIC transport class; enabling this currently logs a
  /// warning and falls back to TCP-only mode.
  final bool enableQuic;

  /// UDP port the QUIC transport will listen on when enabled and available.
  final int quicListenPort;

  /// Maximum number of concurrent QUIC streams per connection.
  ///
  /// Ignored: no QUIC transport exists.
  final int quicMaxStreams;

  /// Whether to prefer QUIC over TCP when dialing a peer that advertises both.
  ///
  /// Ignored: no QUIC transport exists.
  final bool preferQuic;

  /// STUN servers for WebRTC ICE negotiation. Default is empty; no
  /// production STUN servers are hardcoded.
  final List<String> stunServers;

  /// TURN servers for WebRTC relay fallback. Default is empty.
  final List<TurnServer> turnServers;

  /// Circuit relay client configuration.
  final CircuitRelayConfig circuitRelay;

  /// Unique identifier for this node.
  ///
  /// Ignored: the node identity is derived from the libp2p keypair;
  /// [IPFSConfig.nodeId] names the mDNS instance.
  final String nodeId;

  /// Optional HTTP endpoint for delegated routing.
  final String? delegatedRoutingEndpoint;

  /// Optional IPNI endpoints for content routing.
  final List<String> ipniEndpoints;

  /// Optional Reframe endpoints for delegated routing.
  final List<String> reframeEndpoints;

  /// Optional path to a libp2p private-network swarm key file.
  String? swarmKeyPath;

  /// The 32-byte pre-shared key loaded from [swarmKeyPath].
  ///
  /// This is populated at runtime and is intentionally not serialized.
  Uint8List? privateNetworkPsk;

  /// Converts the network configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'listenAddresses': listenAddresses,
    'bootstrapPeers': bootstrapPeers,
    'maxConnections': maxConnections,
    'connectionTimeoutSeconds': connectionTimeout.inSeconds,
    'enableNatTraversal': enableNatTraversal,
    'enableMDNS': enableMDNS,
    'enableWebTransport': enableWebTransport,
    'enableWebRtc': enableWebRtc,
    'enableQuic': enableQuic,
    'quicListenPort': quicListenPort,
    'quicMaxStreams': quicMaxStreams,
    'preferQuic': preferQuic,
    'stunServers': stunServers,
    'turnServers': turnServers.map((e) => e.toJson()).toList(),
    'circuitRelay': circuitRelay.toJson(),
    'nodeId': nodeId,
    'delegatedRoutingEndpoint': delegatedRoutingEndpoint,
    'ipniEndpoints': ipniEndpoints,
    'reframeEndpoints': reframeEndpoints,
    'swarmKeyPath': swarmKeyPath,
    // privateNetworkPsk is intentionally not serialized.
  };

  static String _generateDefaultNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return Base58().encode(Uint8List.fromList(bytes));
  }
}

/// Configuration for the circuit relay client.
class CircuitRelayConfig {
  /// Creates a new [CircuitRelayConfig].
  const CircuitRelayConfig({
    this.enabled = true,
    @Deprecated('Static relays are never dialed; this option is ignored.')
    this.staticRelays = const <String>[],
    this.reservationTimeout = const Duration(seconds: 30),
    this.reservationRefreshInterval = const Duration(minutes: 5),
    this.maxCircuits = 8,
  });

  /// Creates a [CircuitRelayConfig] from a JSON map.
  factory CircuitRelayConfig.fromJson(Map<String, dynamic> json) {
    return CircuitRelayConfig(
      enabled: json['enabled'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      staticRelays: (json['staticRelays'] as List?)?.cast<String>() ?? const [],
      reservationTimeout: json['reservationTimeoutSeconds'] != null
          ? Duration(seconds: json['reservationTimeoutSeconds'] as int)
          : const Duration(seconds: 30),
      reservationRefreshInterval:
          json['reservationRefreshIntervalSeconds'] != null
          ? Duration(seconds: json['reservationRefreshIntervalSeconds'] as int)
          : const Duration(minutes: 5),
      maxCircuits: json['maxCircuits'] as int? ?? 8,
    );
  }

  /// Whether circuit relay support is enabled.
  final bool enabled;

  /// Static relay multiaddresses to use when no dynamic relay is available.
  ///
  /// Ignored: static relays are never dialed.
  final List<String> staticRelays;

  /// Timeout for reservation and CONNECT requests.
  final Duration reservationTimeout;

  /// Interval before a reservation expires at which to refresh it.
  final Duration reservationRefreshInterval;

  /// Maximum number of concurrent relayed circuits.
  final int maxCircuits;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'staticRelays': staticRelays,
    'reservationTimeoutSeconds': reservationTimeout.inSeconds,
    'reservationRefreshIntervalSeconds': reservationRefreshInterval.inSeconds,
    'maxCircuits': maxCircuits,
  };
}

/// Configuration for a TURN server used by WebRTC ICE.
class TurnServer {
  /// Creates a new [TurnServer].
  const TurnServer({
    required this.url,
    required this.username,
    required this.credential,
  });

  /// Creates a [TurnServer] from a JSON map.
  factory TurnServer.fromJson(Map<String, dynamic> json) {
    return TurnServer(
      url: json['url'] as String,
      username: json['username'] as String,
      credential: json['credential'] as String,
    );
  }

  /// TURN URL, e.g. `turn:turn.example.com:3478`.
  final String url;

  /// Username for TURN authentication.
  final String username;

  /// Credential (password) for TURN authentication.
  final String credential;

  /// Converts this server to a JSON map.
  Map<String, dynamic> toJson() => {
    'url': url,
    'username': username,
    'credential': credential,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnServer &&
          other.url == url &&
          other.username == username &&
          other.credential == credential;

  @override
  int get hashCode => Object.hash(url, username, credential);
}
