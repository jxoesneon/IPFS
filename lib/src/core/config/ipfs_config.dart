// src/core/config/ipfs_config.dart
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:yaml/yaml.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/config/storage_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';

/// Configuration for an IPFS node.
///
/// This class defines all configuration options for initializing and running
/// an IPFS node, including storage paths, networking parameters, security
/// settings, and service configurations.
///
/// **Basic Configuration:**
/// ```dart
/// final config = IPFSConfig(
///   offline: false,  // Enable P2P networking
///   blockStorePath: './ipfs/blocks',
///   datastorePath: './ipfs/datastore',
/// );
/// ```
///
/// **Advanced Configuration:**
/// ```dart
/// final config = IPFSConfig(
///   offline: false,
///   network: NetworkConfig(
///     bootstrapPeers: ['<multiaddr>', ...],
///     listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
///   ),
///   dht: DHTConfig(
///     mode: DHTMode.server,  // Participate as DHT server
///     bucketSize: 20,
///   ),
///   security: SecurityConfig(
///     enableEncryption: true,
///   ),
/// );
/// ```
///
/// **Deployment Modes:**
///
/// **Offline Mode** (Local storage only):
/// ```dart
/// IPFSConfig(offline: true)
/// ```
///
/// **Gateway Mode** (HTTP serving):
/// ```dart
/// IPFSConfig(
///   offline: true,
///   gateway: GatewayConfig(enabled: true, port: 8080),
/// )
/// ```
///
/// **Full P2P Mode** (Network participation):
/// ```dart
/// IPFSConfig(offline: false)
/// ```
class IPFSConfig {
  final NetworkConfig network;
  final DHTConfig dht;
  final StorageConfig storage;
  final SecurityConfig security;
  final bool debug;
  final bool verboseLogging;
  final bool enablePubSub;
  final bool enableDHT;
  final bool enableCircuitRelay;
  final bool enableContentRouting;
  final bool enableDNSLinkResolution;
  final bool enableIPLD;
  final bool enableGraphsync;
  final bool enableMetrics;
  final bool enableLogging;
  final String logLevel;
  final bool enableQuotaManagement;
  final int defaultBandwidthQuota;
  final String datastorePath;
  final String keystorePath;
  final String blockStorePath;
  final String nodeId;
  final Duration garbageCollectionInterval;
  final bool garbageCollectionEnabled;
  final MetricsConfig metrics;
  final String dataPath;
  final Keystore keystore;
  final bool offline;
  final Map<String, dynamic> customConfig;

  IPFSConfig({
    this.offline = false,
    this.network = const NetworkConfig(),
    this.dht = const DHTConfig(),
    this.storage = const StorageConfig(),
    this.security = const SecurityConfig(),
    this.debug = true,
    this.verboseLogging = true,
    this.enablePubSub = true,
    this.enableDHT = true,
    this.enableCircuitRelay = true,
    this.enableContentRouting = true,
    this.enableDNSLinkResolution = true,
    this.enableIPLD = true,
    this.enableGraphsync = true,
    this.enableMetrics = true,
    this.enableLogging = true,
    this.logLevel = 'info',
    this.enableQuotaManagement = true,
    this.defaultBandwidthQuota = 1048576,
    this.datastorePath = './ipfs_data',
    this.keystorePath = './ipfs_keystore',
    this.blockStorePath = 'blocks',
    String? nodeId,
    this.garbageCollectionInterval = const Duration(hours: 24),
    this.garbageCollectionEnabled = true,
    this.metrics = const MetricsConfig(),
    this.dataPath = './ipfs_data',
    Keystore? keystore,
    this.customConfig = const {},
  })  : nodeId = nodeId ?? _generateDefaultNodeId(),
        keystore = keystore ?? Keystore();

  /// Creates a new IPFSConfig with a generated nodeId
  factory IPFSConfig.withDefaults() {
    return IPFSConfig(
      nodeId: _generateDefaultNodeId(),
    );
  }

  static String _generateDefaultNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return Base58().encode(Uint8List.fromList(bytes));
  }

  /// Loads configuration from a YAML file
  static Future<IPFSConfig> fromFile(String path) async {
    final file = File(path);
    final yaml = loadYaml(await file.readAsString());
    return IPFSConfig.fromJson(json.decode(json.encode(yaml)));
  }

  /// Creates configuration from JSON
  factory IPFSConfig.fromJson(Map<String, dynamic> json) {
    return IPFSConfig(
      offline: json['offline'] ?? false,
      network: NetworkConfig.fromJson(json['network'] ?? {}),
      dht: DHTConfig.fromJson(json['dht'] ?? {}),
      storage: StorageConfig.fromJson(json['storage'] ?? {}),
      security: SecurityConfig.fromJson(json['security'] ?? {}),
      debug: json['debug'] ?? false,
      verboseLogging: json['verboseLogging'] ?? false,
      enablePubSub: json['enablePubSub'] ?? true,
      enableDHT: json['enableDHT'] ?? true,
      enableCircuitRelay: json['enableCircuitRelay'] ?? true,
      enableContentRouting: json['enableContentRouting'] ?? true,
      enableDNSLinkResolution: json['enableDNSLinkResolution'] ?? true,
      enableIPLD: json['enableIPLD'] ?? true,
      enableGraphsync: json['enableGraphsync'] ?? true,
      enableMetrics: json['enableMetrics'] ?? true,
      enableLogging: json['enableLogging'] ?? true,
      logLevel: json['logLevel'] ?? 'info',
      enableQuotaManagement: json['enableQuotaManagement'] ?? true,
      defaultBandwidthQuota: json['defaultBandwidthQuota'] ?? 1048576,
    );
  }

  Map<String, dynamic> toJson() => {
        'offline': offline,
        'network': network.toJson(),
        'dht': dht.toJson(),
        'storage': storage.toJson(),
        'security': security.toJson(),
        'debug': debug,
        'verboseLogging': verboseLogging,
        'enablePubSub': enablePubSub,
        'enableDHT': enableDHT,
        'enableCircuitRelay': enableCircuitRelay,
        'enableContentRouting': enableContentRouting,
        'enableDNSLinkResolution': enableDNSLinkResolution,
        'enableIPLD': enableIPLD,
        'enableGraphsync': enableGraphsync,
        'enableMetrics': enableMetrics,
        'enableLogging': enableLogging,
        'logLevel': logLevel,
        'enableQuotaManagement': enableQuotaManagement,
        'defaultBandwidthQuota': defaultBandwidthQuota,
      };
}

/// Network-specific configuration
class NetworkConfig {
  final List<String> listenAddresses;
  final List<String> bootstrapPeers;
  final int maxConnections;
  final Duration connectionTimeout;
  final String? delegatedRoutingEndpoint;

  static const List<String> defaultBootstrapPeers = [
    // Public IPFS Bootstrap Nodes (Direct IPs to bypass DNS resolution issues in p2plib)
    '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ', // mars.i.ipfs.io
    '/ip4/104.236.179.241/tcp/4001/p2p/QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM', // pluto.i.ipfs.io
    '/ip4/128.199.219.111/tcp/4001/p2p/QmSoLSafTMBsPKadTEgaXctDQVcqN88CNLHXMkTNwMKPnu', // saturn.i.ipfs.io
    '/ip4/104.236.76.40/tcp/4001/p2p/QmSoLV4Bbm51jM9C4gDYZQ9Cy3U6aXMJDAbzgu2fzaDs64', // earth.i.ipfs.io

    // Cloudflare
    '/ip4/172.65.0.13/tcp/4009/p2p/QmcfgsJsMtx6qJb74akCw1M24X1zFwgGo11h1cuhwQjtJP',
  ];

  const NetworkConfig({
    this.listenAddresses = const ['/ip4/0.0.0.0/tcp/4001'],
    this.bootstrapPeers = defaultBootstrapPeers,
    this.maxConnections = 50,
    this.connectionTimeout = const Duration(seconds: 30),
    this.delegatedRoutingEndpoint,
  });

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses: List<String>.from(json['listenAddresses'] ?? []),
      bootstrapPeers: List<String>.from(json['bootstrapPeers'] ?? []),
      maxConnections: json['maxConnections'] ?? 50,
      connectionTimeout: Duration(
        seconds: json['connectionTimeoutSeconds'] ?? 30,
      ),
      delegatedRoutingEndpoint: json['delegatedRoutingEndpoint'],
    );
  }

  Map<String, dynamic> toJson() => {
        'listenAddresses': listenAddresses,
        'bootstrapPeers': bootstrapPeers,
        'maxConnections': maxConnections,
        'connectionTimeoutSeconds': connectionTimeout.inSeconds,
        'delegatedRoutingEndpoint': delegatedRoutingEndpoint,
      };
}

// Similar implementations for DHTConfig, StorageConfig, and SecurityConfig...

class KeyPair {
  final String publicKey;
  final String privateKey;

  KeyPair(this.publicKey, this.privateKey);
}
