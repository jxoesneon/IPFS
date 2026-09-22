import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

class MockMetricsCollector implements MetricsCollector {
  final Map<String, dynamic> recordedMetrics = {};
  final List<Map<String, dynamic>> metricHistory = [];

  @override
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {
    recordedMetrics[protocol] = metrics;
    metricHistory.add({'protocol': protocol, 'metrics': metrics});
  }

  @override
  void recordSecurityEvent(String type) {
    metricHistory.add({'method': 'recordSecurityEvent', 'type': type});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Logger.root.level = Level.OFF;

  group('SecurityManager keystore getters', () {
    late SecurityConfig config;
    late MockMetricsCollector mockMetrics;
    late SecurityManager securityManager;

    setUp(() {
      config = const SecurityConfig();
      mockMetrics = MockMetricsCollector();
      securityManager = SecurityManager(config, mockMetrics);
    });

    tearDown(() async {
      await securityManager.stop();
    });

    test('keystore returns the legacy plaintext Keystore', () {
      expect(securityManager.keystore, isA<Keystore>());
    });

    test('secureKeystore returns the EncryptedKeystore', () {
      expect(securityManager.secureKeystore, isA<EncryptedKeystore>());
    });

    test('getters return stable instances', () {
      expect(
        identical(securityManager.keystore, securityManager.keystore),
        isTrue,
      );
      expect(
        identical(
          securityManager.secureKeystore,
          securityManager.secureKeystore,
        ),
        isTrue,
      );
      expect(
        identical(securityManager.keystore, securityManager.secureKeystore),
        isFalse,
      );
    });
  });
}
