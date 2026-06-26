// lib/src/core/config/bitswap_config.dart

import 'package:meta/meta.dart';

/// Configuration for the Bitswap protocol, including the optional HTTP
/// gateway fallback used when P2P block exchange fails.
class BitswapConfig {
  /// Creates a new [BitswapConfig].
  const BitswapConfig({
    this.maxConcurrentRequests = 10,
    this.httpFallbackGateways = const <String>[],
    this.p2pTimeout = const Duration(seconds: 30),
    this.httpTimeout = const Duration(seconds: 10),
    this.enableHttpFallback = false,
    this.maxHttpBlockSize = 2 * 1024 * 1024,
    this.allowPrivateGateways = false,
    @visibleForTesting this.verifyHttpBlocks = true,
  });

  /// Creates a [BitswapConfig] from a JSON map.
  factory BitswapConfig.fromJson(Map<String, dynamic> json) {
    return BitswapConfig(
      maxConcurrentRequests: json['maxConcurrentRequests'] as int? ?? 10,
      httpFallbackGateways:
          (json['httpFallbackGateways'] as List?)?.cast<String>() ??
              const <String>[],
      p2pTimeout: json['p2pTimeoutSeconds'] != null
          ? Duration(seconds: json['p2pTimeoutSeconds'] as int)
          : const Duration(seconds: 30),
      httpTimeout: json['httpTimeoutSeconds'] != null
          ? Duration(seconds: json['httpTimeoutSeconds'] as int)
          : const Duration(seconds: 10),
      enableHttpFallback: json['enableHttpFallback'] as bool? ?? false,
      maxHttpBlockSize: json['maxHttpBlockSize'] as int? ?? 2 * 1024 * 1024,
      allowPrivateGateways: json['allowPrivateGateways'] as bool? ?? false,
      // verifyHttpBlocks is intentionally not exposed in serialised config.
    );
  }

  /// Maximum number of concurrent P2P Bitswap requests.
  final int maxConcurrentRequests;

  /// Ordered list of HTTP gateway base URLs to use as a fallback.
  ///
  /// Each URL should be a trustless gateway base, e.g. `https://ipfs.io`.
  final List<String> httpFallbackGateways;

  /// Timeout applied to each P2P Bitswap request attempt.
  final Duration p2pTimeout;

  /// Timeout applied to each HTTP fallback request.
  final Duration httpTimeout;

  /// Whether the HTTP gateway fallback is enabled.
  final bool enableHttpFallback;

  /// Maximum allowed HTTP block response size in bytes.
  final int maxHttpBlockSize;

  /// Whether private/loopback gateway URLs (e.g. `127.0.0.1`) are allowed.
  final bool allowPrivateGateways;

  /// Whether to verify HTTP-fetched blocks against their CID.
  ///
  /// This is intended as a test-only override. Verification must never be
  /// disabled in production.
  final bool verifyHttpBlocks;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
        'maxConcurrentRequests': maxConcurrentRequests,
        'httpFallbackGateways': httpFallbackGateways,
        'p2pTimeoutSeconds': p2pTimeout.inSeconds,
        'httpTimeoutSeconds': httpTimeout.inSeconds,
        'enableHttpFallback': enableHttpFallback,
        'maxHttpBlockSize': maxHttpBlockSize,
        'allowPrivateGateways': allowPrivateGateways,
      };
}
