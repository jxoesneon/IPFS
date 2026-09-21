import 'dart:convert';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:prometheus_client/format.dart' as format;
import 'package:test/test.dart';

/// Minimal parser for the Prometheus 0.0.4 text exposition format.
///
/// Verifies structural correctness of [MetricsCollector.getPrometheusMetrics]
/// output: HELP/TYPE header lines per family, `name{labels} value` sample
/// lines, and histogram `_bucket`/`_sum`/`_count` conventions.
class _Exposition {
  _Exposition.parse(String text) {
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('# HELP ')) {
        final rest = line.substring('# HELP '.length);
        final space = rest.indexOf(' ');
        help[rest.substring(0, space)] = rest.substring(space + 1);
      } else if (line.startsWith('# TYPE ')) {
        final rest = line.substring('# TYPE '.length);
        final space = rest.indexOf(' ');
        types[rest.substring(0, space)] = rest.substring(space + 1);
      } else if (line.startsWith('#')) {
        otherComments.add(line);
      } else {
        samples.add(_Sample.parse(line));
      }
    }
  }

  final Map<String, String> help = {};
  final Map<String, String> types = {};
  final List<_Sample> samples = [];
  final List<String> otherComments = [];

  /// Base family name for a sample: strips the histogram suffixes.
  static String familyOf(String metricName) {
    for (final suffix in const ['_bucket', '_sum', '_count']) {
      if (metricName.endsWith(suffix)) {
        return metricName.substring(0, metricName.length - suffix.length);
      }
    }
    return metricName;
  }
}

class _Sample {
  _Sample.parse(String line) {
    final braceStart = line.indexOf('{');
    final braceEnd = line.lastIndexOf('}');
    final String rest;
    if (braceStart != -1 && braceEnd > braceStart) {
      name = line.substring(0, braceStart);
      labels = _parseLabels(line.substring(braceStart + 1, braceEnd));
      rest = line.substring(braceEnd + 1).trim();
    } else {
      final space = line.indexOf(' ');
      name = line.substring(0, space);
      labels = const {};
      rest = line.substring(space + 1).trim();
    }
    value = double.parse(rest);
  }

  static Map<String, String> _parseLabels(String body) {
    final result = <String, String>{};
    // Labels are comma-separated `key="value"` pairs; the prometheus_client
    // writer emits a trailing comma before the closing brace.
    final pattern = RegExp('([a-zA-Z_][a-zA-Z0-9_]*)="((?:[^"\\\\]|\\\\.)*)"');
    for (final match in pattern.allMatches(body)) {
      result[match.group(1)!] = match.group(2)!;
    }
    return result;
  }

  late final String name;
  late final Map<String, String> labels;
  late final double value;
}

void main() {
  group('Prometheus exposition format', () {
    late MetricsCollector collector;

    setUp(() {
      collector = MetricsCollector(
        IPFSConfig(
          metrics: const MetricsConfig(
            enabled: true,
            enablePrometheusExport: true,
          ),
        ),
      );
    });

    tearDown(() async {
      await collector.stop();
    });

    test('every sample family declares HELP and TYPE headers', () async {
      collector.recordMessageSent('bitswap', 64);
      collector.recordPeerConnected();
      collector.recordRoutingTableSize(3);
      collector.recordBlockstoreStats(10, 2048);
      collector.recordLatency('bitswap', const Duration(milliseconds: 10));
      collector.recordGatewayRequest(
        'ipfs',
        'GET',
        200,
        const Duration(milliseconds: 5),
      );
      collector.recordRpcRequest(
        '/api/v0/version',
        'POST',
        200,
        const Duration(milliseconds: 1),
      );
      collector.recordDhtProvide(true);
      collector.recordReprovide('pinned', true, const Duration(seconds: 1));
      collector.recordSecurityEvent('rate_limit');

      final exposition = _Exposition.parse(
        await collector.getPrometheusMetrics(),
      );

      expect(exposition.samples, isNotEmpty);
      for (final sample in exposition.samples) {
        final family = _Exposition.familyOf(sample.name);
        expect(
          exposition.help,
          contains(family),
          reason: 'missing HELP for $family',
        );
        expect(
          exposition.types,
          contains(family),
          reason: 'missing TYPE for $family',
        );
      }

      // TYPE values must be valid metric types.
      for (final type in exposition.types.values) {
        expect(type, isIn(['counter', 'gauge', 'histogram']));
      }
    });

    test('counter samples reflect recorded increments', () async {
      collector.recordMessageSent('bitswap', 100);
      collector.recordMessageSent('bitswap', 50);
      collector.recordMessageReceived('dht', 200);
      collector.recordDhtProvide(true);
      collector.recordDhtProvide(false);
      collector.recordDhtProvide(true);

      final exposition = _Exposition.parse(
        await collector.getPrometheusMetrics(),
      );

      final sent = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_messages_sent_total' &&
            s.labels['protocol'] == 'bitswap',
      );
      expect(sent.value, 2.0);
      expect(exposition.types['ipfs_messages_sent_total'], 'counter');

      final bytesSent = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_bytes_sent_total' &&
            s.labels['protocol'] == 'bitswap',
      );
      expect(bytesSent.value, 150.0);

      final providesSuccess = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_dht_provides_total' &&
            s.labels['status'] == 'success',
      );
      final providesFailure = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_dht_provides_total' &&
            s.labels['status'] == 'failure',
      );
      expect(providesSuccess.value, 2.0);
      expect(providesFailure.value, 1.0);
    });

    test('gauge samples reflect recorded values', () async {
      collector.recordPeerConnected();
      collector.recordPeerConnected();
      collector.recordPeerDisconnected();
      collector.recordRoutingTableSize(7);
      collector.recordBlockstoreStats(42, 12345);

      final exposition = _Exposition.parse(
        await collector.getPrometheusMetrics(),
      );

      double gauge(String name) =>
          exposition.samples.firstWhere((s) => s.name == name).value;

      expect(gauge('ipfs_connected_peers'), 1.0);
      expect(gauge('ipfs_routing_table_size'), 7.0);
      expect(gauge('ipfs_blockstore_blocks'), 42.0);
      expect(gauge('ipfs_blockstore_bytes'), 12345.0);
      expect(exposition.types['ipfs_connected_peers'], 'gauge');
    });

    test('histogram emits cumulative buckets, +Inf, sum and count', () async {
      collector.recordLatency('bitswap', const Duration(milliseconds: 5));
      collector.recordLatency('bitswap', const Duration(milliseconds: 500));
      collector.recordLatency('bitswap', const Duration(seconds: 3));

      final exposition = _Exposition.parse(
        await collector.getPrometheusMetrics(),
      );
      expect(exposition.types['ipfs_latency_seconds'], 'histogram');

      final buckets =
          exposition.samples
              .where(
                (s) =>
                    s.name == 'ipfs_latency_seconds_bucket' &&
                    s.labels['protocol'] == 'bitswap',
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a.labels['le'] == '+Inf'
                          ? double.infinity
                          : double.parse(a.labels['le']!))
                      .compareTo(
                        b.labels['le'] == '+Inf'
                            ? double.infinity
                            : double.parse(b.labels['le']!),
                      ),
            );

      expect(buckets, isNotEmpty);

      // Every bucket carries an `le` label and the +Inf bucket exists.
      expect(buckets.every((s) => s.labels.containsKey('le')), isTrue);
      expect(buckets.last.labels['le'], '+Inf');

      // Bucket counts are cumulative and non-decreasing.
      for (var i = 1; i < buckets.length; i++) {
        expect(
          buckets[i].value,
          greaterThanOrEqualTo(buckets[i - 1].value),
          reason: 'bucket ${buckets[i].labels['le']} not cumulative',
        );
      }

      final count = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_latency_seconds_count' &&
            s.labels['protocol'] == 'bitswap',
      );
      final sum = exposition.samples.firstWhere(
        (s) =>
            s.name == 'ipfs_latency_seconds_sum' &&
            s.labels['protocol'] == 'bitswap',
      );

      expect(count.value, 3.0);
      // +Inf bucket must equal the total observation count.
      expect(buckets.last.value, count.value);
      // Sum is the total of observed seconds: 0.005 + 0.5 + 3.0.
      expect(sum.value, closeTo(3.505, 1e-9));
    });

    test('labels use Prometheus key="value" syntax', () async {
      collector.recordRpcRequest(
        '/api/v0/block/get',
        'POST',
        404,
        const Duration(milliseconds: 2),
      );

      final text = await collector.getPrometheusMetrics();
      expect(
        text,
        contains(
          'ipfs_rpc_requests_total'
          '{method="POST",endpoint="/api/v0/block/get",status="404",} 1.0',
        ),
      );

      // No malformed sample lines: every non-comment line parses as
      // `name{...} number` or `name number`.
      final exposition = _Exposition.parse(text);
      expect(
        exposition.samples.length,
        text
            .split('\n')
            .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
            .length,
      );
    });

    test('content type declares text/plain version 0.0.4', () {
      // The /metrics endpoint serves `format.contentType` as its
      // Content-Type header; pin the expected 0.0.4 value so a format
      // regression is caught here.
      expect(format.contentType, 'text/plain; version=0.0.4; charset=utf-8');
    });

    test('disabled collector produces empty exposition', () async {
      final disabled = MetricsCollector(
        IPFSConfig(metrics: const MetricsConfig(enabled: false)),
      );
      disabled.recordMessageSent('bitswap', 100);
      expect(await disabled.getPrometheusMetrics(), isEmpty);
      await disabled.stop();
    });
  });
}
