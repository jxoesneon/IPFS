// src/core/config/network_config.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/base58.dart';

class NetworkConfig {
  static const defaultListenAddresses = [
    '/ip4/0.0.0.0/tcp/4001',
    '/ip6/::/tcp/4001'
  ];

  static const defaultBootstrapPeers = [
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt'
  ];

  final List<String> listenAddresses;
  final List<String> bootstrapPeers;
  final int maxConnections;
  final Duration connectionTimeout;
  final String nodeId;
  final String? delegatedRoutingEndpoint;

  NetworkConfig({
    this.listenAddresses = defaultListenAddresses,
    this.bootstrapPeers = defaultBootstrapPeers,
    this.maxConnections = 50,
    this.connectionTimeout = const Duration(seconds: 30),
    String? nodeId,
    this.delegatedRoutingEndpoint,
  }) : nodeId = nodeId ?? _generateDefaultNodeId();

  factory NetworkConfig.withGeneratedId({
    List<String> listenAddresses = defaultListenAddresses,
    List<String> bootstrapPeers = defaultBootstrapPeers,
    int maxConnections = 50,
    Duration connectionTimeout = const Duration(seconds: 30),
  }) {
    return NetworkConfig(
      listenAddresses: listenAddresses,
      bootstrapPeers: bootstrapPeers,
      maxConnections: maxConnections,
      connectionTimeout: connectionTimeout,
      nodeId: _generateDefaultNodeId(),
    );
  }

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses:
          List<String>.from(json['listenAddresses'] ?? defaultListenAddresses),
      bootstrapPeers:
          List<String>.from(json['bootstrapPeers'] ?? defaultBootstrapPeers),
      maxConnections: json['maxConnections'] ?? 50,
      connectionTimeout:
          Duration(seconds: json['connectionTimeoutSeconds'] ?? 30),
      nodeId: json['nodeId'],
      delegatedRoutingEndpoint: json['delegatedRoutingEndpoint'],
    );
  }

  Map<String, dynamic> toJson() => {
        'listenAddresses': listenAddresses,
        'bootstrapPeers': bootstrapPeers,
        'maxConnections': maxConnections,
        'connectionTimeoutSeconds': connectionTimeout.inSeconds,
        'nodeId': nodeId,
        'delegatedRoutingEndpoint': delegatedRoutingEndpoint,
      };

  static String _generateDefaultNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return Base58().encode(Uint8List.fromList(bytes));
  }
}

class ProtocolConfig {
  final String protocolId;
  final Duration messageTimeout;
  final int maxRetries;

  ProtocolConfig({
    required this.protocolId,
    this.messageTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  });
}
