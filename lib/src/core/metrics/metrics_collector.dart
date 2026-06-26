// src/core/metrics/metrics_collector.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/metrics/network_metrics.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:prometheus_client/format.dart' as format;
import 'package:prometheus_client/prometheus_client.dart';

/// Collects and manages metrics about IPFS node operations.
///
/// MetricsCollector gathers telemetry data including:
/// - P2P message and byte counters per protocol
/// - Latency histograms per protocol
/// - Peer connection and routing table gauges
/// - Blockstore size gauges
/// - Gateway and RPC request counters and duration histograms
/// - DHT provide/reprovide counters
/// - Security event counters
///
/// Collection is configurable via [IPFSConfig.metrics] and runs
/// periodically when enabled. Metrics are exposed in Prometheus text
/// format via [getPrometheusMetrics].
class MetricsCollector implements ILifecycle {
  /// Creates a new metrics collector with the given [_config].
  ///
  /// Optional [blockStore] and [routingTableProvider] are used by the
  /// periodic background collection started in [start].
  MetricsCollector(
    this._config, {
    BlockStore? blockStore,
    int Function()? routingTableProvider,
  }) : _blockStore = blockStore,
       _routingTableProvider = routingTableProvider {
    _logger = Logger(
      'MetricsCollector',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _initializeMetrics();
    _logger.debug('MetricsCollector instance created');
  }

  final IPFSConfig _config;
  late final Logger _logger;

  final _registry = CollectorRegistry();
  final StreamController<Map<String, dynamic>> _metricsStreamController =
      StreamController.broadcast();

  BlockStore? _blockStore;
  int Function()? _routingTableProvider;
  Timer? _collectionTimer;

  final _networkMetrics = NetworkMetrics();

  // Legacy protocol accumulators used by the legacy getter methods.
  final Map<String, int> _protocolMessagesSent = {};
  final Map<String, int> _protocolMessagesReceived = {};
  final Map<String, int> _protocolBytesSent = {};
  final Map<String, int> _protocolBytesReceived = {};
  final Map<String, int> _protocolLatencySumMicros = {};
  final Map<String, int> _protocolLatencyCount = {};

  // Count of peer-average-latency reports received via updateConnectionMetrics.
  final Map<String, int> _latencyReportCount = {};

  // --------------------------------------------------------------------------
  // Prometheus metric families
  // --------------------------------------------------------------------------
  late Counter _messagesSent;
  late Counter _messagesReceived;
  late Counter _bytesSent;
  late Counter _bytesReceived;
  late Histogram _latency;
  late Gauge _connectedPeers;
  late Gauge _routingTableSize;
  late Gauge _blockstoreBlocks;
  late Gauge _blockstoreBytes;
  late Counter _gatewayRequests;
  late Histogram _gatewayDuration;
  late Counter _rpcRequests;
  late Histogram _rpcDuration;
  late Counter _dhtProvides;
  late Counter _dhtReprovideRuns;
  late Histogram _dhtReprovideDuration;
  late Counter _securityEvents;

  void _initializeMetrics() {
    _messagesSent = Counter(
      name: 'ipfs_messages_sent_total',
      help: 'Total P2P messages sent.',
      labelNames: ['protocol'],
    )..register(_registry);

    _messagesReceived = Counter(
      name: 'ipfs_messages_received_total',
      help: 'Total P2P messages received.',
      labelNames: ['protocol'],
    )..register(_registry);

    _bytesSent = Counter(
      name: 'ipfs_bytes_sent_total',
      help: 'Total bytes sent.',
      labelNames: ['protocol'],
    )..register(_registry);

    _bytesReceived = Counter(
      name: 'ipfs_bytes_received_total',
      help: 'Total bytes received.',
      labelNames: ['protocol'],
    )..register(_registry);

    _latency = Histogram(
      name: 'ipfs_latency_seconds',
      help: 'Round-trip latency distribution.',
      labelNames: ['protocol'],
    )..register(_registry);

    _connectedPeers = Gauge(
      name: 'ipfs_connected_peers',
      help: 'Number of currently connected peers.',
    )..register(_registry);

    _routingTableSize = Gauge(
      name: 'ipfs_routing_table_size',
      help: 'Number of peers in the Kademlia routing table.',
    )..register(_registry);

    _blockstoreBlocks = Gauge(
      name: 'ipfs_blockstore_blocks',
      help: 'Number of blocks in the local blockstore.',
    )..register(_registry);

    _blockstoreBytes = Gauge(
      name: 'ipfs_blockstore_bytes',
      help: 'Total bytes stored in the local blockstore.',
    )..register(_registry);

    _gatewayRequests = Counter(
      name: 'ipfs_gateway_requests_total',
      help: 'Total HTTP gateway requests.',
      labelNames: ['namespace', 'method', 'status'],
    )..register(_registry);

    _gatewayDuration = Histogram(
      name: 'ipfs_gateway_request_duration_seconds',
      help: 'Gateway request latency.',
      labelNames: ['namespace', 'method'],
    )..register(_registry);

    _rpcRequests = Counter(
      name: 'ipfs_rpc_requests_total',
      help: 'Total RPC API requests.',
      labelNames: ['method', 'endpoint', 'status'],
    )..register(_registry);

    _rpcDuration = Histogram(
      name: 'ipfs_rpc_request_duration_seconds',
      help: 'RPC request latency.',
      labelNames: ['endpoint'],
    )..register(_registry);

    _dhtProvides = Counter(
      name: 'ipfs_dht_provides_total',
      help: 'Total provider announcements attempted.',
      labelNames: ['status'],
    )..register(_registry);

    _dhtReprovideRuns = Counter(
      name: 'ipfs_dht_reprovide_runs_total',
      help: 'Total reprovide runs.',
      labelNames: ['strategy', 'status'],
    )..register(_registry);

    _dhtReprovideDuration = Histogram(
      name: 'ipfs_dht_reprovide_duration_seconds',
      help: 'Reprovide run duration.',
      labelNames: ['strategy'],
    )..register(_registry);

    _securityEvents = Counter(
      name: 'ipfs_security_events_total',
      help: 'Security events.',
      labelNames: ['type'],
    )..register(_registry);
  }

  /// Returns a stream of metrics data.
  Stream<Map<String, dynamic>> get metricsStream =>
      _metricsStreamController.stream;

  /// Returns the metrics configuration used by this collector.
  MetricsConfig get metricsConfig => _config.metrics;

  @override
  Future<void> start() async {
    _logger.debug('Starting MetricsCollector...');
    if (!_config.metrics.enabled) {
      return;
    }

    // Collect immediately and then periodically.
    unawaited(_collect());
    _collectionTimer = Timer.periodic(
      Duration(seconds: _config.metrics.collectionIntervalSeconds),
      (_) => _collect(),
    );
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping MetricsCollector...');
    _collectionTimer?.cancel();
    _collectionTimer = null;
    await _metricsStreamController.close();
  }

  /// Registers a [BlockStore] to be queried by the periodic collector.
  void registerBlockStore(BlockStore blockStore) {
    _blockStore = blockStore;
  }

  /// Registers a callback that returns the current routing table size.
  void registerRoutingTableProvider(int Function() provider) {
    _routingTableProvider = provider;
  }

  Future<void> _collect() async {
    if (!_config.metrics.enabled) return;

    try {
      if (_blockStore != null && _config.metrics.collectStorageMetrics) {
        final status = await _blockStore!.getStatus();
        final blocks = status['total_blocks'] as int? ?? 0;
        final bytes = status['total_size'] as int? ?? 0;
        recordBlockstoreStats(blocks, bytes);
      }

      if (_routingTableProvider != null &&
          _config.metrics.collectNetworkMetrics) {
        recordRoutingTableSize(_routingTableProvider!());
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to collect periodic metrics', e, stackTrace);
    }
  }

  // --------------------------------------------------------------------------
  // Recording methods
  // --------------------------------------------------------------------------

  /// Records a P2P message sent via [protocol] with [bytes] payload.
  void recordMessageSent(String protocol, int bytes) {
    if (!_config.metrics.enabled) return;

    _messagesSent.labels([protocol]).inc();
    _bytesSent.labels([protocol]).inc(bytes.toDouble());
    _protocolMessagesSent[protocol] =
        (_protocolMessagesSent[protocol] ?? 0) + 1;
    _protocolBytesSent[protocol] = (_protocolBytesSent[protocol] ?? 0) + bytes;

    _emit('recordMessageSent', {'protocol': protocol, 'bytes': bytes});
  }

  /// Records a P2P message received via [protocol] with [bytes] payload.
  void recordMessageReceived(String protocol, int bytes) {
    if (!_config.metrics.enabled) return;

    _messagesReceived.labels([protocol]).inc();
    _bytesReceived.labels([protocol]).inc(bytes.toDouble());
    _protocolMessagesReceived[protocol] =
        (_protocolMessagesReceived[protocol] ?? 0) + 1;
    _protocolBytesReceived[protocol] =
        (_protocolBytesReceived[protocol] ?? 0) + bytes;

    _emit('recordMessageReceived', {'protocol': protocol, 'bytes': bytes});
  }

  /// Records a round-trip latency observation for [protocol].
  void recordLatency(String protocol, Duration latency) {
    if (!_config.metrics.enabled) return;

    final seconds = latency.inMicroseconds / 1e6;
    _latency.labels([protocol]).observe(seconds);

    _protocolLatencySumMicros[protocol] =
        (_protocolLatencySumMicros[protocol] ?? 0) + latency.inMicroseconds;
    _protocolLatencyCount[protocol] =
        (_protocolLatencyCount[protocol] ?? 0) + 1;

    _emit('recordLatency', {
      'protocol': protocol,
      'latency_microseconds': latency.inMicroseconds,
    });
  }

  /// Records that a peer has connected.
  void recordPeerConnected() {
    if (!_config.metrics.enabled) return;
    _connectedPeers.inc();
    _emit('recordPeerConnected', {});
  }

  /// Records that a peer has disconnected.
  void recordPeerDisconnected() {
    if (!_config.metrics.enabled) return;
    _connectedPeers.dec();
    _emit('recordPeerDisconnected', {});
  }

  /// Records the current routing table [size].
  void recordRoutingTableSize(int size) {
    if (!_config.metrics.enabled) return;
    _routingTableSize.value = size.toDouble();
  }

  /// Records blockstore statistics: number of [blocks] and total [bytes].
  void recordBlockstoreStats(int blocks, int bytes) {
    if (!_config.metrics.enabled) return;
    _blockstoreBlocks.value = blocks.toDouble();
    _blockstoreBytes.value = bytes.toDouble();
  }

  /// Records an HTTP gateway request.
  void recordGatewayRequest(
    String namespace,
    String method,
    int status,
    Duration duration,
  ) {
    if (!_config.metrics.enabled) return;

    final statusLabel = status.toString();
    _gatewayRequests.labels([namespace, method, statusLabel]).inc();
    _gatewayDuration
        .labels([namespace, method])
        .observe(duration.inMicroseconds / 1e6);

    _emit('recordGatewayRequest', {
      'namespace': namespace,
      'method': method,
      'status': status,
      'duration_microseconds': duration.inMicroseconds,
    });
  }

  /// Records an RPC API request.
  void recordRpcRequest(
    String endpoint,
    String method,
    int status,
    Duration duration,
  ) {
    if (!_config.metrics.enabled) return;

    final statusLabel = status.toString();
    _rpcRequests.labels([method, endpoint, statusLabel]).inc();
    _rpcDuration.labels([endpoint]).observe(duration.inMicroseconds / 1e6);

    _emit('recordRpcRequest', {
      'endpoint': endpoint,
      'method': method,
      'status': status,
      'duration_microseconds': duration.inMicroseconds,
    });
  }

  /// Records a DHT provider announcement attempt.
  ///
  /// [success] indicates whether the announcement succeeded.
  void recordDhtProvide(bool success) {
    if (!_config.metrics.enabled) return;
    _dhtProvides.labels([success ? 'success' : 'failure']).inc();
    _emit('recordDhtProvide', {'success': success});
  }

  /// Records a reprovide run.
  ///
  /// [strategy] is the reprovide strategy name, [success] indicates whether the
  /// run succeeded, and [duration] is the time it took.
  void recordReprovide(String strategy, bool success, Duration duration) {
    if (!_config.metrics.enabled) return;

    _dhtReprovideRuns.labels([strategy, success ? 'success' : 'failure']).inc();
    _dhtReprovideDuration
        .labels([strategy])
        .observe(duration.inMicroseconds / 1e6);

    _emit('recordReprovide', {
      'strategy': strategy,
      'success': success,
      'duration_microseconds': duration.inMicroseconds,
    });
  }

  /// Records a security event of the given [type].
  ///
  /// Common types include `rate_limit`, `blocked_cid`, and `auth_failure`.
  void recordSecurityEvent(String type) {
    if (!_config.metrics.enabled) return;
    _securityEvents.labels([type]).inc();
    _emit('recordSecurityEvent', {'type': type});
  }

  // --------------------------------------------------------------------------
  // Legacy/secondary API
  // --------------------------------------------------------------------------

  /// Records metrics for a specific protocol.
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {
    _logger.debug('Recording metrics for $protocol: $metrics');
    _metricsStreamController.add({'protocol': protocol, ...metrics});
  }

  /// Records an error in the metrics system.
  void recordError(String error, Object e, StackTrace st) {
    _logger.error(error, e, st);
  }

  /// Returns total messages sent for a protocol or peer identifier.
  int getMessagesSent(String key) {
    return _protocolMessagesSent[key] ??
        _networkMetrics.peerMetrics[key]?.messagesSent ??
        _networkMetrics.protocolMetrics[key]?.messagesSent ??
        0;
  }

  /// Returns total messages received for a protocol or peer identifier.
  int getMessagesReceived(String key) {
    return _protocolMessagesReceived[key] ??
        _networkMetrics.peerMetrics[key]?.messagesReceived ??
        _networkMetrics.protocolMetrics[key]?.messagesReceived ??
        0;
  }

  /// Returns total bytes sent for a protocol or peer identifier.
  int getBytesSent(String key) {
    return _protocolBytesSent[key] ??
        _networkMetrics.peerMetrics[key]?.bytesSent ??
        _networkMetrics.protocolMetrics[key]?.bytesSent ??
        0;
  }

  /// Returns total bytes received for a protocol or peer identifier.
  int getBytesReceived(String key) {
    return _protocolBytesReceived[key] ??
        _networkMetrics.peerMetrics[key]?.bytesReceived ??
        _networkMetrics.protocolMetrics[key]?.bytesReceived ??
        0;
  }

  /// Returns average latency in milliseconds for a protocol or peer identifier.
  double getAverageLatency(String key) {
    final count = _protocolLatencyCount[key] ?? 0;
    if (count > 0) {
      return (_protocolLatencySumMicros[key] ?? 0) / count / 1000.0;
    }

    final peer = _networkMetrics.peerMetrics[key];
    if (peer != null) {
      return peer.averageLatency.inMicroseconds / 1000.0;
    }
    return 0.0;
  }

  /// Updates connection metrics for a peer.
  void updateConnectionMetrics(String peerId, Map<String, dynamic> metrics) {
    if (!_config.metrics.enabled) return;

    final peer = _networkMetrics.peerMetrics.putIfAbsent(
      peerId,
      PeerMetrics.new,
    );

    final messagesSent = _intValue(metrics['messagesSent']);
    if (messagesSent != null) {
      peer.messagesSent += messagesSent;
    }
    final messagesReceived = _intValue(metrics['messagesReceived']);
    if (messagesReceived != null) {
      peer.messagesReceived += messagesReceived;
    }
    final bytesSent = _intValue(metrics['bytesSent']);
    if (bytesSent != null) {
      peer.bytesSent += bytesSent;
    }
    final bytesReceived = _intValue(metrics['bytesReceived']);
    if (bytesReceived != null) {
      peer.bytesReceived += bytesReceived;
    }
    final latencyMs = _intValue(metrics['averageLatencyMs']);
    if (latencyMs != null) {
      final previousCount = _latencyReportCount[peerId] ?? 0;
      final previousMicros = peer.averageLatency.inMicroseconds;
      final newCount = previousCount + 1;
      final newMicros =
          ((previousMicros * previousCount + latencyMs * 1000) / newCount)
              .round();
      peer.averageLatency = Duration(microseconds: newMicros);
      _latencyReportCount[peerId] = newCount;
    }
  }

  /// Returns the current status of the metrics collector.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'status': 'active',
      'enabled': _config.metrics.enabled,
      'prometheus_export_enabled': _config.metrics.enablePrometheusExport,
    };
  }

  /// Returns the metrics in Prometheus text format (version 0.0.4).
  ///
  /// Returns an empty string when metrics collection is disabled.
  Future<String> getPrometheusMetrics() async {
    if (!_config.metrics.enabled) return '';

    final buffer = StringBuffer();
    final samples = await _registry.collectMetricFamilySamples();
    format.write004(buffer, samples);
    return buffer.toString();
  }

  /// Resets all metrics. Intended for testing only.
  void reset() {
    // Unregister the old collectors and recreate them so that all values are
    // reset to zero while keeping the same metric names and labels.
    _registry.unregister(_messagesSent);
    _registry.unregister(_messagesReceived);
    _registry.unregister(_bytesSent);
    _registry.unregister(_bytesReceived);
    _registry.unregister(_latency);
    _registry.unregister(_connectedPeers);
    _registry.unregister(_routingTableSize);
    _registry.unregister(_blockstoreBlocks);
    _registry.unregister(_blockstoreBytes);
    _registry.unregister(_gatewayRequests);
    _registry.unregister(_gatewayDuration);
    _registry.unregister(_rpcRequests);
    _registry.unregister(_rpcDuration);
    _registry.unregister(_dhtProvides);
    _registry.unregister(_dhtReprovideRuns);
    _registry.unregister(_dhtReprovideDuration);
    _registry.unregister(_securityEvents);

    _initializeMetrics();

    _protocolMessagesSent.clear();
    _protocolMessagesReceived.clear();
    _protocolBytesSent.clear();
    _protocolBytesReceived.clear();
    _protocolLatencySumMicros.clear();
    _protocolLatencyCount.clear();
    _latencyReportCount.clear();
    _networkMetrics.peerMetrics.clear();
    _networkMetrics.protocolMetrics.clear();
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  void _emit(String method, Map<String, dynamic> data) {
    if (!_metricsStreamController.isClosed) {
      _metricsStreamController.add({'method': method, ...data});
    }
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
