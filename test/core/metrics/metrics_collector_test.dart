import 'dart:async';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('MetricsCollector', () {
    late IPFSConfig config;
    late MetricsCollector collector;

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

    tearDown(() async {
      await collector.stop();
    });

    test('should initialize with correct status', () async {
      final status = await collector.getStatus();
      expect(status['enabled'], isTrue);
      expect(status['collection_interval'], equals(1));
    });

    test('should respect enabled flag in config', () async {
      final disabledConfig = IPFSConfig(metrics: MetricsConfig(enabled: false));
      final disabledCollector = MetricsCollector(disabledConfig);

      await disabledCollector.start();
      final status = await disabledCollector.getStatus();
      expect(status['enabled'], isFalse);

      // Recording should do nothing (no crash)
      disabledCollector.recordProtocolMetrics('test', {'val': 1});
      disabledCollector.recordError('cat', 'src', 'err');

      await disabledCollector.stop();
    });

    test('recordProtocolMetrics - message counts', () {
      collector.recordProtocolMetrics('bitswap', {
        'messages_sent': 10,
        'messages_received': 5,
        'active_connections': 2,
        'type': 'error_type',
        'message': 'something_failed',
      });

      // Verify no crash.
    });

    test('recordError tracking', () {
      collector.recordError('network', 'bitswap', 'timeout');
      collector.recordError('network', 'bitswap', 'timeout');
      collector.recordError('validation', 'bitswap', 'invalid_msg');
    });

    test('Connection metrics update and retrieval', () async {
      final peerId = 'peer123';
      final pbMetrics = ConnectionMetrics()
        ..peerId = peerId
        ..messagesSent = Int64(100)
        ..messagesReceived = Int64(50)
        ..bytesSent = Int64(2048)
        ..bytesReceived = Int64(1024)
        ..averageLatencyMs = 45;

      await collector.updateConnectionMetrics(pbMetrics);

      expect(collector.getMessagesSent(peerId).toInt(), equals(100));
      expect(collector.getMessagesReceived(peerId).toInt(), equals(50));
      expect(collector.getBytesSent(peerId).toInt(), equals(2048));
      expect(collector.getBytesReceived(peerId).toInt(), equals(1024));
      expect(collector.getAverageLatency(peerId).inMilliseconds, equals(45));
    });

    test('latency history management', () async {
      final peerId = 'peer_latency';

      for (int i = 1; i <= 110; i++) {
        final m = ConnectionMetrics()
          ..peerId = peerId
          ..averageLatencyMs = i;
        await collector.updateConnectionMetrics(m);
      }

      // Should only keep last 100.
      final avg = collector.getAverageLatency(peerId).inMilliseconds;
      expect(avg, closeTo(60, 1));
    });

    test('metricsStream emits data', () async {
      await collector.start();

      final completer = Completer<Map<String, dynamic>>();
      collector.metricsStream.listen((data) {
        if (!completer.isCompleted) completer.complete(data);
      });

      final result = await completer.future.timeout(Duration(seconds: 5));
      expect(result, contains('timestamp'));
      expect(result, contains('totalSent'));
      expect(result, contains('totalReceived'));
      expect(result, contains('peers'));
    });

    test('latency for non-existent peer', () {
      expect(collector.getAverageLatency('unknown').inMilliseconds, equals(0));
    });

    test('recordProtocolMetrics - error paths', () {
      collector.recordProtocolMetrics('invalid', {
        'messages_sent': 'not_an_int',
      });
    });
  });
}
