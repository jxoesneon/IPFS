import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';

import '../core/metrics/metrics_collector.dart';
import '../core/types/p2p_types.dart';
import '../proto/generated/connection.pb.dart';

/// Manages peer connection lifecycle and metrics.
class ConnectionManager {
  /// Creates a connection manager with the given [_metrics] collector.
  ConnectionManager(this._metrics);
  final Map<String, ConnectionState> _connections = {};
  final MetricsCollector _metrics;

  /// Handles a new peer connection.
  Future<void> handleNewConnection(LibP2PPeerId peerId) async {
    final now = DateTime.now();
    final timestamp = Timestamp()
      ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
      ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

    final state = ConnectionState()
      ..peerId = peerId.toString()
      ..status = ConnectionState_Status.CONNECTED
      ..connectedAt = timestamp
      ..metadata.addAll({
        'client_version': 'ipfs-dart/1.0.0',
        'protocols': ['dht', 'bitswap'].join(','),
      });

    _connections[peerId.toString()] = state;
    await _updateMetrics(peerId.toString());
  }

  Future<void> _updateMetrics(String peerId) async {
    final metrics = ConnectionMetrics()
      ..peerId = peerId
      ..messagesSent = Int64(_metrics.getMessagesSent(peerId))
      ..messagesReceived = Int64(_metrics.getMessagesReceived(peerId))
      ..bytesSent = Int64(_metrics.getBytesSent(peerId))
      ..bytesReceived = Int64(_metrics.getBytesReceived(peerId))
      ..averageLatencyMs = _metrics.getAverageLatency(peerId).toInt();

    _metrics.updateConnectionMetrics(
      peerId,
      metrics.toProto3Json() as Map<String, dynamic>,
    );
  }
}
