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
///   enableOpenTelemetry: true,
///   otlpEndpoint: 'http://localhost:4318/v1/metrics',
/// );
/// ```
class MetricsConfig {
  /// Creates a metrics configuration with the given options.
  /// Creates a new [MetricsConfig] with the given collection options.
  const MetricsConfig({
    this.enabled = true,
    this.collectionIntervalSeconds = 60,
    @Deprecated(
      'System metrics collection is not implemented; '
      'this option is ignored.',
    )
    this.collectSystemMetrics = true,
    this.collectNetworkMetrics = true,
    this.collectStorageMetrics = true,
    this.enablePrometheusExport = false,
    this.prometheusEndpoint = '/metrics',
    this.enableOpenTelemetry = false,
    this.otlpEndpoint = 'http://localhost:4318/v1/metrics',
    this.otlpHeaders = const {},
    this.exportIntervalSeconds = 60,
  });

  /// Creates a [MetricsConfig] from a JSON map.
  factory MetricsConfig.fromJson(Map<String, dynamic> json) {
    return MetricsConfig(
      enabled: json['enabled'] as bool? ?? true,
      collectionIntervalSeconds:
          json['collectionIntervalSeconds'] as int? ?? 60,
      // ignore: deprecated_member_use_from_same_package
      collectSystemMetrics: json['collectSystemMetrics'] as bool? ?? true,
      collectNetworkMetrics: json['collectNetworkMetrics'] as bool? ?? true,
      collectStorageMetrics: json['collectStorageMetrics'] as bool? ?? true,
      enablePrometheusExport: json['enablePrometheusExport'] as bool? ?? false,
      prometheusEndpoint: json['prometheusEndpoint'] as String? ?? '/metrics',
      enableOpenTelemetry: json['enableOpenTelemetry'] as bool? ?? false,
      otlpEndpoint:
          json['otlpEndpoint'] as String? ?? 'http://localhost:4318/v1/metrics',
      otlpHeaders:
          (json['otlpHeaders'] as Map?)?.cast<String, String>() ?? const {},
      exportIntervalSeconds: json['exportIntervalSeconds'] as int? ?? 60,
    );
  }

  /// Whether metrics collection is enabled.
  final bool enabled;

  /// How often metrics are collected, in seconds.
  final int collectionIntervalSeconds;

  /// Whether to collect CPU and memory metrics.
  ///
  /// Ignored: system metrics collection is not implemented.
  final bool collectSystemMetrics;

  /// Whether to collect network bandwidth and peer metrics.
  final bool collectNetworkMetrics;

  /// Whether to collect disk and block storage metrics.
  final bool collectStorageMetrics;

  /// Whether to expose metrics via Prometheus endpoint.
  final bool enablePrometheusExport;

  /// The HTTP path for Prometheus metrics.
  final String prometheusEndpoint;

  /// Whether to export metrics to an OpenTelemetry collector via OTLP/HTTP.
  ///
  /// Disabled by default. When enabled, metrics are pushed to [otlpEndpoint]
  /// every [exportIntervalSeconds] and once more when the collector stops.
  /// This runs alongside Prometheus export; either or both may be enabled.
  final bool enableOpenTelemetry;

  /// The OTLP/HTTP endpoint that receives `ExportMetricsServiceRequest`
  /// payloads, e.g. `http://localhost:4318/v1/metrics`.
  final String otlpEndpoint;

  /// Additional HTTP headers sent with every OTLP export request.
  ///
  /// Useful for collector authentication (for example an `Authorization`
  /// or `X-API-Key` header).
  final Map<String, String> otlpHeaders;

  /// How often metrics are pushed to [otlpEndpoint], in seconds.
  final int exportIntervalSeconds;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'collectionIntervalSeconds': collectionIntervalSeconds,
    'collectSystemMetrics': collectSystemMetrics,
    'collectNetworkMetrics': collectNetworkMetrics,
    'collectStorageMetrics': collectStorageMetrics,
    'enablePrometheusExport': enablePrometheusExport,
    'prometheusEndpoint': prometheusEndpoint,
    'enableOpenTelemetry': enableOpenTelemetry,
    'otlpEndpoint': otlpEndpoint,
    'otlpHeaders': otlpHeaders,
    'exportIntervalSeconds': exportIntervalSeconds,
  };
}
