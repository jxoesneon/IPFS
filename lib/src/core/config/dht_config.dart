/// Configuration options for the DHT (Distributed Hash Table)
class DHTConfig {
  /// Protocol identifier for DHT
  final String protocolId;

  /// Number of parallel lookups (alpha value in Kademlia)
  final int alpha;

  /// Size of k-buckets
  final int bucketSize;

  /// Maximum number of providers to store per key
  final int maxProvidersPerKey;

  /// Time to wait before considering a request as failed
  final Duration requestTimeout;

  /// Maximum number of records to return per query
  final int maxRecordsPerQuery;

  /// Whether to enable provider recording
  final bool enableProviderRecording;

  /// Whether to enable value storage
  final bool enableValueStorage;

  const DHTConfig({
    this.protocolId = '/ipfs/kad/1.0.0',
    this.alpha = 3,
    this.bucketSize = 20,
    this.maxProvidersPerKey = 20,
    this.requestTimeout = const Duration(seconds: 30),
    this.maxRecordsPerQuery = 20,
    this.enableProviderRecording = true,
    this.enableValueStorage = true,
  });

  /// Creates a DHTConfig from JSON
  factory DHTConfig.fromJson(Map<String, dynamic> json) {
    return DHTConfig(
      protocolId: (json['protocolId'] as String?) ?? '/ipfs/kad/1.0.0',
      alpha: (json['alpha'] as int?) ?? 3,
      bucketSize: (json['bucketSize'] as int?) ?? 20,
      maxProvidersPerKey: (json['maxProvidersPerKey'] as int?) ?? 20,
      requestTimeout: Duration(
        seconds: (json['requestTimeoutSeconds'] as int?) ?? 30,
      ),
      maxRecordsPerQuery: (json['maxRecordsPerQuery'] as int?) ?? 20,
      enableProviderRecording:
          (json['enableProviderRecording'] as bool?) ?? true,
      enableValueStorage: (json['enableValueStorage'] as bool?) ?? true,
    );
  }

  /// Converts the config to JSON
  Map<String, dynamic> toJson() => {
    'protocolId': protocolId,
    'alpha': alpha,
    'bucketSize': bucketSize,
    'maxProvidersPerKey': maxProvidersPerKey,
    'requestTimeoutSeconds': requestTimeout.inSeconds,
    'maxRecordsPerQuery': maxRecordsPerQuery,
    'enableProviderRecording': enableProviderRecording,
    'enableValueStorage': enableValueStorage,
  };
}
