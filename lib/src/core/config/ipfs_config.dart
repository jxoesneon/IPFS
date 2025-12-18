// src/core/config/ipfs_config.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/config/storage_config.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:yaml/yaml.dart';

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
  /// Creates a new [IPFSConfig] with the specified options.
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
  }) : nodeId = nodeId ?? _generateDefaultNodeId(),
       keystore = keystore ?? Keystore();

  /// Creates a new IPFSConfig with a generated nodeId
  factory IPFSConfig.withDefaults() {
    return IPFSConfig(nodeId: _generateDefaultNodeId());
  }

  /// Creates configuration from JSON
  factory IPFSConfig.fromJson(Map<String, dynamic> json) {
    return IPFSConfig(
      offline: json['offline'] as bool? ?? false,
      network: NetworkConfig.fromJson(
        json['network'] != null
            ? Map<String, dynamic>.from(json['network'] as Map)
            : {},
      ),
      dht: DHTConfig.fromJson(
        json['dht'] != null
            ? Map<String, dynamic>.from(json['dht'] as Map)
            : {},
      ),
      storage: StorageConfig.fromJson(
        json['storage'] != null
            ? Map<String, dynamic>.from(json['storage'] as Map)
            : {},
      ),
      security: SecurityConfig.fromJson(
        json['security'] != null
            ? Map<String, dynamic>.from(json['security'] as Map)
            : {},
      ),
      debug: json['debug'] as bool? ?? false,
      verboseLogging: json['verboseLogging'] as bool? ?? false,
      enablePubSub: json['enablePubSub'] as bool? ?? true,
      enableDHT: json['enableDHT'] as bool? ?? true,
      enableCircuitRelay: json['enableCircuitRelay'] as bool? ?? true,
      enableContentRouting: json['enableContentRouting'] as bool? ?? true,
      enableDNSLinkResolution: json['enableDNSLinkResolution'] as bool? ?? true,
      enableIPLD: json['enableIPLD'] as bool? ?? true,
      enableGraphsync: json['enableGraphsync'] as bool? ?? true,
      enableMetrics: json['enableMetrics'] as bool? ?? true,
      enableLogging: json['enableLogging'] as bool? ?? true,
      logLevel: json['logLevel'] as String? ?? 'info',
      enableQuotaManagement: json['enableQuotaManagement'] as bool? ?? true,
      defaultBandwidthQuota: json['defaultBandwidthQuota'] as int? ?? 1048576,
    );
  }

  /// Detailed network configuration.
  final NetworkConfig network;

  /// Distributed Hash Table configuration.
  final DHTConfig dht;

  /// Storage and datastore configuration.
  final StorageConfig storage;

  /// Security and identity configuration.
  final SecurityConfig security;

  /// Enable debug mode.
  final bool debug;

  /// Enable verbose logging.
  final bool verboseLogging;

  /// Enable PubSub protocols.
  final bool enablePubSub;

  /// Enable DHT protocols.
  final bool enableDHT;

  /// Enable Circuit Relay support.
  final bool enableCircuitRelay;

  /// Enable content routing.
  final bool enableContentRouting;

  /// Enable DNSLink resolution.
  final bool enableDNSLinkResolution;

  /// Enable IPLD support.
  final bool enableIPLD;

  /// Enable Graphsync protocol.
  final bool enableGraphsync;

  /// Enable metrics collection.
  final bool enableMetrics;

  /// Enable system-wide logging.
  final bool enableLogging;

  /// The logging level (e.g., 'info', 'debug', 'error').
  final String logLevel;

  /// Enable bandwidth quota management.
  final bool enableQuotaManagement;

  /// Default bandwidth quota in bytes.
  final int defaultBandwidthQuota;

  /// Path to the datastore.
  final String datastorePath;

  /// Path to the keystore.
  final String keystorePath;

  /// Path to the blockstore.
  final String blockStorePath;

  /// The unique node identifier.
  final String nodeId;

  /// Interval for garbage collection.
  final Duration garbageCollectionInterval;

  /// Enable automatic garbage collection.
  final bool garbageCollectionEnabled;

  /// Metrics collection configuration.
  final MetricsConfig metrics;

  /// The base path for node data.
  final String dataPath;

  /// The keystore for managing keys.
  final Keystore keystore;

  /// Run node in offline mode.
  final bool offline;

  /// Key-value pair for custom configuration options.
  final Map<String, dynamic> customConfig;

  static String _generateDefaultNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return Base58().encode(Uint8List.fromList(bytes));
  }

  /// Loads configuration from a YAML file
  static Future<IPFSConfig> fromFile(String path) async {
    final file = File(path);
    final yaml = loadYaml(await file.readAsString());
    return IPFSConfig.fromJson(
      json.decode(json.encode(yaml)) as Map<String, dynamic>,
    );
  }

  /// Converts to JSON representation.
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
/// Network-specific configuration for an IPFS node.
class NetworkConfig {
  /// Creates a new [NetworkConfig].
  const NetworkConfig({
    this.listenAddresses = const ['/ip4/0.0.0.0/tcp/4001'],
    this.bootstrapPeers = defaultBootstrapPeers,
    this.maxConnections = 50,
    this.connectionTimeout = const Duration(seconds: 30),
    this.delegatedRoutingEndpoint,
  });

  /// Creates a [NetworkConfig] from a JSON map.
  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      listenAddresses: List<String>.from(
        (json['listenAddresses'] as List?) ?? [],
      ),
      bootstrapPeers: List<String>.from(
        (json['bootstrapPeers'] as List?) ?? [],
      ),
      maxConnections: json['maxConnections'] as int? ?? 50,
      connectionTimeout: Duration(
        seconds: json['connectionTimeoutSeconds'] as int? ?? 30,
      ),
      delegatedRoutingEndpoint: json['delegatedRoutingEndpoint'] as String?,
    );
  }

  /// List of multiaddrs this node listens on.
  final List<String> listenAddresses;

  /// Peers to connect to on startup.
  final List<String> bootstrapPeers;

  /// Maximum allowed concurrent connections.
  final int maxConnections;

  /// Timeout for connection attempts.
  final Duration connectionTimeout;

  /// Optional endpoint for delegated routing.
  final String? delegatedRoutingEndpoint;

  /// Default IPFS bootstrap peers.
  static const List<String> defaultBootstrapPeers = [
    // Public IPFS Bootstrap Nodes (Direct IPs to bypass DNS resolution issues in p2plib)
    '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ', // mars.i.ipfs.io
    '/ip4/104.236.179.241/tcp/4001/p2p/QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM', // pluto.i.ipfs.io
    '/ip4/128.199.219.111/tcp/4001/p2p/QmSoLSafTMBsPKadTEgaXctDQVcqN88CNLHXMkTNwMKPnu', // saturn.i.ipfs.io
    '/ip4/104.236.76.40/tcp/4001/p2p/QmSoLV4Bbm51jM9C4gDYZQ9Cy3U6aXMJDAbzgu2fzaDs64', // earth.i.ipfs.io
    // Cloudflare
    '/ip4/172.65.0.13/tcp/4009/p2p/QmcfgsJsMtx6qJb74akCw1M24X1zFwgGo11h1cuhwQjtJP',
  ];

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() => {
    'listenAddresses': listenAddresses,
    'bootstrapPeers': bootstrapPeers,
    'maxConnections': maxConnections,
    'connectionTimeoutSeconds': connectionTimeout.inSeconds,
    'delegatedRoutingEndpoint': delegatedRoutingEndpoint,
  };
}

// Similar implementations for DHTConfig, StorageConfig, and SecurityConfig...

/// Represents a public/private key pair used for configuration.
class KeyPair {
  /// Creates a new [KeyPair].
  KeyPair(this.publicKey, this.privateKey);

  /// The public key in string format.
  final String publicKey;

  /// The private key in string format.
  final String privateKey;
}
