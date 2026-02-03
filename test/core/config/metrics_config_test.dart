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
      );

      final json = config.toJson();
      expect(json['enabled'], isFalse);
      expect(json['collectionIntervalSeconds'], equals(30));

      final config2 = MetricsConfig.fromJson(json);
      expect(config2.enabled, isFalse);
      expect(config2.collectionIntervalSeconds, equals(30));
      expect(config2.collectSystemMetrics, isFalse);
      expect(config2.collectNetworkMetrics, isFalse);
      expect(config2.collectStorageMetrics, isFalse);
      expect(config2.enablePrometheusExport, isTrue);
      expect(config2.prometheusEndpoint, equals('/stats'));
    });

    test('fromJson with empty Map', () {
      final config = MetricsConfig.fromJson({});
      expect(config.enabled, isTrue);
      expect(config.collectionIntervalSeconds, equals(60));
    });
  });
}

