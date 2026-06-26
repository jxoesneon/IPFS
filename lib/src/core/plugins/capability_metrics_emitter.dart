// lib/src/core/plugins/capability_metrics_emitter.dart
//
// Capability-gated adapter for the metrics collector. Plugins with the
// `metrics.emit` capability can emit counters/histograms without receiving
// a raw reference to the underlying [MetricsCollector].

import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';

import 'capability_exception.dart';
import 'capability_registry.dart';

/// Adapter that gates access to the metrics collector by the `metrics.emit`
/// capability.
class CapabilityMetricsEmitter {
  /// Creates a metrics emitter for [_pluginId] gated by [_grantedCapabilities].
  CapabilityMetricsEmitter(
    this._pluginId,
    this._metrics,
    this._registry,
    this._grantedCapabilities, {
    void Function(String pluginId)? onViolation,
  }) : _onViolation = onViolation;

  final String _pluginId;
  final MetricsCollector _metrics;
  final CapabilityRegistry _registry;
  final Set<String> _grantedCapabilities;
  final void Function(String pluginId)? _onViolation;

  static const String _capability = 'metrics.emit';

  void _require() {
    try {
      _registry.require(_pluginId, _capability, _grantedCapabilities);
    } on CapabilityException {
      _onViolation?.call(_pluginId);
      rethrow;
    }
  }

  /// Emits a named counter metric.
  ///
  /// Throws [CapabilityException] if the plugin was not granted
  /// `metrics.emit`. The plugin is disabled on violation.
  void emitCounter(String name, {int value = 1, Map<String, String>? labels}) {
    _require();
    _metrics.recordProtocolMetrics(
      'plugin',
      {
        'pluginId': _pluginId,
        'metricType': 'counter',
        'name': name,
        'value': value,
        // ignore: use_null_aware_elements
        if (labels != null) 'labels': labels,
      },
    );
  }

  /// Emits a named histogram metric.
  ///
  /// Throws [CapabilityException] if the plugin was not granted
  /// `metrics.emit`. The plugin is disabled on violation.
  void emitHistogram(
    String name,
    double value, {
    Map<String, String>? labels,
  }) {
    _require();
    _metrics.recordProtocolMetrics(
      'plugin',
      {
        'pluginId': _pluginId,
        'metricType': 'histogram',
        'name': name,
        'value': value,
        // ignore: use_null_aware_elements
        if (labels != null) 'labels': labels,
      },
    );
  }
}
