// src/core/metrics/otel_exporter.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prometheus_client/prometheus_client.dart';

import '../../utils/logger.dart';

/// OTLP `AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE`.
///
/// All metrics collected by [MetricsCollector] are cumulative since process
/// start, so every exported data point uses this temporality.
const int _aggregationTemporalityCumulative = 2;

/// Thrown when an OTLP export request fails or is rejected by the collector.
class OTelExportException implements Exception {
  /// Creates an exception describing a failed OTLP export.
  OTelExportException(this.message, {this.statusCode});

  /// Human-readable failure description.
  final String message;

  /// HTTP status code returned by the collector, when available.
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'OTelExportException: $message'
      : 'OTelExportException: $message (HTTP $statusCode)';
}

/// Exports metrics to an OpenTelemetry collector over OTLP/HTTP.
///
/// OTelExporter converts the [MetricFamilySamples] produced by the
/// `prometheus_client`-backed registry into an OTLP
/// `ExportMetricsServiceRequest` JSON document and POSTs it to a configured
/// endpoint. The implementation is dependency-free beyond `package:http`
/// (already a dependency of this package); protobuf encoding is not used.
///
/// Metric type mapping:
/// - Prometheus counters become OTLP `sum` data points with cumulative
///   aggregation temporality and `isMonotonic: true`.
/// - Prometheus gauges become OTLP `gauge` data points.
/// - Prometheus histograms become OTLP `histogram` data points. Prometheus
///   cumulative `_bucket` samples are converted to OTLP non-cumulative
///   `bucketCounts`, and the `+Inf` bound is dropped from `explicitBounds`
///   per the OTLP data model.
/// - Summaries and untyped families fall back to `gauge` data points.
///
/// Scope note: this repository has no tracing abstraction, so only metrics
/// are exported. No spans or traces are bridged; if a tracing layer is added
/// later, it should plug in as a peer to this exporter.
///
/// The exporter is disabled by default; see
/// [MetricsConfig.enableOpenTelemetry].
///
/// Example:
/// ```dart
/// final exporter = OTelExporter(
///   endpoint: Uri.parse('http://localhost:4318/v1/metrics'),
///   headers: {'Authorization': 'Bearer token'},
/// );
/// await exporter.export(await registry.collectMetricFamilySamples());
/// await exporter.close();
/// ```
class OTelExporter {
  /// Creates an OTLP/HTTP exporter that POSTs to [endpoint].
  ///
  /// [headers] are merged into every request on top of the default
  /// `Content-Type: application/json` header. [serviceName] is reported as
  /// the `service.name` resource attribute. An optional [httpClient] may be
  /// injected for testing; otherwise the exporter owns and closes its
  /// client in [close].
  OTelExporter({
    required Uri endpoint,
    Map<String, String> headers = const {},
    String serviceName = 'dart_ipfs',
    http.Client? httpClient,
    Logger? logger,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _endpoint = endpoint,
       _headers = Map.unmodifiable(headers),
       _serviceName = serviceName,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _logger = logger ?? Logger('OTelExporter'),
       _requestTimeout = requestTimeout;

  final Uri _endpoint;
  final Map<String, String> _headers;
  final String _serviceName;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Logger _logger;
  final Duration _requestTimeout;

  /// Time the exporter was created; used as `startTimeUnixNano` for
  /// cumulative data points.
  final int _startTimeUnixNano = DateTime.now().microsecondsSinceEpoch * 1000;

  bool _closed = false;

  /// The endpoint this exporter POSTs to.
  Uri get endpoint => _endpoint;

  /// Builds the OTLP `ExportMetricsServiceRequest` JSON document for
  /// [families].
  ///
  /// [timestamp] overrides the data point timestamp (defaults to now);
  /// [startTimestamp] overrides the cumulative start timestamp (defaults to
  /// exporter construction time). Exposed for testing and for callers that
  /// want to control the reported time window.
  Map<String, dynamic> buildMetricsPayload(
    Iterable<MetricFamilySamples> families, {
    DateTime? timestamp,
    DateTime? startTimestamp,
  }) {
    final timeUnixNano =
        (timestamp ?? DateTime.now()).microsecondsSinceEpoch * 1000;
    final startTimeUnixNano = startTimestamp != null
        ? startTimestamp.microsecondsSinceEpoch * 1000
        : _startTimeUnixNano;

    final metrics = <Map<String, dynamic>>[];
    for (final family in families) {
      final metric = _convertFamily(family, startTimeUnixNano, timeUnixNano);
      if (metric != null) {
        metrics.add(metric);
      }
    }

    return {
      'resourceMetrics': [
        {
          'resource': {
            'attributes': [_attribute('service.name', _serviceName)],
          },
          'scopeMetrics': [
            {
              'scope': {'name': 'dart_ipfs'},
              'metrics': metrics,
            },
          ],
        },
      ],
    };
  }

  /// Exports [families] to the configured endpoint as a single OTLP
  /// `ExportMetricsServiceRequest`.
  ///
  /// Throws [OTelExportException] when the request fails or the collector
  /// responds with a non-2xx status. Callers that export periodically should
  /// catch and log; a failed export must never take down metric recording.
  Future<void> export(Iterable<MetricFamilySamples> families) async {
    if (_closed) {
      throw OTelExportException('Exporter is closed');
    }

    final body = jsonEncode(buildMetricsPayload(families));
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {'Content-Type': 'application/json', ..._headers},
            body: body,
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw OTelExportException(
        'OTLP export to $_endpoint timed out after $_requestTimeout',
      );
    } on Object catch (e) {
      throw OTelExportException('OTLP export to $_endpoint failed: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OTelExportException(
        'OTLP export to $_endpoint was rejected',
        statusCode: response.statusCode,
      );
    }

    _logger.debug(
      'Exported ${body.length} bytes of OTLP metrics to $_endpoint '
      '(HTTP ${response.statusCode})',
    );
  }

  /// Closes the exporter and releases the underlying HTTP client when it is
  /// owned by this exporter.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  // --------------------------------------------------------------------------
  // OTLP conversion helpers
  // --------------------------------------------------------------------------

  Map<String, dynamic>? _convertFamily(
    MetricFamilySamples family,
    int startTimeUnixNano,
    int timeUnixNano,
  ) {
    final metric = <String, dynamic>{
      'name': family.name,
      'description': family.help,
    };

    switch (family.type) {
      case MetricType.counter:
        metric['sum'] = {
          'dataPoints': family.samples
              .where((s) => s.value.isFinite)
              .map((s) => _numberDataPoint(s, startTimeUnixNano, timeUnixNano))
              .toList(),
          'aggregationTemporality': _aggregationTemporalityCumulative,
          'isMonotonic': true,
        };
      case MetricType.gauge:
      case MetricType.summary:
      case MetricType.untyped:
        // Summaries and untyped families have no faithful OTLP equivalent in
        // this exporter; their samples are exported as gauge points.
        metric['gauge'] = {
          'dataPoints': family.samples
              .where((s) => s.value.isFinite)
              .map((s) => _numberDataPoint(s, startTimeUnixNano, timeUnixNano))
              .toList(),
        };
      case MetricType.histogram:
        metric['histogram'] = _histogramData(
          family,
          startTimeUnixNano,
          timeUnixNano,
        );
    }

    return metric;
  }

  Map<String, dynamic> _numberDataPoint(
    Sample sample,
    int startTimeUnixNano,
    int timeUnixNano,
  ) {
    return {
      'attributes': _attributes(sample.labelNames, sample.labelValues),
      'startTimeUnixNano': startTimeUnixNano.toString(),
      'timeUnixNano': timeUnixNano.toString(),
      'asDouble': sample.value,
    };
  }

  /// Converts a Prometheus histogram family into an OTLP `histogram` metric
  /// body by regrouping `_bucket`/`_count`/`_sum` samples per label set and
  /// de-cumulating the bucket counts.
  Map<String, dynamic> _histogramData(
    MetricFamilySamples family,
    int startTimeUnixNano,
    int timeUnixNano,
  ) {
    final groups = <String, _HistogramAccumulator>{};

    for (final sample in family.samples) {
      final isBucket = sample.name.endsWith('_bucket');
      final leIndex = isBucket ? sample.labelNames.indexOf('le') : -1;

      final labelNames = <String>[];
      final labelValues = <String>[];
      for (var i = 0; i < sample.labelValues.length; i++) {
        if (i == leIndex) continue;
        labelNames.add(sample.labelNames[i]);
        labelValues.add(sample.labelValues[i]);
      }

      final acc = groups.putIfAbsent(
        labelValues.join(' '),
        () => _HistogramAccumulator(labelNames, labelValues),
      );

      if (isBucket) {
        acc.buckets.add(
          _BucketBound(
            _parseLeLabel(sample.labelValues[leIndex]),
            sample.value,
          ),
        );
      } else if (sample.name.endsWith('_count')) {
        acc.count = sample.value;
      } else if (sample.name.endsWith('_sum')) {
        acc.sum = sample.value;
      }
    }

    final dataPoints = <Map<String, dynamic>>[];
    for (final acc in groups.values) {
      acc.buckets.sort((a, b) => a.bound.compareTo(b.bound));

      final bucketCounts = <String>[];
      final explicitBounds = <double>[];
      var previousCumulative = 0.0;
      for (final bucket in acc.buckets) {
        bucketCounts.add(
          (bucket.cumulativeCount - previousCumulative).round().toString(),
        );
        previousCumulative = bucket.cumulativeCount;
        if (bucket.bound.isFinite) {
          explicitBounds.add(bucket.bound);
        }
      }

      dataPoints.add({
        'attributes': _attributes(acc.labelNames, acc.labelValues),
        'startTimeUnixNano': startTimeUnixNano.toString(),
        'timeUnixNano': timeUnixNano.toString(),
        'count': acc.count.round().toString(),
        'sum': acc.sum,
        'bucketCounts': bucketCounts,
        'explicitBounds': explicitBounds,
      });
    }

    return {
      'dataPoints': dataPoints,
      'aggregationTemporality': _aggregationTemporalityCumulative,
    };
  }

  static double _parseLeLabel(String value) {
    if (value == '+Inf') return double.infinity;
    if (value == '-Inf') return double.negativeInfinity;
    return double.parse(value);
  }

  static List<Map<String, dynamic>> _attributes(
    List<String> labelNames,
    List<String> labelValues,
  ) {
    return [
      for (var i = 0; i < labelNames.length && i < labelValues.length; i++)
        _attribute(labelNames[i], labelValues[i]),
    ];
  }

  static Map<String, dynamic> _attribute(String key, String value) => {
    'key': key,
    'value': {'stringValue': value},
  };
}

/// A single Prometheus histogram bucket: an upper [bound] (`le` label) and
/// its cumulative [cumulativeCount].
class _BucketBound {
  _BucketBound(this.bound, this.cumulativeCount);

  final double bound;
  final double cumulativeCount;
}

/// Accumulates the samples of one histogram time series (one label set).
class _HistogramAccumulator {
  _HistogramAccumulator(this.labelNames, this.labelValues);

  final List<String> labelNames;
  final List<String> labelValues;
  final List<_BucketBound> buckets = [];
  double count = 0;
  double sum = 0;
}
