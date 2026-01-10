// src/core/metrics/metrics_collector.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';
import 'package:dart_ipfs/src/proto/generated/metrics.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

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
///
/// Example:
/// ```dart
/// final collector = MetricsCollector(config);
/// await collector.start();
///
/// // Record protocol activity
/// collector.recordProtocolMetrics('bitswap', {
///   'messages_sent': 10,
///   'messages_received': 5,
/// });
///
/// // Get status
/// final status = await collector.getStatus();
/// ```
///
/// See also:
/// - [MetricsConfig] for configuration options
/// - [ConnectionMetrics] for per-peer statistics
class MetricsCollector {
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
  Timer? _collectionTimer;
  final Map<String, dynamic> _metrics = <String, dynamic>{};
  final Map<String, Map<String, int>> _messageMetrics =
      <String, Map<String, int>>{};
  final Map<String, Map<String, int>> _byteMetrics =
      <String, Map<String, int>>{};
  final Map<String, List<Duration>> _latencyMetrics =
      <String, List<Duration>>{};
  final StreamController<Map<String, dynamic>> _metricsStreamController =
      StreamController.broadcast();

  /// Stream of collected metrics.
  Stream<Map<String, dynamic>> get metricsStream =>
      _metricsStreamController.stream;

  /// Starts metrics collection.
  Future<void> start() async {
    _logger.debug('Starting metrics collection...');

    try {
      if (_config.metrics.enabled) {
        _startCollection();
        _logger.info('Metrics collection started');
      } else {
        _logger.info('Metrics collection disabled in config');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start metrics collection', e, stackTrace);
      rethrow;
    }
  }

  void _startCollection() {
    _collectionTimer?.cancel();
    _collectionTimer = Timer.periodic(
      Duration(seconds: _config.metrics.collectionIntervalSeconds),
      (_) => _collectMetrics(),
    );
  }

  Future<void> _collectMetrics() async {
    try {
      if (_config.metrics.collectSystemMetrics) {
        await _collectSystemMetrics();
      }
      if (_config.metrics.collectNetworkMetrics) {
        await _collectNetworkMetrics();
      }
      if (_config.metrics.collectStorageMetrics) {
        await _collectStorageMetrics();
      }
      if (_config.metrics.collectStorageMetrics) {
        await _collectStorageMetrics();
      }

      // Calculate totals
      int totalSent = 0;
      int totalReceived = 0;
      for (final peerMetrics in _byteMetrics.values) {
        totalSent += peerMetrics['sent'] ?? 0;
        totalReceived += peerMetrics['received'] ?? 0;
      }

      _metricsStreamController.add({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'totalSent': totalSent,
        'totalReceived': totalReceived,
        'peers': _byteMetrics.length,
      });
    } catch (e, stackTrace) {
      _logger.error('Error collecting metrics', e, stackTrace);
    }
  }

  /// Stops metrics collection.
  Future<void> stop() async {
    _logger.debug('Stopping metrics collection');
    _collectionTimer?.cancel();
    _collectionTimer = null;
    await _metricsStreamController.close();
  }

  /// Returns the current metrics collector status.
  Future<Map<String, dynamic>> getStatus() async {
    return <String, dynamic>{
      'enabled': _config.metrics.enabled,
      'collection_interval': _config.metrics.collectionIntervalSeconds,
      'system_metrics_enabled': _config.metrics.collectSystemMetrics,
      'network_metrics_enabled': _config.metrics.collectNetworkMetrics,
      'storage_metrics_enabled': _config.metrics.collectStorageMetrics,
    };
  }

  // Collection methods for different metric types
  Future<void> _collectSystemMetrics() async {
    // Collect CPU, memory, etc.
  }

  Future<void> _collectNetworkMetrics() async {
    // Collect bandwidth, peers, etc.
  }

  Future<void> _collectStorageMetrics() async {
    // Collect disk usage, block counts, etc.
  }

  /// Records an error with the given category, source, and message
  void recordError(String category, String source, String message) {
    if (!_config.metrics.enabled) return;

    try {
      final protocolMetrics = _metrics['protocol_metrics'] ??=
          <String, ProtocolMetrics>{};
      final metrics = protocolMetrics[source] ?? ProtocolMetrics();

      // Update error counts map
      final errorKey = '${category}_${message.hashCode}';
      final currentCount = metrics.errorCounts[errorKey] ?? fixnum.Int64.ZERO;
      metrics.errorCounts[errorKey] = currentCount + fixnum.Int64.ONE;

      protocolMetrics[source] = metrics;
      _logger.verbose('Recorded error for $source: $message');
    } catch (e, stackTrace) {
      _logger.error('Failed to record error metric', e, stackTrace);
    }
  }

  /// Records protocol-specific metrics
  void recordProtocolMetrics(String protocol, Map<String, dynamic> data) {
    if (!_config.metrics.enabled) return;

    try {
      final protocolMetrics = _metrics['protocol_metrics'] ??=
          <String, ProtocolMetrics>{};
      final metrics = protocolMetrics[protocol] ?? ProtocolMetrics();

      // Update message counts if provided
      if (data['messages_sent'] != null) {
        final val = data['messages_sent'];
        final count = val is int ? val : int.tryParse(val.toString()) ?? 0;
        metrics.messagesSent += fixnum.Int64(count);
      }
      if (data['messages_received'] != null) {
        final val = data['messages_received'];
        final count = val is int ? val : int.tryParse(val.toString()) ?? 0;
        metrics.messagesReceived += fixnum.Int64(count);
      }

      // Update active connections if provided
      if (data['active_connections'] != null) {
        final val = data['active_connections'];
        metrics.activeConnections = val is int
            ? val
            : int.tryParse(val.toString()) ?? 0;
      }

      // Record error if this is an error event
      if (data['type'] != null) {
        final errorKey = '${data['type']}_${(data['message'] ?? '').hashCode}';
        final currentCount = metrics.errorCounts[errorKey] ?? fixnum.Int64.ZERO;
        metrics.errorCounts[errorKey] = currentCount + fixnum.Int64.ONE;
      }

      protocolMetrics[protocol] = metrics;
      _logger.verbose('Recorded protocol metrics for $protocol');
    } catch (e, stackTrace) {
      _logger.error('Failed to record protocol metrics', e, stackTrace);
    }
  }

  // Get number of messages sent by a peer
  /// Gets the number of messages sent to a peer.
  fixnum.Int64 getMessagesSent(String peerId) {
    return fixnum.Int64(_messageMetrics[peerId]?['sent'] ?? 0);
  }

  // Get number of messages received from a peer
  /// Gets the number of messages received from a peer.
  fixnum.Int64 getMessagesReceived(String peerId) {
    return fixnum.Int64(_messageMetrics[peerId]?['received'] ?? 0);
  }

  // Get number of bytes sent to a peer
  /// Gets the number of bytes sent to a peer.
  fixnum.Int64 getBytesSent(String peerId) {
    return fixnum.Int64(_byteMetrics[peerId]?['sent'] ?? 0);
  }

  // Get number of bytes received from a peer
  /// Gets the number of bytes received from a peer.
  fixnum.Int64 getBytesReceived(String peerId) {
    return fixnum.Int64(_byteMetrics[peerId]?['received'] ?? 0);
  }

  // Get average latency for a peer
  /// Gets the average latency for a peer.
  Duration getAverageLatency(String peerId) {
    final latencies = _latencyMetrics[peerId];
    if (latencies == null || latencies.isEmpty) {
      return Duration.zero;
    }
    final totalMs = latencies.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ latencies.length);
  }

  // Update connection metrics
  /// Updates connection metrics for a peer.
  Future<void> updateConnectionMetrics(ConnectionMetrics metrics) async {
    final peerId = metrics.peerId;

    // Initialize maps if they don't exist
    _messageMetrics[peerId] ??= <String, int>{};
    _byteMetrics[peerId] ??= <String, int>{};

    // Update message metrics
    _messageMetrics[peerId]?['sent'] = metrics.messagesSent.toInt();
    _messageMetrics[peerId]?['received'] = metrics.messagesReceived.toInt();

    // Update byte metrics
    _byteMetrics[peerId]?['sent'] = metrics.bytesSent.toInt();
    _byteMetrics[peerId]?['received'] = metrics.bytesReceived.toInt();

    // Update latency metrics
    _latencyMetrics[peerId] ??= [];
    _latencyMetrics[peerId]?.add(
      Duration(milliseconds: metrics.averageLatencyMs),
    );

    // Keep only last 100 latency measurements
    if (_latencyMetrics[peerId]!.length > 100) {
      _latencyMetrics[peerId]?.removeAt(0);
    }
  }
}
