// src/core/config/ipfs_config.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import '../../platform/platform.dart';
import '../../utils/base58.dart';
import '../../utils/keystore.dart';
import 'bitswap_config.dart';
import 'dht_config.dart';
import 'gateway_config.dart';
import 'graphsync_config.dart';
import 'metrics_config.dart';
import 'network_config.dart';
import 'security_config.dart';
import 'storage_config.dart';

export 'bitswap_config.dart';
export 'dht_config.dart';
export 'gateway_config.dart';
export 'graphsync_config.dart';
export 'metrics_config.dart';
export 'network_config.dart';
export 'security_config.dart';
export 'storage_config.dart';

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
    @Deprecated('StorageConfig is never read; use the top-level path fields.')
    // ignore: deprecated_member_use_from_same_package
    StorageConfig? storage,
    SecurityConfig? security,
    GatewayConfig? gateway,
    BitswapConfig? bitswap,
    GraphsyncConfig? graphsync,
    this.debug = true,
    this.verboseLogging = true,
    this.enablePubSub = true,
    this.enableDHT = true,
    this.enableRPC = false,
    this.rpcApiKey,
    @Deprecated(
      'Use NetworkConfig.circuitRelay.enabled; this option is ignored.',
    )
    this.enableCircuitRelay = true,
    this.enableContentRouting = true,
    this.enableDNSLinkResolution = true,
    @Deprecated(
      'IPLD is a core dependency and cannot be disabled; this flag is ignored.',
    )
    this.enableIPLD = true,
    this.enableGraphsync = true,
    this.enableMetrics = true,
    this.enableIpnsPubSub = false,
    @Deprecated('Logging is always enabled; use logLevel to control verbosity.')
    this.enableLogging = true,
    @Deprecated(
      'Structured logging is not wired into the node runtime; '
      'this option is ignored.',
    )
    this.enableStructuredLogging = false,
    this.ipnsCacheSize = 1000,
    this.logLevel = 'info',
    @Deprecated('No bandwidth quota subsystem exists; this flag is ignored.')
    this.enableQuotaManagement = true,
    @Deprecated('No bandwidth quota subsystem exists; this flag is ignored.')
    this.defaultBandwidthQuota = 1048576,
    this.maxConcurrentBitswapRequests = 10,
    this.datastorePath = './ipfs_data/datastore',
    this.keystorePath = './ipfs_keystore',
    this.blockStorePath = 'blocks',
    @Deprecated('No libp2p bridge transport exists; this flag is ignored.')
    this.enableLibp2pBridge = false,
    this.libp2pListenAddress = '/ip4/0.0.0.0/tcp/4001',
    this.libp2pIdentitySeed,
    String? nodeId,
    @Deprecated(
      'No repository garbage-collection loop exists; this flag is ignored.',
    )
    this.garbageCollectionInterval = const Duration(hours: 24),
    @Deprecated(
      'No repository garbage-collection loop exists; this flag is ignored.',
    )
    this.garbageCollectionEnabled = true,
    this.metrics = const MetricsConfig(),
    this.dataPath = './ipfs_data',
    Keystore? keystore,
    @Deprecated('Use GraphsyncConfig.defaultMaxDepth; this flag is ignored.')
    this.maxSelectorDepth = 32,
    @Deprecated('Use GraphsyncConfig.defaultMaxBlocks; this flag is ignored.')
    this.maxSelectorNodes = 10000,
    @Deprecated('Custom config entries are never read; this option is ignored.')
    this.customConfig = const {},
    this.swarmKeyPath,
    this.privateNetworkPsk,
  }) : network = network ?? NetworkConfig(),
       dht = dht ?? const DHTConfig(),
       // ignore: deprecated_member_use_from_same_package
       storage = storage ?? const StorageConfig(),
       security = security ?? const SecurityConfig(),
       gateway = gateway ?? const GatewayConfig(),
       bitswap = bitswap ?? const BitswapConfig(),
       graphsync = graphsync ?? const GraphsyncConfig(),
       nodeId = nodeId ?? _generateDefaultNodeId(),
       keystore = keystore ?? Keystore() {
    // Sync top-level PNET fields into the nested network config so the
    // router only has to inspect [network].
    this.network.swarmKeyPath ??= swarmKeyPath;
    this.network.privateNetworkPsk ??= privateNetworkPsk;
  }

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
      // ignore: deprecated_member_use_from_same_package
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
      graphsync: json['graphsync'] != null
          ? GraphsyncConfig.fromJson(
              Map<String, dynamic>.from(json['graphsync'] as Map),
            )
          : const GraphsyncConfig(),
      debug: json['debug'] as bool? ?? true,
      verboseLogging: json['verboseLogging'] as bool? ?? true,
      enablePubSub: json['enablePubSub'] as bool? ?? true,
      enableDHT: json['enableDHT'] as bool? ?? true,
      enableRPC: json['enableRPC'] as bool? ?? false,
      rpcApiKey: json['rpcApiKey'] as String?,
      // ignore: deprecated_member_use_from_same_package
      enableCircuitRelay: json['enableCircuitRelay'] as bool? ?? true,
      enableContentRouting: json['enableContentRouting'] as bool? ?? true,
      enableDNSLinkResolution: json['enableDNSLinkResolution'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      enableIPLD: json['enableIPLD'] as bool? ?? true,
      enableGraphsync: json['enableGraphsync'] as bool? ?? true,
      enableMetrics: json['enableMetrics'] as bool? ?? true,
      enableIpnsPubSub: json['enableIpnsPubSub'] as bool? ?? false,
      // ignore: deprecated_member_use_from_same_package
      enableLogging: json['enableLogging'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      enableStructuredLogging:
          json['enableStructuredLogging'] as bool? ?? false,
      logLevel: json['logLevel'] as String? ?? 'info',
      // ignore: deprecated_member_use_from_same_package
      enableQuotaManagement: json['enableQuotaManagement'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      defaultBandwidthQuota: json['defaultBandwidthQuota'] as int? ?? 1048576,
      maxConcurrentBitswapRequests:
          json['maxConcurrentBitswapRequests'] as int? ?? 10,
      // ignore: deprecated_member_use_from_same_package
      maxSelectorDepth: json['maxSelectorDepth'] as int? ?? 32,
      // ignore: deprecated_member_use_from_same_package
      maxSelectorNodes: json['maxSelectorNodes'] as int? ?? 10000,
      ipnsCacheSize: json['ipnsCacheSize'] as int? ?? 1000,
      // ignore: deprecated_member_use_from_same_package
      garbageCollectionInterval: Duration(
        seconds: json['garbageCollectionInterval'] as int? ?? 86400,
      ),
      // ignore: deprecated_member_use_from_same_package
      garbageCollectionEnabled:
          json['garbageCollectionEnabled'] as bool? ?? true,
      datastorePath:
          json['datastorePath'] as String? ?? './ipfs_data/datastore',
      keystorePath: json['keystorePath'] as String? ?? './ipfs_keystore',
      blockStorePath: json['blockStorePath'] as String? ?? 'blocks',
      dataPath: json['dataPath'] as String? ?? './ipfs_data',
      // ignore: deprecated_member_use_from_same_package
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
      // ignore: deprecated_member_use_from_same_package
      customConfig: Map<String, dynamic>.from(
        json['customConfig'] as Map? ?? const {},
      ),
      swarmKeyPath: json['swarmKeyPath'] as String?,
      privateNetworkPsk: null,
    );
  }

  /// Detailed network configuration.
  final NetworkConfig network;

  /// Distributed Hash Table configuration.
  final DHTConfig dht;

  /// Storage and datastore configuration.
  // ignore: deprecated_member_use_from_same_package
  final StorageConfig storage;

  /// Security and identity configuration.
  final SecurityConfig security;

  /// HTTP Gateway configuration.
  final GatewayConfig gateway;

  /// Bitswap protocol configuration.
  final BitswapConfig bitswap;

  /// Graphsync protocol configuration.
  final GraphsyncConfig graphsync;

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

  /// Optional API key required by the RPC server for protected endpoints.
  ///
  /// When set, clients must send `X-API-Key: <key>` on all non-public RPC
  /// calls. The daemon also honors the `DART_IPFS_API_KEY` environment
  /// variable.
  final String? rpcApiKey;

  /// Enable Circuit Relay support.
  ///
  /// Ignored: use [NetworkConfig.circuitRelay] (`network.circuitRelay.enabled`)
  /// instead; this flag is never read.
  final bool enableCircuitRelay;

  /// Enable content routing.
  final bool enableContentRouting;

  /// Enable DNSLink resolution.
  final bool enableDNSLinkResolution;

  /// Enable IPLD support.
  ///
  /// Ignored: IPLD is a core dependency and is always enabled.
  final bool enableIPLD;

  /// Enable Graphsync protocol.
  final bool enableGraphsync;

  /// Enable metrics collection.
  final bool enableMetrics;

  /// Enable IPNS PubSub notifications.
  ///
  /// When enabled and a PubSub handler is available, the node publishes a
  /// base64-encoded signed IPNS record after each successful DHT publish and
  /// refreshes its local IPNS cache from records announced by peers. This is
  /// a best-effort cache-update channel; the DHT remains the authoritative
  /// store, so a notification delivery failure does not fail the publish.
  final bool enableIpnsPubSub;

  /// Enable system-wide logging.
  ///
  /// Ignored: logging is always enabled; use [logLevel] to control verbosity.
  final bool enableLogging;

  /// Enable structured (JSON) logging.
  ///
  /// Ignored: no live code path reads this flag.
  final bool enableStructuredLogging;

  /// The size of the IPNS resolution cache.
  final int ipnsCacheSize;

  /// The logging level (e.g., 'info', 'debug', 'error').
  final String logLevel;

  /// Enable bandwidth quota management.
  ///
  /// Ignored: no bandwidth quota subsystem exists.
  final bool enableQuotaManagement;

  /// Default bandwidth quota in bytes.
  ///
  /// Ignored: no bandwidth quota subsystem exists.
  final int defaultBandwidthQuota;

  /// Maximum concurrent bitswap requests.
  final int maxConcurrentBitswapRequests;

  /// Maximum recursion depth for IPLD selector execution.
  ///
  /// Ignored: use [GraphsyncConfig.defaultMaxDepth] instead.
  final int maxSelectorDepth;

  /// Maximum number of nodes to visit during IPLD selector execution.
  ///
  /// Ignored: use [GraphsyncConfig.defaultMaxBlocks] instead.
  final int maxSelectorNodes;

  /// Path to the datastore.
  final String datastorePath;

  /// Path to the keystore.
  final String keystorePath;

  /// Path to the blockstore.
  final String blockStorePath;

  /// Whether to enable the libp2p bridge transport.
  ///
  /// Ignored: no libp2p bridge transport exists.
  final bool enableLibp2pBridge;

  /// Legacy single listen address for the libp2p host.
  ///
  /// Honored only when [NetworkConfig.listenAddresses] is empty; the
  /// network listen-address list is the canonical surface.
  final String libp2pListenAddress;

  /// Optional seed for persistent libp2p identity.
  final Uint8List? libp2pIdentitySeed;

  /// The unique node identifier.
  final String nodeId;

  /// Interval for garbage collection.
  ///
  /// Ignored: no repository garbage-collection loop exists.
  final Duration garbageCollectionInterval;

  /// Enable automatic garbage collection.
  ///
  /// Ignored: no repository garbage-collection loop exists.
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
  ///
  /// Ignored: no consumer reads these entries.
  final Map<String, dynamic> customConfig;

  /// Optional path to a libp2p private-network swarm key file.
  final String? swarmKeyPath;

  /// The 32-byte pre-shared key loaded from [swarmKeyPath].
  ///
  /// This is populated at runtime and is intentionally not serialized.
  final Uint8List? privateNetworkPsk;

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
    'graphsync': graphsync.toJson(),
    'debug': debug,
    'verboseLogging': verboseLogging,
    'enablePubSub': enablePubSub,
    'enableDHT': enableDHT,
    'enableRPC': enableRPC,
    'rpcApiKey': rpcApiKey,
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
    'swarmKeyPath': swarmKeyPath,
    // privateNetworkPsk is intentionally not serialized.
  };
}
