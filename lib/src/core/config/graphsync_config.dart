// src/core/config/graphsync_config.dart

/// Configuration for the Graphsync protocol handler.
///
/// Defines the default budgets for selector traversal and whether the handler
/// should fall back to Bitswap for missing blocks.
class GraphsyncConfig {
  /// Creates a [GraphsyncConfig] with the given settings.
  const GraphsyncConfig({
    this.enabled = true,
    this.defaultMaxDepth = 32,
    this.defaultMaxBlocks = 1024,
    this.defaultMaxBytes = _defaultMaxBytes,
    this.fallBackToBitswap = true,
  });

  /// Creates a [GraphsyncConfig] from a JSON map.
  factory GraphsyncConfig.fromJson(Map<String, dynamic> json) {
    return GraphsyncConfig(
      enabled: json['enabled'] as bool? ?? true,
      defaultMaxDepth: json['defaultMaxDepth'] as int? ?? 32,
      defaultMaxBlocks: json['defaultMaxBlocks'] as int? ?? 1024,
      defaultMaxBytes: json['defaultMaxBytes'] as int? ?? _defaultMaxBytes,
      fallBackToBitswap: json['fallBackToBitswap'] as bool? ?? true,
    );
  }

  static const int _defaultMaxBytes = 16 * 1024 * 1024;

  /// Whether Graphsync is enabled on this node.
  final bool enabled;

  /// Default maximum traversal depth for a Graphsync request.
  final int defaultMaxDepth;

  /// Default maximum number of blocks returned for a single request.
  final int defaultMaxBlocks;

  /// Default maximum number of bytes returned for a single request.
  final int defaultMaxBytes;

  /// Whether to fall back to Bitswap when a requested block is not local.
  final bool fallBackToBitswap;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'defaultMaxDepth': defaultMaxDepth,
    'defaultMaxBlocks': defaultMaxBlocks,
    'defaultMaxBytes': defaultMaxBytes,
    'fallBackToBitswap': fallBackToBitswap,
  };
}
