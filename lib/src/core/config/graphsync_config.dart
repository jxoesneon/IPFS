// src/core/config/graphsync_config.dart

/// Configuration for the Graphsync protocol handler.
///
/// Defines the default budgets for selector traversal, the hard server-side
/// maxima applied to requester-supplied budgets, and whether the handler
/// should fall back to Bitswap for missing blocks.
class GraphsyncConfig {
  /// Creates a [GraphsyncConfig] with the given settings.
  const GraphsyncConfig({
    @Deprecated(
      'Graphsync availability is controlled by IPFSConfig.enableGraphsync; '
      'this flag is only echoed in handler status and is ignored.',
    )
    this.enabled = true,
    this.defaultMaxDepth = 32,
    this.defaultMaxBlocks = 1024,
    this.defaultMaxBytes = _defaultMaxBytes,
    this.maxServeDepth = 32,
    this.maxServeBlocks = 10000,
    this.maxServeBytes = _defaultMaxServeBytes,
    this.fallBackToBitswap = true,
  });

  /// Creates a [GraphsyncConfig] from a JSON map.
  factory GraphsyncConfig.fromJson(Map<String, dynamic> json) {
    return GraphsyncConfig(
      // ignore: deprecated_member_use_from_same_package
      enabled: json['enabled'] as bool? ?? true,
      defaultMaxDepth: json['defaultMaxDepth'] as int? ?? 32,
      defaultMaxBlocks: json['defaultMaxBlocks'] as int? ?? 1024,
      defaultMaxBytes: json['defaultMaxBytes'] as int? ?? _defaultMaxBytes,
      maxServeDepth: json['maxServeDepth'] as int? ?? 32,
      maxServeBlocks: json['maxServeBlocks'] as int? ?? 10000,
      maxServeBytes: json['maxServeBytes'] as int? ?? _defaultMaxServeBytes,
      fallBackToBitswap: json['fallBackToBitswap'] as bool? ?? true,
    );
  }

  static const int _defaultMaxBytes = 16 * 1024 * 1024;
  static const int _defaultMaxServeBytes = 32 * 1024 * 1024;

  /// Whether Graphsync is enabled on this node.
  ///
  /// Ignored: Graphsync availability is controlled by
  /// `IPFSConfig.enableGraphsync`; this flag is only echoed in handler
  /// status.
  final bool enabled;

  /// Default maximum traversal depth for a Graphsync request.
  ///
  /// Used when a request does not advertise a `graphsync/max-depth`
  /// extension; the effective limit is still bounded by [maxServeDepth].
  final int defaultMaxDepth;

  /// Default maximum number of blocks returned for a single request.
  ///
  /// Used when a request does not advertise a `graphsync/max-blocks`
  /// extension; the effective limit is still bounded by [maxServeBlocks].
  final int defaultMaxBlocks;

  /// Default maximum number of bytes returned for a single request.
  ///
  /// Used when a request does not advertise a `graphsync/max-bytes`
  /// extension; the effective limit is still bounded by [maxServeBytes].
  final int defaultMaxBytes;

  /// Hard upper bound on traversal depth served to a remote requester.
  ///
  /// Requester-supplied `graphsync/max-depth` values are clamped to this
  /// maximum so a peer cannot drive unbounded DAG traversal. Matches the
  /// gateway CAR export depth cap.
  final int maxServeDepth;

  /// Hard upper bound on the number of blocks served to a remote requester.
  ///
  /// Requester-supplied `graphsync/max-blocks` values are clamped to this
  /// maximum. Matches the gateway CAR export block cap.
  final int maxServeBlocks;

  /// Hard upper bound on the number of bytes served to a remote requester.
  ///
  /// Requester-supplied `graphsync/max-bytes` values are clamped to this
  /// maximum.
  final int maxServeBytes;

  /// Whether to fall back to Bitswap when a requested block is not local.
  ///
  /// Applies only to the serve path: blocks fetched this way on behalf of a
  /// remote requester are still bounded by the [maxServeBlocks] and
  /// [maxServeBytes] clamps, so a requester cannot drive unbounded remote
  /// fetching. Set to `false` to serve strictly local content.
  final bool fallBackToBitswap;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'defaultMaxDepth': defaultMaxDepth,
    'defaultMaxBlocks': defaultMaxBlocks,
    'defaultMaxBytes': defaultMaxBytes,
    'maxServeDepth': maxServeDepth,
    'maxServeBlocks': maxServeBlocks,
    'maxServeBytes': maxServeBytes,
    'fallBackToBitswap': fallBackToBitswap,
  };
}
