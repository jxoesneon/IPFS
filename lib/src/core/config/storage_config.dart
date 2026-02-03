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
  /// Creates a new [StorageConfig] with default paths and limits.
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

  /// Creates a [StorageConfig] from a JSON map.
  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      baseDir: json['baseDir'] as String? ?? '.ipfs',
      maxStorageSize: json['maxStorageSize'] as int? ?? 10 * 1024 * 1024 * 1024,
      blocksDir: json['blocksDir'] as String? ?? 'blocks',
      datastoreDir: json['datastoreDir'] as String? ?? 'datastore',
      keysDir: json['keysDir'] as String? ?? 'keys',
      enableGC: json['enableGC'] as bool? ?? true,
      gcInterval: Duration(seconds: json['gcIntervalSeconds'] as int? ?? 3600),
      maxBlockSize: json['maxBlockSize'] as int? ?? 1024 * 1024 * 2,
    );
  }

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

  /// Converts this configuration to a JSON map.
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

  /// Computed path to the block storage directory.
  String get blockPath => '$baseDir/$blocksDir';

  /// Computed path to the datastore directory.
  String get datastorePath => '$baseDir/$datastoreDir';

  /// Computed path to the keys directory.
  String get keysPath => '$baseDir/$keysDir';
}
