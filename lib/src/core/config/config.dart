// lib/src/core/config/config.dart

/// Configuration class for the IPFS node.
class IPFSConfig {
  /// Creates a new IPFSConfig with default values.
  IPFSConfig({
    this.addresses = const ['/ip4/0.0.0.0/tcp/4001', '/ip6/::/tcp/4001'],
    this.bootstrapPeers = const [
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt'
    ],
    this.datastorePath = './ipfs_data',
    this.keystorePath = './ipfs_keystore',
    this.maxConnections = 100,
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
    this.defaultDiskQuota = 1073741824, // 1 GB
    this.defaultBandwidthQuota = 1048576, // 1 MB/s
    this.garbageCollectionEnabled = true,
    this.garbageCollectionInterval = const Duration(hours: 24),
    SecurityConfig? security, // Change to nullable and provide default value below
  }) : security = security ?? SecurityConfig(); // Assign default in initializer list

  /// The addresses and ports to listen on.
  final List<String> addresses;

  /// The bootstrap peers to connect to.
  final List<String> bootstrapPeers;

  /// The path to the datastore directory.
  final String datastorePath;

  /// The path to the keystore directory.
  final String keystorePath;

  /// The maximum number of connections allowed.
  final int maxConnections;

  /// Whether to enable PubSub.
  final bool enablePubSub;

  /// Whether to enable DHT.
  final bool enableDHT;

  /// Whether to enable Circuit Relay.
  final bool enableCircuitRelay;

  /// Whether to enable content routing.
  final bool enableContentRouting;

  /// Whether to enable DNSLink resolution.
  final bool enableDNSLinkResolution;

  /// Whether to enable IPLD.
  final bool enableIPLD;

  /// Whether to enable Graphsync.
  final bool enableGraphsync;

  /// Whether to enable metrics collection.
  final bool enableMetrics;

  /// Whether to enable logging.
  final bool enableLogging;

  /// The level of logging to use.
  final String logLevel;

  /// Whether to enable quota management.
  final bool enableQuotaManagement;

  /// The default disk quota for peers (in bytes).
  final int defaultDiskQuota;

  /// The default bandwidth quota for peers (in bytes per second).
  final int defaultBandwidthQuota;

  /// Whether to enable garbage collection.
  final bool garbageCollectionEnabled;

  /// The interval for garbage collection.
  final Duration garbageCollectionInterval;

  /// Security-related configuration options.
  final SecurityConfig security;
}

/// Security-related configuration options.
class SecurityConfig {
  /// Whether to enable TLS for secure communication.
  final bool enableTLS;

  /// The path to the TLS certificate file.
  final String? tlsCertificatePath;

  /// The path to the TLS private key file.
  final String? tlsPrivateKeyPath;

  SecurityConfig({
    this.enableTLS = false,
    this.tlsCertificatePath, 
    this.tlsPrivateKeyPath, 
  });
}
