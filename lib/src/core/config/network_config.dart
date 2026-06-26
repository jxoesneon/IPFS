// src/core/config/network_config.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/base58.dart';

/// Network configuration for the IPFS node.
///
/// Defines listen addresses, bootstrap peers, connection limits,
/// and other networking parameters.
///
/// Example:
/// ```dart
/// final config = NetworkConfig(
///   listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
///   maxConnections: 100,
/// );
/// ```
class NetworkConfig {
  /// Creates a network configuration with the given options.
  NetworkConfig({
    this.listenAddresses = defaultListenAddresses,
    this.bootstrapPeers = defaultBootstrapPeers,
    this.maxConnections = 50,
    this.connectionTimeout = const Duration(seconds: 30),
    this.enableNatTraversal = false,
    this.enableMDNS = true,
    this.enableWebTransport = true,
    this.enableWebRtc = true,
    this.circuitRelay = const CircuitRelayConfig(),
    String? nodeId,
    this.delegatedRoutingEndpoint,
  }) : nodeId = nodeId ?? _generateDefaultNodeId();

  /// Creates a network configuration with the given options and a generated Peer ID.
  factory NetworkConfig.withGeneratedId({
    List<String> listenAddresses = defaultListenAddresses,
    List<String> bootstrapPeers = defaultBootstrapPeers,
    int maxConnections = 50,
    Duration connectionTimeout = const Duration(seconds: 30),
    bool enableNatTraversal = false,
    bool enableMDNS = true,
    bool enableWebTransport = true,
    bool enableWebRtc = true,
    CircuitRelayConfig? circuitRelay,
  }) {
    return NetworkConfig(
      listenAddresses: listenAddresses,
      bootstrapPeers: bootstrapPeers,
      maxConnections: maxConnections,
      connectionTimeout: connectionTimeout,
      enableNatTraversal: enableNatTraversal,
      enableMDNS: enableMDNS,
      enableWebTransport: enableWebTransport,
      enableWebRtc: enableWebRtc,
      circuitRelay: circuitRelay ?? const CircuitRelayConfig(),
      nodeId: _generateDefaultNodeId(),
    );
  }

  /// Creates a network configuration from a JSON map.
  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses: (json['listenAddresses'] as List?)?.cast<String>() ?? [],
      bootstrapPeers: (json['bootstrapPeers'] as List?)?.cast<String>() ?? [],
      maxConnections: json['maxConnections'] as int? ?? 50,
      connectionTimeout: json['connectionTimeoutSeconds'] != null
          ? Duration(seconds: json['connectionTimeoutSeconds'] as int)
          : const Duration(seconds: 30),
      enableNatTraversal: json['enableNatTraversal'] as bool? ?? false,
      enableMDNS: json['enableMDNS'] as bool? ?? true,
      enableWebTransport: json['enableWebTransport'] as bool? ?? true,
      enableWebRtc: json['enableWebRtc'] as bool? ?? true,
      circuitRelay: json['circuitRelay'] != null
          ? CircuitRelayConfig.fromJson(
              Map<String, dynamic>.from(json['circuitRelay'] as Map),
            )
          : const CircuitRelayConfig(),
      nodeId: json['nodeId'] as String?,
      delegatedRoutingEndpoint: json['delegatedRoutingEndpoint'] as String?,
    );
  }

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
  final int maxConnections;

  /// Timeout for connection attempts.
  final Duration connectionTimeout;

  /// Whether to enable NAT traversal (UPnP/NAT-PMP). Defaults to false for security.
  final bool enableNatTraversal;

  /// Whether to enable mDNS for local peer discovery. Defaults to true.
  final bool enableMDNS;

  /// Whether to enable WebTransport.
  final bool enableWebTransport;

  /// Whether to enable WebRTC.
  final bool enableWebRtc;

  /// Circuit relay client configuration.
  final CircuitRelayConfig circuitRelay;

  /// Unique identifier for this node.
  final String nodeId;

  /// Optional HTTP endpoint for delegated routing.
  final String? delegatedRoutingEndpoint;

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
    'circuitRelay': circuitRelay.toJson(),
    'nodeId': nodeId,
    'delegatedRoutingEndpoint': delegatedRoutingEndpoint,
  };

  static String _generateDefaultNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return Base58().encode(Uint8List.fromList(bytes));
  }
}

/// Configuration for a specific protocol.
class ProtocolConfig {
  /// Creates a new [ProtocolConfig].
  ProtocolConfig({
    required this.protocolId,
    this.messageTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  });

  /// The protocol identifier.
  final String protocolId;

  /// Timeout for individual messages.
  final Duration messageTimeout;

  /// Maximum number of retries per message.
  final int maxRetries;
}

/// Configuration for the circuit relay client.
class CircuitRelayConfig {
  /// Creates a new [CircuitRelayConfig].
  const CircuitRelayConfig({
    this.enabled = true,
    this.staticRelays = const <String>[],
    this.reservationTimeout = const Duration(seconds: 30),
    this.reservationRefreshInterval = const Duration(minutes: 5),
    this.maxCircuits = 8,
  });

  /// Creates a [CircuitRelayConfig] from a JSON map.
  factory CircuitRelayConfig.fromJson(Map<String, dynamic> json) {
    return CircuitRelayConfig(
      enabled: json['enabled'] as bool? ?? true,
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
