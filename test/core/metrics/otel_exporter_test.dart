import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/metrics/otel_exporter.dart';
import 'package:prometheus_client/prometheus_client.dart';
import 'package:test/test.dart';

/// Binds a loopback HTTP server that captures request bodies and replies
/// with [statusCode].
Future<HttpServer> _startCapturingServer(
  List<HttpRequest> requests,
  List<String> bodies, {
  int statusCode = 200,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requests.add(request);
    bodies.add(await utf8.decodeStream(request));
    request.response.statusCode = statusCode;
    await request.response.close();
  });
  return server;
}

Map<String, dynamic> _decodeBody(String body) =>
    jsonDecode(body) as Map<String, dynamic>;

List<dynamic> _metricsOf(Map<String, dynamic> payload) {
  final resourceMetrics = payload['resourceMetrics'] as List<dynamic>;
  final scopeMetrics =
      (resourceMetrics.first as Map<String, dynamic>)['scopeMetrics']
          as List<dynamic>;
  return (scopeMetrics.first as Map<String, dynamic>)['metrics']
      as List<dynamic>;
}

void main() {
  group('OTelExporter payload', () {
    late CollectorRegistry registry;
    late OTelExporter exporter;

    setUp(() {
      registry = CollectorRegistry();
      exporter = OTelExporter(
        endpoint: Uri.parse('http://localhost:4318/v1/metrics'),
      );
    });

    tearDown(() async {
      await exporter.close();
    });

    test('converts counter families to monotonic cumulative sums', () async {
      final counter = Counter(
        name: 'test_hits_total',
        help: 'Total hits.',
        labelNames: ['path'],
      )..register(registry);
      counter.labels(['/a']).inc(2);

      final families = await registry.collectMetricFamilySamples();
      final payload = exporter.buildMetricsPayload(families);
      final metrics = _metricsOf(payload);

      final hits =
          metrics.firstWhere(
                (m) => (m as Map<String, dynamic>)['name'] == 'test_hits_total',
              )
              as Map<String, dynamic>;
      final sum = hits['sum'] as Map<String, dynamic>;
      expect(sum['aggregationTemporality'], equals(2));
      expect(sum['isMonotonic'], isTrue);

      final point =
          (sum['dataPoints'] as List<dynamic>).single as Map<String, dynamic>;
      expect(point['asDouble'], equals(2.0));
      expect(point['startTimeUnixNano'], isA<String>());
      expect(point['timeUnixNano'], isA<String>());
      expect(
        point['attributes'],
        equals([
          {
            'key': 'path',
            'value': {'stringValue': '/a'},
          },
        ]),
      );
    });

    test('converts gauge families to gauge data points', () async {
      final gauge = Gauge(name: 'test_peers', help: 'Connected peers.')
        ..register(registry);
      gauge.value = 7;

      final families = await registry.collectMetricFamilySamples();
      final payload = exporter.buildMetricsPayload(families);
      final metrics = _metricsOf(payload);

      final peers =
          metrics.firstWhere(
                (m) => (m as Map<String, dynamic>)['name'] == 'test_peers',
              )
              as Map<String, dynamic>;
      final points =
          (peers['gauge'] as Map<String, dynamic>)['dataPoints']
              as List<dynamic>;
      expect((points.single as Map<String, dynamic>)['asDouble'], equals(7.0));
    });

    test('converts histogram families to OTLP histograms', () async {
      final histogram = Histogram(
        name: 'test_latency_seconds',
        help: 'Latency.',
        labelNames: ['protocol'],
        buckets: const [0.1, 0.5, 1.0],
      )..register(registry);
      histogram.labels(['bitswap']).observe(0.05);
      histogram.labels(['bitswap']).observe(0.3);
      histogram.labels(['bitswap']).observe(0.9);

      final families = await registry.collectMetricFamilySamples();
      final payload = exporter.buildMetricsPayload(families);
      final metrics = _metricsOf(payload);

      final latency =
          metrics.firstWhere(
                (m) =>
                    (m as Map<String, dynamic>)['name'] ==
                    'test_latency_seconds',
              )
              as Map<String, dynamic>;
      final histogramData = latency['histogram'] as Map<String, dynamic>;
      expect(histogramData['aggregationTemporality'], equals(2));

      final point =
          (histogramData['dataPoints'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(point['count'], equals('3'));
      expect(point['sum'], closeTo(1.25, 0.001));
      // Cumulative Prometheus buckets are de-cumulated for OTLP.
      expect(point['bucketCounts'], equals(['1', '1', '1', '0']));
      // The +Inf bound is implicit and must not appear in explicitBounds.
      expect(point['explicitBounds'], equals([0.1, 0.5, 1.0]));
      expect(
        point['attributes'],
        equals([
          {
            'key': 'protocol',
            'value': {'stringValue': 'bitswap'},
          },
        ]),
      );
    });

    test('includes service.name resource attribute', () async {
      final gauge = Gauge(name: 'test_g', help: 'g')..register(registry);
      gauge.inc();

      final payload = exporter.buildMetricsPayload(
        await registry.collectMetricFamilySamples(),
      );
      final resource =
          ((payload['resourceMetrics'] as List<dynamic>).first
                  as Map<String, dynamic>)['resource']
              as Map<String, dynamic>;
      expect(
        resource['attributes'],
        equals([
          {
            'key': 'service.name',
            'value': {'stringValue': 'dart_ipfs'},
          },
        ]),
      );
    });
  });

  group('OTelExporter HTTP export', () {
    late HttpServer server;
    late List<HttpRequest> requests;
    late List<String> bodies;

    tearDown(() async {
      await server.close(force: true);
    });

    test('POSTs OTLP JSON with configured headers', () async {
      requests = [];
      bodies = [];
      server = await _startCapturingServer(requests, bodies);

      final exporter = OTelExporter(
        endpoint: Uri.parse('http://localhost:${server.port}/v1/metrics'),
        headers: {'Authorization': 'Bearer test-token'},
      );
      addTearDown(exporter.close);

      final registry = CollectorRegistry();
      final counter = Counter(
        name: 'test_exported_total',
        help: 'Exported counter.',
      )..register(registry);
      counter.inc(5);

      await exporter.export(await registry.collectMetricFamilySamples());

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, equals('POST'));
      expect(request.uri.path, equals('/v1/metrics'));
      expect(request.headers.contentType?.mimeType, equals('application/json'));
      expect(
        request.headers.value('authorization'),
        equals('Bearer test-token'),
      );

      final payload = _decodeBody(bodies.single);
      final metrics = _metricsOf(payload);
      expect(
        metrics.map((m) => (m as Map<String, dynamic>)['name']),
        contains('test_exported_total'),
      );
    });

    test('throws OTelExportException on non-2xx responses', () async {
      requests = [];
      bodies = [];
      server = await _startCapturingServer(requests, bodies, statusCode: 400);

      final exporter = OTelExporter(
        endpoint: Uri.parse('http://localhost:${server.port}/v1/metrics'),
      );
      addTearDown(exporter.close);

      await expectLater(
        exporter.export(const <MetricFamilySamples>[]),
        throwsA(
          isA<OTelExportException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(400),
          ),
        ),
      );
    });

    test('throws OTelExportException after close', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final exporter = OTelExporter(
        endpoint: Uri.parse('http://localhost:${server.port}/v1/metrics'),
      );
      await exporter.close();

      await expectLater(
        exporter.export(const <MetricFamilySamples>[]),
        throwsA(isA<OTelExportException>()),
      );
    });
  });

  group('MetricsCollector OTLP integration', () {
    late HttpServer server;
    late List<HttpRequest> requests;
    late List<String> bodies;

    setUp(() async {
      requests = [];
      bodies = [];
      server = await _startCapturingServer(requests, bodies);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('does not export when OpenTelemetry is disabled', () async {
      final collector = MetricsCollector(
        IPFSConfig(metrics: const MetricsConfig(enabled: true)),
      );
      addTearDown(collector.stop);

      await collector.start();
      collector.recordMessageSent('bitswap', 10);
      await collector.flushOpenTelemetry();

      expect(bodies, isEmpty);
    });

    test('flushOpenTelemetry POSTs current metrics to the endpoint', () async {
      final collector = MetricsCollector(
        IPFSConfig(
          metrics: MetricsConfig(
            enabled: true,
            enableOpenTelemetry: true,
            otlpEndpoint: 'http://localhost:${server.port}/v1/metrics',
          ),
        ),
      );
      addTearDown(collector.stop);

      await collector.start();
      collector.recordMessageSent('bitswap', 42);
      collector.recordPeerConnected();

      await collector.flushOpenTelemetry();

      expect(bodies, hasLength(1));
      final payload = _decodeBody(bodies.single);
      final metrics = _metricsOf(payload);
      final names = metrics.map((m) => (m as Map<String, dynamic>)['name']);
      expect(names, contains('ipfs_messages_sent_total'));
      expect(names, contains('ipfs_connected_peers'));
    });

    test('stop performs a final flush', () async {
      final collector = MetricsCollector(
        IPFSConfig(
          metrics: MetricsConfig(
            enabled: true,
            enableOpenTelemetry: true,
            otlpEndpoint: 'http://localhost:${server.port}/v1/metrics',
          ),
        ),
      );

      await collector.start();
      collector.recordSecurityEvent('rate_limit');
      await collector.stop();

      expect(bodies, isNotEmpty);
      final payload = _decodeBody(bodies.last);
      final names = _metricsOf(
        payload,
      ).map((m) => (m as Map<String, dynamic>)['name']);
      expect(names, contains('ipfs_security_events_total'));
    });

    test('periodic export fires on the configured interval', () async {
      final collector = MetricsCollector(
        IPFSConfig(
          metrics: MetricsConfig(
            enabled: true,
            enableOpenTelemetry: true,
            otlpEndpoint: 'http://localhost:${server.port}/v1/metrics',
            exportIntervalSeconds: 1,
          ),
        ),
      );
      addTearDown(collector.stop);

      await collector.start();
      collector.recordPeerConnected();

      // Wait for at least one periodic export.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (bodies.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(bodies, isNotEmpty);
    });

    test('invalid endpoint disables OTLP export without throwing', () async {
      final collector = MetricsCollector(
        IPFSConfig(
          metrics: const MetricsConfig(
            enabled: true,
            enableOpenTelemetry: true,
            otlpEndpoint: '::not a uri::',
          ),
        ),
      );
      addTearDown(collector.stop);

      await collector.start();
      await collector.flushOpenTelemetry();
      expect(bodies, isEmpty);
    });

    test('unreachable endpoint is logged and swallowed on flush', () async {
      final port = server.port;
      await server.close(force: true);
      final collector = MetricsCollector(
        IPFSConfig(
          metrics: MetricsConfig(
            enabled: true,
            enableOpenTelemetry: true,
            otlpEndpoint: 'http://localhost:$port/v1/metrics',
          ),
        ),
      );
      addTearDown(collector.stop);

      await collector.start();
      // Port is closed; flush must not throw.
      await collector.flushOpenTelemetry();
    });
  });
}
