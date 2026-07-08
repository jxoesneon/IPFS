import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:test/test.dart';

void main() {
  group('MetricsCollector', () {
    late MetricsCollector collector;
    late IPFSConfig config;

    setUp(() {
      config = IPFSConfig(
        metrics: const MetricsConfig(
          enabled: true,
          collectionIntervalSeconds: 1,
          collectSystemMetrics: true,
          collectNetworkMetrics: true,
          collectStorageMetrics: true,
        ),
      );
      collector = MetricsCollector(config);
    });

    tearDown(() async {
      await collector.stop();
    });

    test('should initialize and start/stop', () async {
      await collector.start();
      await collector.stop();
      expect(true, isTrue);
    });

    test('should record protocol metrics', () {
      collector.recordProtocolMetrics('bitswap', {
        'messages_sent': 10,
        'messages_received': 5,
        'active_connections': 3,
      });
      expect(true, isTrue);
    });

    test('should update and retrieve connection metrics', () async {
      final peerId = 'peer1';
      final metrics = {
        'messagesSent': 10,
        'messagesReceived': 5,
        'bytesSent': 1000,
        'bytesReceived': 500,
        'averageLatencyMs': 50,
      };

      collector.updateConnectionMetrics(peerId, metrics);

      expect(collector.getMessagesSent(peerId), 10);
      expect(collector.getMessagesReceived(peerId), 5);
      expect(collector.getBytesSent(peerId), 1000);
      expect(collector.getBytesReceived(peerId), 500);
      expect(collector.getAverageLatency(peerId), closeTo(50.0, 0.1));
    });

    test('should calculate average latency correctly', () async {
      final peerId = 'peer2';

      collector.updateConnectionMetrics(peerId, {'averageLatencyMs': 100});
      collector.updateConnectionMetrics(peerId, {'averageLatencyMs': 200});

      expect(collector.getAverageLatency(peerId), closeTo(150.0, 0.1));
    });

    test('should record errors', () {
      try {
        throw Exception('test error');
      } catch (e, st) {
        collector.recordError('dht', e, st);
      }
      expect(true, isTrue);
    });

    test('should handle disabled metrics gracefully', () async {
      final disabledConfig = IPFSConfig(
        metrics: const MetricsConfig(enabled: false),
      );
      final disabledCollector = MetricsCollector(disabledConfig);

      await disabledCollector.start();

      try {
        throw Exception('test error');
      } catch (e, st) {
        disabledCollector.recordError('test', e, st);
      }
      disabledCollector.recordProtocolMetrics('proto', {});
      disabledCollector.updateConnectionMetrics('p1', {});
      disabledCollector.recordMessageSent('bitswap', 100);

      expect(disabledCollector.getMessagesSent('p1'), 0);
      expect(disabledCollector.getMessagesSent('bitswap'), 0);

      await disabledCollector.stop();
    });

    test('should expose Prometheus metrics for P2P traffic', () async {
      collector.recordMessageSent('bitswap', 64);
      collector.recordMessageReceived('bitswap', 128);
      collector.recordLatency('bitswap', const Duration(milliseconds: 10));

      final output = await collector.getPrometheusMetrics();
      expect(output, contains('ipfs_messages_sent_total'));
      expect(output, contains('ipfs_messages_received_total'));
      expect(output, contains('ipfs_bytes_sent_total'));
      expect(output, contains('ipfs_bytes_received_total'));
      expect(output, contains('ipfs_latency_seconds'));
      expect(output, contains('protocol="bitswap"'));
    });

    test('should expose Prometheus metrics for node state', () async {
      collector.recordPeerConnected();
      collector.recordRoutingTableSize(7);
      collector.recordBlockstoreStats(3, 4096);

      final output = await collector.getPrometheusMetrics();
      expect(output, contains('ipfs_connected_peers'));
      expect(output, contains('ipfs_routing_table_size'));
      expect(output, contains('ipfs_blockstore_blocks'));
      expect(output, contains('ipfs_blockstore_bytes'));
    });
  });
}
