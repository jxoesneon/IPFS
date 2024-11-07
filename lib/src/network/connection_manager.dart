import '../generated/connection.pb.dart';
import '../core/metrics/metrics_collector.dart';

class ConnectionManager {
  final Map<String, ConnectionState> _connections = {};
  final MetricsCollector _metrics;

  Future<void> handleNewConnection(LibP2PPeerId peerId) async {
    final state = ConnectionState()
      ..peerId = peerId.toString()
      ..status = ConnectionState_Status.CONNECTED
      ..connectedAt = Int64.now()
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
      ..messagesSent = _metrics.getMessagesSent(peerId)
      ..messagesReceived = _metrics.getMessagesReceived(peerId)
      ..bytesSent = _metrics.getBytesSent(peerId)
      ..bytesReceived = _metrics.getBytesReceived(peerId)
      ..averageLatencyMs = _metrics.getAverageLatency(peerId).inMilliseconds;

    await _metrics.updateConnectionMetrics(metrics);
  }
}
