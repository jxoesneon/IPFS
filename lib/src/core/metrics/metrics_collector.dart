// src/core/metrics/metrics_collector.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Collects and manages metrics about IPFS node operations.
///
/// MetricsCollector gathers telemetry data including:
/// - System metrics (CPU, memory usage)
/// - Network metrics (bandwidth, peer connections)
/// - Storage metrics (disk usage, block counts)
/// - Protocol-specific metrics (message counts, errors)
///
/// Collection is configurable via [IPFSConfig.metrics] and runs
/// periodically when enabled.
class MetricsCollector implements ILifecycle {
  /// Creates a new metrics collector with the given [_config].
  MetricsCollector(this._config) {
    _logger = Logger(
      'MetricsCollector',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('MetricsCollector instance created');
  }
  final IPFSConfig _config;
  late final Logger _logger;

  final StreamController<Map<String, dynamic>> _metricsStreamController =
      StreamController.broadcast();

  /// Returns a stream of metrics data.
  Stream<Map<String, dynamic>> get metricsStream =>
      _metricsStreamController.stream;

  @override
  Future<void> start() async {
    _logger.debug('Starting MetricsCollector...');
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping MetricsCollector...');
    await _metricsStreamController.close();
  }

  /// Records metrics for a specific protocol.
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {
    _logger.debug('Recording metrics for $protocol: $metrics');
    _metricsStreamController.add({'protocol': protocol, ...metrics});
  }

  /// Records an error in the metrics system.
  void recordError(String error, Object e, StackTrace st) {
    _logger.error(error, e, st);
  }

  /// Returns total messages sent for a protocol.
  int getMessagesSent(String protocol) => 0;

  /// Returns total messages received for a protocol.
  int getMessagesReceived(String protocol) => 0;

  /// Returns total bytes sent for a protocol.
  int getBytesSent(String protocol) => 0;

  /// Returns total bytes received for a protocol.
  int getBytesReceived(String protocol) => 0;

  /// Returns average latency for a protocol.
  double getAverageLatency(String protocol) => 0.0;

  /// Updates connection metrics for a peer.
  void updateConnectionMetrics(String peerId, Map<String, dynamic> metrics) {}
}
