/// Configuration options for IPFS storage.
///
/// Controls storage paths, size limits, and garbage collection settings.
///
/// Example:
/// ```dart
/// final config = StorageConfig(
///   baseDir: '/var/ipfs',
///   maxStorageSize: 50 * 1024 * 1024 * 1024, // 50GB
///   enableGC: true,
/// );
/// ```
class StorageConfig {
  /// Base directory for all IPFS data
  final String baseDir;

  /// Maximum storage size in bytes
  final int maxStorageSize;

  /// Directory for block storage
  final String blocksDir;

  /// Directory for datastore
  final String datastoreDir;

  /// Directory for keys
  final String keysDir;

  /// Whether to enable garbage collection
  final bool enableGC;

  /// Garbage collection interval
  final Duration gcInterval;

  /// Maximum size for a single block
  final int maxBlockSize;

  const StorageConfig({
    this.baseDir = '.ipfs',
    this.maxStorageSize = 10 * 1024 * 1024 * 1024, // 10GB default
    this.blocksDir = 'blocks',
    this.datastoreDir = 'datastore',
    this.keysDir = 'keys',
    this.enableGC = true,
    this.gcInterval = const Duration(hours: 1),
    this.maxBlockSize = 1024 * 1024 * 2, // 2MB default
  });

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      baseDir: json['baseDir'] ?? '.ipfs',
      maxStorageSize: json['maxStorageSize'] ?? 10 * 1024 * 1024 * 1024,
      blocksDir: json['blocksDir'] ?? 'blocks',
      datastoreDir: json['datastoreDir'] ?? 'datastore',
      keysDir: json['keysDir'] ?? 'keys',
      enableGC: json['enableGC'] ?? true,
      gcInterval: Duration(
        seconds: json['gcIntervalSeconds'] ?? 3600,
      ),
      maxBlockSize: json['maxBlockSize'] ?? 1024 * 1024 * 2,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseDir': baseDir,
        'maxStorageSize': maxStorageSize,
        'blocksDir': blocksDir,
        'datastoreDir': datastoreDir,
        'keysDir': keysDir,
        'enableGC': enableGC,
        'gcIntervalSeconds': gcInterval.inSeconds,
        'maxBlockSize': maxBlockSize,
      };

  String get blockPath => '$baseDir/$blocksDir';
  String get datastorePath => '$baseDir/$datastoreDir';
  String get keysPath => '$baseDir/$keysDir';
}
