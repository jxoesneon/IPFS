// src/core/config/metrics_config.dart
class MetricsConfig {
  final bool enabled;
  final int collectionIntervalSeconds;
  final bool collectSystemMetrics;
  final bool collectNetworkMetrics;
  final bool collectStorageMetrics;
  final bool enablePrometheusExport;
  final String prometheusEndpoint;

  const MetricsConfig({
    this.enabled = true,
    this.collectionIntervalSeconds = 60,
    this.collectSystemMetrics = true,
    this.collectNetworkMetrics = true,
    this.collectStorageMetrics = true,
    this.enablePrometheusExport = false,
    this.prometheusEndpoint = '/metrics',
  });

  factory MetricsConfig.fromJson(Map<String, dynamic> json) {
    return MetricsConfig(
      enabled: json['enabled'] ?? true,
      collectionIntervalSeconds: json['collectionIntervalSeconds'] ?? 60,
      collectSystemMetrics: json['collectSystemMetrics'] ?? true,
      collectNetworkMetrics: json['collectNetworkMetrics'] ?? true,
      collectStorageMetrics: json['collectStorageMetrics'] ?? true,
      enablePrometheusExport: json['enablePrometheusExport'] ?? false,
      prometheusEndpoint: json['prometheusEndpoint'] ?? '/metrics',
    );
  }

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
