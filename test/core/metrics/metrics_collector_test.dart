import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:test/test.dart';

void main() {
  group('MetricsCollector', () {
    late IPFSConfig config;
    late MetricsCollector collector;

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
      expect(collector.metricsConfig.enabled, isTrue);
      await collector.stop();
    });

    test('should respect enabled flag in config', () async {
      final disabledConfig = IPFSConfig(
        metrics: const MetricsConfig(enabled: false),
      );
      final disabledCollector = MetricsCollector(disabledConfig);

      await disabledCollector.start();
      disabledCollector.recordMessageSent('bitswap', 100);
      disabledCollector.recordPeerConnected();
      expect(disabledCollector.getMessagesSent('bitswap'), 0);
      expect(await disabledCollector.getPrometheusMetrics(), isEmpty);

      await disabledCollector.stop();
    });

    test('recordMessageSent records message and byte counters', () {
      collector.recordMessageSent('bitswap', 128);
      collector.recordMessageSent('bitswap', 64);
      collector.recordMessageSent('dht', 32);

      expect(collector.getMessagesSent('bitswap'), 2);
      expect(collector.getMessagesSent('dht'), 1);
      expect(collector.getBytesSent('bitswap'), 192);
      expect(collector.getBytesSent('dht'), 32);
    });

    test('recordMessageReceived records message and byte counters', () {
      collector.recordMessageReceived('bitswap', 256);
      collector.recordMessageReceived('bitswap', 44);

      expect(collector.getMessagesReceived('bitswap'), 2);
      expect(collector.getBytesReceived('bitswap'), 300);
    });

    test('recordLatency records observations and average latency', () {
      collector.recordLatency('bitswap', const Duration(milliseconds: 100));
      collector.recordLatency('bitswap', const Duration(milliseconds: 200));
      collector.recordLatency('dht', const Duration(milliseconds: 50));

      expect(collector.getAverageLatency('bitswap'), closeTo(150.0, 0.1));
      expect(collector.getAverageLatency('dht'), closeTo(50.0, 0.1));
    });

    test(
      'recordPeerConnected and recordPeerDisconnected update gauge',
      () async {
        collector.recordPeerConnected();
        collector.recordPeerConnected();
        collector.recordPeerDisconnected();

        final metrics = await collector.getPrometheusMetrics();
        expect(metrics, contains('ipfs_connected_peers'));
        expect(metrics, contains('1.0'));
      },
    );

    test(
      'recordRoutingTableSize and recordBlockstoreStats update gauges',
      () async {
        collector.recordRoutingTableSize(12);
        collector.recordBlockstoreStats(42, 12345);

        final metrics = await collector.getPrometheusMetrics();
        expect(metrics, contains('ipfs_routing_table_size'));
        expect(metrics, contains('ipfs_blockstore_blocks'));
        expect(metrics, contains('ipfs_blockstore_bytes'));
      },
    );

    test('recordGatewayRequest records counter and histogram', () async {
      collector.recordGatewayRequest(
        'ipfs',
        'GET',
        200,
        const Duration(milliseconds: 50),
      );
      collector.recordGatewayRequest(
        'ipfs',
        'GET',
        404,
        const Duration(milliseconds: 10),
      );

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('ipfs_gateway_requests_total'));
      expect(metrics, contains('ipfs_gateway_request_duration_seconds'));
      expect(metrics, contains('namespace="ipfs"'));
      expect(metrics, contains('status="200"'));
      expect(metrics, contains('status="404"'));
    });

    test('recordRpcRequest records counter and histogram', () async {
      collector.recordRpcRequest(
        '/api/v0/version',
        'POST',
        200,
        const Duration(milliseconds: 25),
      );

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('ipfs_rpc_requests_total'));
      expect(metrics, contains('ipfs_rpc_request_duration_seconds'));
      expect(metrics, contains('endpoint="/api/v0/version"'));
    });

    test('recordDhtProvide records success and failure labels', () async {
      collector.recordDhtProvide(true);
      collector.recordDhtProvide(true);
      collector.recordDhtProvide(false);

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('ipfs_dht_provides_total'));
      expect(metrics, contains('status="success"'));
      expect(metrics, contains('status="failure"'));
    });

    test('recordReprovide records runs and duration', () async {
      collector.recordReprovide(
        'pinned',
        true,
        const Duration(seconds: 1, milliseconds: 500),
      );
      collector.recordReprovide('all', false, const Duration(seconds: 2));

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('ipfs_dht_reprovide_runs_total'));
      expect(metrics, contains('ipfs_dht_reprovide_duration_seconds'));
      expect(metrics, contains('strategy="pinned"'));
      expect(metrics, contains('strategy="all"'));
    });

    test('recordSecurityEvent records type labels', () async {
      collector.recordSecurityEvent('rate_limit');
      collector.recordSecurityEvent('auth_failure');
      collector.recordSecurityEvent('blocked_cid');

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('ipfs_security_events_total'));
      expect(metrics, contains('type="rate_limit"'));
      expect(metrics, contains('type="auth_failure"'));
      expect(metrics, contains('type="blocked_cid"'));
    });

    test('getPrometheusMetrics returns Prometheus text format', () async {
      collector.recordMessageSent('bitswap', 1);
      collector.recordPeerConnected();
      collector.recordRoutingTableSize(5);
      collector.recordBlockstoreStats(10, 1024);

      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, contains('# HELP ipfs_messages_sent_total'));
      expect(metrics, contains('# TYPE ipfs_messages_sent_total counter'));
      expect(metrics, contains('ipfs_messages_sent_total'));
      expect(metrics, contains('protocol="bitswap"'));
      expect(metrics, contains('# HELP ipfs_connected_peers'));
      expect(metrics, contains('# TYPE ipfs_routing_table_size gauge'));
    });

    test('reset clears all metrics', () async {
      collector.recordMessageSent('bitswap', 100);
      collector.recordPeerConnected();
      collector.recordSecurityEvent('rate_limit');

      collector.reset();

      expect(collector.getMessagesSent('bitswap'), 0);
      final metrics = await collector.getPrometheusMetrics();
      expect(metrics, isNot(contains('protocol="bitswap"')));
      expect(metrics, isNot(contains('rate_limit')));
    });

    test('metricsStream emits records', () async {
      await collector.start();

      final events = <Map<String, dynamic>>[];
      collector.metricsStream.listen(events.add);

      collector.recordMessageSent('bitswap', 10);
      collector.recordPeerConnected();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, hasLength(2));
      expect(events.first['method'], equals('recordMessageSent'));
      expect(events.first['protocol'], equals('bitswap'));
    });

    test('updateConnectionMetrics updates legacy getters', () {
      collector.updateConnectionMetrics('peer1', {
        'messagesSent': 10,
        'messagesReceived': 5,
        'bytesSent': 1000,
        'bytesReceived': 500,
        'averageLatencyMs': 50,
      });

      expect(collector.getMessagesSent('peer1'), 10);
      expect(collector.getMessagesReceived('peer1'), 5);
      expect(collector.getBytesSent('peer1'), 1000);
      expect(collector.getBytesReceived('peer1'), 500);
      expect(collector.getAverageLatency('peer1'), closeTo(50.0, 0.1));
    });

    test(
      'recordProtocolMetrics emits stream events without crashing',
      () async {
        collector.recordProtocolMetrics('bitswap', {
          'messages_sent': 10,
          'messages_received': 5,
          'active_connections': 2,
        });
        expect(true, isTrue);
      },
    );

    test('recordError logs without crashing', () {
      try {
        throw Exception('test error');
      } catch (e, st) {
        collector.recordError('network', e, st);
      }
      expect(true, isTrue);
    });
  });
}
