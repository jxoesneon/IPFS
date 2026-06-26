// src/core/config/ipfs_config.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/bitswap_config.dart';
import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/config/storage_config.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:yaml/yaml.dart';

export 'package:dart_ipfs/src/core/config/bitswap_config.dart';
export 'package:dart_ipfs/src/core/config/dht_config.dart';
export 'package:dart_ipfs/src/core/config/gateway_config.dart';
export 'package:dart_ipfs/src/core/config/metrics_config.dart';
export 'package:dart_ipfs/src/core/config/network_config.dart';
export 'package:dart_ipfs/src/core/config/security_config.dart';
export 'package:dart_ipfs/src/core/config/storage_config.dart';

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
    NetworkConfig? network,
    DHTConfig? dht,
    StorageConfig? storage,
    SecurityConfig? security,
    GatewayConfig? gateway,
    BitswapConfig? bitswap,
    this.debug = true,
    this.verboseLogging = true,
    this.enablePubSub = true,
    this.enableDHT = true,
    this.enableRPC = false,
    this.enableCircuitRelay = true,
    this.enableContentRouting = true,
    this.enableDNSLinkResolution = true,
    this.enableIPLD = true,
    this.enableGraphsync = true,
    this.enableMetrics = true,
    this.enableIpnsPubSub = false,
    this.enableLogging = true,
    this.enableStructuredLogging = false,
    this.ipnsCacheSize = 1000,
    this.logLevel = 'info',
    this.enableQuotaManagement = true,
    this.defaultBandwidthQuota = 1048576,
    this.maxConcurrentBitswapRequests = 10,
    this.datastorePath = './ipfs_data',
    this.keystorePath = './ipfs_keystore',
    this.blockStorePath = 'blocks',
    this.enableLibp2pBridge = false,
    this.libp2pListenAddress = '/ip4/0.0.0.0/tcp/4001',
    this.libp2pIdentitySeed,
    String? nodeId,
    this.garbageCollectionInterval = const Duration(hours: 24),
    this.garbageCollectionEnabled = true,
    this.metrics = const MetricsConfig(),
    this.dataPath = './ipfs_data',
    Keystore? keystore,
    this.maxSelectorDepth = 32,
    this.maxSelectorNodes = 10000,
    this.customConfig = const {},
  })  : network = network ?? NetworkConfig(),
        dht = dht ?? const DHTConfig(),
        storage = storage ?? const StorageConfig(),
        security = security ?? const SecurityConfig(),
        gateway = gateway ?? const GatewayConfig(),
        bitswap = bitswap ?? const BitswapConfig(),
        nodeId = nodeId ?? _generateDefaultNodeId(),
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
      gateway: json['gateway'] != null
          ? GatewayConfig.fromJson(
              Map<String, dynamic>.from(json['gateway'] as Map),
            )
          : null,
      bitswap: json['bitswap'] != null
          ? BitswapConfig.fromJson(
              Map<String, dynamic>.from(json['bitswap'] as Map),
            )
          : const BitswapConfig(),
      debug: json['debug'] as bool? ?? false,
      verboseLogging: json['verboseLogging'] as bool? ?? false,
      enablePubSub: json['enablePubSub'] as bool? ?? true,
      enableDHT: json['enableDHT'] as bool? ?? true,
      enableRPC: json['enableRPC'] as bool? ?? false,
      enableCircuitRelay: json['enableCircuitRelay'] as bool? ?? true,
      enableContentRouting: json['enableContentRouting'] as bool? ?? true,
      enableDNSLinkResolution: json['enableDNSLinkResolution'] as bool? ?? true,
      enableIPLD: json['enableIPLD'] as bool? ?? true,
      enableGraphsync: json['enableGraphsync'] as bool? ?? true,
      enableMetrics: json['enableMetrics'] as bool? ?? true,
      enableIpnsPubSub: json['enableIpnsPubSub'] as bool? ?? false,
      enableLogging: json['enableLogging'] as bool? ?? true,
      enableStructuredLogging:
          json['enableStructuredLogging'] as bool? ?? false,
      logLevel: json['logLevel'] as String? ?? 'info',
      enableQuotaManagement: json['enableQuotaManagement'] as bool? ?? true,
      defaultBandwidthQuota: json['defaultBandwidthQuota'] as int? ?? 1048576,
      maxConcurrentBitswapRequests:
          json['maxConcurrentBitswapRequests'] as int? ?? 10,
      maxSelectorDepth: json['maxSelectorDepth'] as int? ?? 32,
      maxSelectorNodes: json['maxSelectorNodes'] as int? ?? 10000,
      ipnsCacheSize: json['ipnsCacheSize'] as int? ?? 1000,
      garbageCollectionInterval: Duration(
        seconds: json['garbageCollectionInterval'] as int? ?? 86400,
      ),
      garbageCollectionEnabled:
          json['garbageCollectionEnabled'] as bool? ?? true,
      datastorePath: json['datastorePath'] as String? ?? './ipfs_data',
      keystorePath: json['keystorePath'] as String? ?? './ipfs_keystore',
      blockStorePath: json['blockStorePath'] as String? ?? 'blocks',
      dataPath: json['dataPath'] as String? ?? './ipfs_data',
      enableLibp2pBridge: json['enableLibp2pBridge'] as bool? ?? false,
      libp2pListenAddress:
          json['libp2pListenAddress'] as String? ?? '/ip4/0.0.0.0/tcp/4001',
      nodeId: json['nodeId'] as String?,
      libp2pIdentitySeed: json['libp2pIdentitySeed'] != null
          ? base64Decode(json['libp2pIdentitySeed'] as String)
          : null,
      metrics: json['metrics'] != null
          ? MetricsConfig.fromJson(
              Map<String, dynamic>.from(json['metrics'] as Map),
            )
          : const MetricsConfig(),
      customConfig: Map<String, dynamic>.from(
        json['customConfig'] as Map? ?? const {},
      ),
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

  /// HTTP Gateway configuration.
  final GatewayConfig gateway;

  /// Bitswap protocol configuration.
  final BitswapConfig bitswap;

  /// Enable debug mode.
  final bool debug;

  /// Enable verbose logging.
  final bool verboseLogging;

  /// Enable PubSub protocols.
  final bool enablePubSub;

  /// Enable DHT protocols.
  final bool enableDHT;

  /// Enable the RPC API server.
  final bool enableRPC;

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

  /// Enable IPNS PubSub notifications (requires a Gossipsub-compliant handler).
  final bool enableIpnsPubSub;

  /// Enable system-wide logging.
  final bool enableLogging;

  /// Enable structured (JSON) logging.
  final bool enableStructuredLogging;

  /// The size of the IPNS resolution cache.
  final int ipnsCacheSize;

  /// The logging level (e.g., 'info', 'debug', 'error').
  final String logLevel;

  /// Enable bandwidth quota management.
  final bool enableQuotaManagement;

  /// Default bandwidth quota in bytes.
  final int defaultBandwidthQuota;

  /// Maximum concurrent bitswap requests.
  final int maxConcurrentBitswapRequests;

  /// Maximum recursion depth for IPLD selector execution.
  final int maxSelectorDepth;

  /// Maximum number of nodes to visit during IPLD selector execution.
  final int maxSelectorNodes;

  /// Path to the datastore.
  final String datastorePath;

  /// Path to the keystore.
  final String keystorePath;

  /// Path to the blockstore.
  final String blockStorePath;

  /// Whether to enable the libp2p bridge transport.
  final bool enableLibp2pBridge;

  /// The listen address for the libp2p bridge.
  final String libp2pListenAddress;

  /// Optional seed for persistent libp2p identity.
  final Uint8List? libp2pIdentitySeed;

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

  /// Loads configuration from a JSON or YAML file.
  ///
  /// JSON is the canonical on-disk format. Files ending in `.yaml` or `.yml`
  /// are parsed as YAML and round-tripped through JSON for compatibility.
  static Future<IPFSConfig> fromFile(String path) async {
    final content = await getPlatform().readString(path);
    if (content == null) {
      throw Exception('Configuration file not found: $path');
    }

    final lower = path.toLowerCase();
    final Map<String, dynamic> jsonMap;
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
      final yaml = loadYaml(content);
      jsonMap = json.decode(json.encode(yaml)) as Map<String, dynamic>;
    } else {
      jsonMap = json.decode(content) as Map<String, dynamic>;
    }

    return IPFSConfig.fromJson(jsonMap);
  }

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() => {
        'offline': offline,
        'network': network.toJson(),
        'dht': dht.toJson(),
        'storage': storage.toJson(),
        'security': security.toJson(),
        'gateway': gateway.toJson(),
        'bitswap': bitswap.toJson(),
        'debug': debug,
        'verboseLogging': verboseLogging,
        'enablePubSub': enablePubSub,
        'enableDHT': enableDHT,
        'enableRPC': enableRPC,
        'enableCircuitRelay': enableCircuitRelay,
        'enableContentRouting': enableContentRouting,
        'enableDNSLinkResolution': enableDNSLinkResolution,
        'enableIPLD': enableIPLD,
        'enableGraphsync': enableGraphsync,
        'enableMetrics': enableMetrics,
        'enableIpnsPubSub': enableIpnsPubSub,
        'enableLogging': enableLogging,
        'enableStructuredLogging': enableStructuredLogging,
        'logLevel': logLevel,
        'enableQuotaManagement': enableQuotaManagement,
        'defaultBandwidthQuota': defaultBandwidthQuota,
        'maxConcurrentBitswapRequests': maxConcurrentBitswapRequests,
        'maxSelectorDepth': maxSelectorDepth,
        'maxSelectorNodes': maxSelectorNodes,
        'ipnsCacheSize': ipnsCacheSize,
        'garbageCollectionInterval': garbageCollectionInterval.inSeconds,
        'garbageCollectionEnabled': garbageCollectionEnabled,
        'datastorePath': datastorePath,
        'keystorePath': keystorePath,
        'blockStorePath': blockStorePath,
        'dataPath': dataPath,
        'enableLibp2pBridge': enableLibp2pBridge,
        'libp2pListenAddress': libp2pListenAddress,
        'nodeId': nodeId,
        'libp2pIdentitySeed': libp2pIdentitySeed != null
            ? base64Encode(libp2pIdentitySeed!)
            : null,
        'metrics': metrics.toJson(),
        'customConfig': customConfig,
      };
}
