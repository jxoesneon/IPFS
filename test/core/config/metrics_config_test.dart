import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:test/test.dart';

void main() {
  group('MetricsConfig', () {
    test('default values', () {
      final config = MetricsConfig();
      expect(config.enabled, isTrue);
      expect(config.collectionIntervalSeconds, equals(60));
      expect(config.collectSystemMetrics, isTrue);
      expect(config.collectNetworkMetrics, isTrue);
      expect(config.collectStorageMetrics, isTrue);
      expect(config.enablePrometheusExport, isFalse);
      expect(config.prometheusEndpoint, equals('/metrics'));
      expect(config.enableOpenTelemetry, isFalse);
      expect(config.otlpEndpoint, equals('http://localhost:4318/v1/metrics'));
      expect(config.otlpHeaders, isEmpty);
      expect(config.exportIntervalSeconds, equals(60));
    });

    test('toJson and fromJson roundtrip', () {
      final config = MetricsConfig(
        enabled: false,
        collectionIntervalSeconds: 30,
        collectSystemMetrics: false,
        collectNetworkMetrics: false,
        collectStorageMetrics: false,
        enablePrometheusExport: true,
        prometheusEndpoint: '/stats',
        enableOpenTelemetry: true,
        otlpEndpoint: 'http://collector:4318/v1/metrics',
        otlpHeaders: const {'Authorization': 'Bearer tok'},
        exportIntervalSeconds: 15,
      );

      final json = config.toJson();
      expect(json['enabled'], isFalse);
      expect(json['collectionIntervalSeconds'], equals(30));
      expect(json['enableOpenTelemetry'], isTrue);
      expect(json['otlpEndpoint'], equals('http://collector:4318/v1/metrics'));
      expect(json['otlpHeaders'], equals({'Authorization': 'Bearer tok'}));
      expect(json['exportIntervalSeconds'], equals(15));

      final config2 = MetricsConfig.fromJson(json);
      expect(config2.enabled, isFalse);
      expect(config2.collectionIntervalSeconds, equals(30));
      expect(config2.collectSystemMetrics, isFalse);
      expect(config2.collectNetworkMetrics, isFalse);
      expect(config2.collectStorageMetrics, isFalse);
      expect(config2.enablePrometheusExport, isTrue);
      expect(config2.prometheusEndpoint, equals('/stats'));
      expect(config2.enableOpenTelemetry, isTrue);
      expect(config2.otlpEndpoint, equals('http://collector:4318/v1/metrics'));
      expect(config2.otlpHeaders, equals({'Authorization': 'Bearer tok'}));
      expect(config2.exportIntervalSeconds, equals(15));
    });

    test('fromJson with empty Map', () {
      final config = MetricsConfig.fromJson({});
      expect(config.enabled, isTrue);
      expect(config.collectionIntervalSeconds, equals(60));
      expect(config.enableOpenTelemetry, isFalse);
      expect(config.otlpHeaders, isEmpty);
    });
  });
}
