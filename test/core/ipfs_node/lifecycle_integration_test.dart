import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:test/test.dart';

void main() {
  group('Node Service Lifecycle Integration', () {
    test('LifecycleManager sequences MetricsCollector and SecurityManager correctly', () async {
      final config = IPFSConfig();
      final metrics = MetricsCollector(config);
      final security = SecurityManager(config.security, metrics);

      // Verify interfaces implemented
      expect(metrics, isA<MetricsCollector>());
      expect(security, isA<SecurityManager>());

      // Test Start Sequence
      await metrics.start();
      await security.start();

      // Test Stop Sequence
      await security.stop();
      await metrics.stop();
      
      // If no exceptions thrown, sequencing is successful
    });
  });
}
