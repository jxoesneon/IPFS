import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/config/storage_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';

/// Configuration for the IPFS node
class IPFSConfig {
  final NetworkConfig network;
  final DHTConfig dht;
  final StorageConfig storage;
  final SecurityConfig security;

  const IPFSConfig({
    this.network = const NetworkConfig(),
    this.dht = const DHTConfig(),
    this.storage = const StorageConfig(),
    this.security = const SecurityConfig(),
  });

  /// Loads configuration from a YAML file
  static Future<IPFSConfig> fromFile(String path) async {
    final file = File(path);
    final yaml = loadYaml(await file.readAsString());
    return IPFSConfig.fromJson(json.decode(json.encode(yaml)));
  }

  /// Creates configuration from JSON
  factory IPFSConfig.fromJson(Map<String, dynamic> json) {
    return IPFSConfig(
      network: NetworkConfig.fromJson(json['network'] ?? {}),
      dht: DHTConfig.fromJson(json['dht'] ?? {}),
      storage: StorageConfig.fromJson(json['storage'] ?? {}),
      security: SecurityConfig.fromJson(json['security'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'network': network.toJson(),
        'dht': dht.toJson(),
        'storage': storage.toJson(),
        'security': security.toJson(),
      };
}

/// Network-specific configuration
class NetworkConfig {
  final List<String> listenAddresses;
  final List<String> bootstrapPeers;
  final int maxConnections;
  final Duration connectionTimeout;

  const NetworkConfig({
    this.listenAddresses = const ['/ip4/0.0.0.0/tcp/4001'],
    this.bootstrapPeers = const [],
    this.maxConnections = 50,
    this.connectionTimeout = const Duration(seconds: 30),
  });

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses: List<String>.from(json['listenAddresses'] ?? []),
      bootstrapPeers: List<String>.from(json['bootstrapPeers'] ?? []),
      maxConnections: json['maxConnections'] ?? 50,
      connectionTimeout: Duration(
        seconds: json['connectionTimeoutSeconds'] ?? 30,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'listenAddresses': listenAddresses,
        'bootstrapPeers': bootstrapPeers,
        'maxConnections': maxConnections,
        'connectionTimeoutSeconds': connectionTimeout.inSeconds,
      };
}

// Similar implementations for DHTConfig, StorageConfig, and SecurityConfig... 