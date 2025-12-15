import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:test/test.dart';

void main() {
  group('MetricsCollector', () {
    late MetricsCollector collector;
    late IPFSConfig config;

    setUp(() {
      config = IPFSConfig(
        metrics: MetricsConfig(
          enabled: true,
          collectionIntervalSeconds: 1,
          collectSystemMetrics: true,
          collectNetworkMetrics: true,
          collectStorageMetrics: true,
        ),
      );
      collector = MetricsCollector(config);
    });

    test('should initialize and start/stop', () async {
      await collector.start();

      final status = await collector.getStatus();
      expect(status['enabled'], isTrue);
      expect(status['system_metrics_enabled'], isTrue);

      await collector.stop();
    });

    test('should record protocol metrics', () {
      collector.recordProtocolMetrics('bitswap', {
        'messages_sent': 10,
        'messages_received': 5,
        'active_connections': 3,
      });

      // Since internal _metrics is private, we can't inspect it directly.
      // But we can verify no exceptions were thrown.
      // Ideally implementation would expose a way to read counters or `getStatus` should return them.
      // But getStatus only returns config.

      // We can check error recording partially?
      // No, recordError also updates _metrics.
    });

    test('should update and retrieve connection metrics', () async {
      final peerId = 'peer1';
      final metrics = ConnectionMetrics(
        peerId: peerId,
        messagesSent: fixnum.Int64(10),
        messagesReceived: fixnum.Int64(5),
        bytesSent: fixnum.Int64(1000),
        bytesReceived: fixnum.Int64(500),
        averageLatencyMs: 50,
      );

      await collector.updateConnectionMetrics(metrics);

      expect(collector.getMessagesSent(peerId).toInt(), 10);
      expect(collector.getMessagesReceived(peerId).toInt(), 5);
      expect(collector.getBytesSent(peerId).toInt(), 1000);
      expect(collector.getBytesReceived(peerId).toInt(), 500);

      final latency = collector.getAverageLatency(peerId);
      expect(latency.inMilliseconds, 50);
    });

    test('should calculate average latency correctly', () async {
      final peerId = 'peer2';

      // 1st update
      await collector.updateConnectionMetrics(
        ConnectionMetrics(peerId: peerId, averageLatencyMs: 100),
      );

      // 2nd update
      await collector.updateConnectionMetrics(
        ConnectionMetrics(peerId: peerId, averageLatencyMs: 200),
      );

      final latency = collector.getAverageLatency(peerId);
      // (100 + 200) / 2 = 150
      expect(latency.inMilliseconds, 150);
    });

    test('should record errors', () {
      collector.recordError('dht', 'lookup', 'timeout');
      // Verify silent success
    });

    test('should handle disabled metrics gracefully', () async {
      final disabledConfig = IPFSConfig(metrics: MetricsConfig(enabled: false));
      final disabledCollector = MetricsCollector(disabledConfig);

      await disabledCollector.start();

      disabledCollector.recordError('test', 'source', 'msg');
      disabledCollector.recordProtocolMetrics('proto', {});

      await disabledCollector.updateConnectionMetrics(
        ConnectionMetrics(peerId: 'p1'),
      );
      // Should result in zero stats
      expect(disabledCollector.getMessagesSent('p1').toInt(), 0);

      await disabledCollector.stop();
    });
  });
}
