/// Configuration options for the DHT (Distributed Hash Table)
///
/// This class holds settings for Kademlia DHT operations, such as
/// lookup parallelization, bucket sizes, and request timeouts.
class DHTConfig {
  /// Creates a new [DHTConfig] with default Kademlia settings.
  const DHTConfig({
    @Deprecated(
      'The Kademlia protocol ID is hardcoded in the DHT client; '
      'this option is ignored.',
    )
    this.protocolId = '/ipfs/kad/1.0.0',
    this.alpha = 3,
    this.bucketSize = 20,
    @Deprecated(
      'Provider record counts are not limited by config; '
      'this option is ignored.',
    )
    this.maxProvidersPerKey = 20,
    this.requestTimeout = const Duration(seconds: 30),
    @Deprecated(
      'Query result counts are not limited by config; '
      'this option is ignored.',
    )
    this.maxRecordsPerQuery = 20,
    @Deprecated('Provider records are always stored; this option is ignored.')
    this.enableProviderRecording = true,
    @Deprecated('Value storage is always enabled; this option is ignored.')
    this.enableValueStorage = true,
    this.validateProviderRecords = true,
    this.reproviderEnabled = true,
    this.reproviderInterval = const Duration(hours: 12),
    this.reproviderStrategy = 'pinned',
    this.reproviderBatchSize = 100,
    this.reproviderConcurrency = 10,
    this.reproviderSweepOptimization = true,
  });

  /// Creates a DHTConfig from JSON.
  ///
  /// @param json The JSON map to parse.
  /// @return A new [DHTConfig] instance.
  factory DHTConfig.fromJson(Map<String, dynamic> json) {
    return DHTConfig(
      // ignore: deprecated_member_use_from_same_package
      protocolId: (json['protocolId'] as String?) ?? '/ipfs/kad/1.0.0',
      alpha: (json['alpha'] as int?) ?? 3,
      bucketSize: (json['bucketSize'] as int?) ?? 20,
      // ignore: deprecated_member_use_from_same_package
      maxProvidersPerKey: (json['maxProvidersPerKey'] as int?) ?? 20,
      requestTimeout: Duration(
        seconds: (json['requestTimeoutSeconds'] as int?) ?? 30,
      ),
      // ignore: deprecated_member_use_from_same_package
      maxRecordsPerQuery: (json['maxRecordsPerQuery'] as int?) ?? 20,
      // ignore: deprecated_member_use_from_same_package
      enableProviderRecording:
          (json['enableProviderRecording'] as bool?) ?? true,
      // ignore: deprecated_member_use_from_same_package
      enableValueStorage: (json['enableValueStorage'] as bool?) ?? true,
      validateProviderRecords:
          (json['validateProviderRecords'] as bool?) ?? true,
      reproviderEnabled: (json['reproviderEnabled'] as bool?) ?? true,
      reproviderInterval: Duration(
        seconds: (json['reproviderIntervalSeconds'] as int?) ?? 43200,
      ),
      reproviderStrategy: (json['reproviderStrategy'] as String?) ?? 'pinned',
      reproviderBatchSize: (json['reproviderBatchSize'] as int?) ?? 100,
      reproviderConcurrency: (json['reproviderConcurrency'] as int?) ?? 10,
      reproviderSweepOptimization:
          (json['reproviderSweepOptimization'] as bool?) ?? true,
    );
  }

  /// Protocol identifier for DHT.
  ///
  /// Ignored: the Kademlia protocol ID is hardcoded in the DHT client.
  final String protocolId;

  /// Number of parallel lookups (alpha value in Kademlia).
  final int alpha;

  /// Size of k-buckets.
  final int bucketSize;

  /// Maximum number of providers to store per key.
  ///
  /// Ignored: provider record counts are not limited by config.
  final int maxProvidersPerKey;

  /// Time to wait before considering a request as failed.
  final Duration requestTimeout;

  /// Maximum number of records to return per query.
  ///
  /// Ignored: query result counts are not limited by config.
  final int maxRecordsPerQuery;

  /// Whether to enable provider recording.
  ///
  /// Ignored: provider records are always stored.
  final bool enableProviderRecording;

  /// Whether to enable value storage.
  ///
  /// Ignored: value storage is always enabled.
  final bool enableValueStorage;

  /// Whether to validate incoming provider records for address sanity and
  /// freshness before trusting them.
  final bool validateProviderRecords;

  /// Whether the periodic reprovider service is enabled.
  final bool reproviderEnabled;

  /// Interval between automatic reprovide runs.
  final Duration reproviderInterval;

  /// Reprovide strategy name (e.g. `pinned`, `roots`, `all`, `pinned+mfs`,
  /// `unique`, `entities`).
  final String reproviderStrategy;

  /// Maximum number of CIDs to announce in a single batch.
  final int reproviderBatchSize;

  /// Maximum number of concurrent in-flight provide announcements.
  final int reproviderConcurrency;

  /// Whether to enable XOR-ordered proximity grouping for reprovides.
  final bool reproviderSweepOptimization;

  /// Converts the config to JSON.
  ///
  /// @return A map representing the configuration.
  Map<String, dynamic> toJson() => {
    'protocolId': protocolId,
    'alpha': alpha,
    'bucketSize': bucketSize,
    'maxProvidersPerKey': maxProvidersPerKey,
    'requestTimeoutSeconds': requestTimeout.inSeconds,
    'maxRecordsPerQuery': maxRecordsPerQuery,
    'enableProviderRecording': enableProviderRecording,
    'enableValueStorage': enableValueStorage,
    'validateProviderRecords': validateProviderRecords,
    'reproviderEnabled': reproviderEnabled,
    'reproviderIntervalSeconds': reproviderInterval.inSeconds,
    'reproviderStrategy': reproviderStrategy,
    'reproviderBatchSize': reproviderBatchSize,
    'reproviderConcurrency': reproviderConcurrency,
    'reproviderSweepOptimization': reproviderSweepOptimization,
  };
}
