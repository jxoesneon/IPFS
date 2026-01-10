// src/core/config/metrics_config.dart

/// Configuration options for telemetry and metrics collection.
///
/// Controls what metrics are gathered and how they're exported.
/// Metrics can include system resources, network activity, and storage usage.
///
/// Example:
/// ```dart
/// final config = MetricsConfig(
///   enabled: true,
///   collectionIntervalSeconds: 30,
///   enablePrometheusExport: true,
/// );
/// ```
class MetricsConfig {
  /// Creates a metrics configuration with the given options.
  /// Creates a new [MetricsConfig] with the given collection options.
  const MetricsConfig({
    this.enabled = true,
    this.collectionIntervalSeconds = 60,
    this.collectSystemMetrics = true,
    this.collectNetworkMetrics = true,
    this.collectStorageMetrics = true,
    this.enablePrometheusExport = false,
    this.prometheusEndpoint = '/metrics',
  });

  /// Creates a [MetricsConfig] from a JSON map.
  factory MetricsConfig.fromJson(Map<String, dynamic> json) {
    return MetricsConfig(
      enabled: json['enabled'] as bool? ?? true,
      collectionIntervalSeconds: json['collectionIntervalSeconds'] as int? ?? 60,
      collectSystemMetrics: json['collectSystemMetrics'] as bool? ?? true,
      collectNetworkMetrics: json['collectNetworkMetrics'] as bool? ?? true,
      collectStorageMetrics: json['collectStorageMetrics'] as bool? ?? true,
      enablePrometheusExport: json['enablePrometheusExport'] as bool? ?? false,
      prometheusEndpoint: json['prometheusEndpoint'] as String? ?? '/metrics',
    );
  }

  /// Whether metrics collection is enabled.
  final bool enabled;

  /// How often metrics are collected, in seconds.
  final int collectionIntervalSeconds;

  /// Whether to collect CPU and memory metrics.
  final bool collectSystemMetrics;

  /// Whether to collect network bandwidth and peer metrics.
  final bool collectNetworkMetrics;

  /// Whether to collect disk and block storage metrics.
  final bool collectStorageMetrics;

  /// Whether to expose metrics via Prometheus endpoint.
  final bool enablePrometheusExport;

  /// The HTTP path for Prometheus metrics.
  final String prometheusEndpoint;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'collectionIntervalSeconds': collectionIntervalSeconds,
    'collectSystemMetrics': collectSystemMetrics,
    'collectNetworkMetrics': collectNetworkMetrics,
    'collectStorageMetrics': collectStorageMetrics,
    'enablePrometheusExport': enablePrometheusExport,
    'prometheusEndpoint': prometheusEndpoint,
  };
}
