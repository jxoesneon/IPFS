import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';
import 'package:dart_ipfs/src/proto/generated/metrics.pb.dart';

/// Collects and manages metrics about peer connections and network activity
class MetricsCollector {
  final Map<String, _PeerStats> _peerStats = {};
  final Map<String, _ProtocolStats> _protocolStats = {};

  // Get metrics for a specific peer
  fixnum.Int64 getMessagesSent(String peerId) {
    return fixnum.Int64(_peerStats[peerId]?.messagesSent ?? 0);
  }

  fixnum.Int64 getMessagesReceived(String peerId) {
    return fixnum.Int64(_peerStats[peerId]?.messagesReceived ?? 0);
  }

  fixnum.Int64 getBytesSent(String peerId) {
    return fixnum.Int64(_peerStats[peerId]?.bytesSent ?? 0);
  }

  fixnum.Int64 getBytesReceived(String peerId) {
    return fixnum.Int64(_peerStats[peerId]?.bytesReceived ?? 0);
  }

  Duration getAverageLatency(String peerId) {
    return Duration(milliseconds: _peerStats[peerId]?.averageLatencyMs ?? 0);
  }

  // Record new metrics
  void recordMessageSent(String peerId, String protocol, int bytes) {
    _peerStats.putIfAbsent(peerId, () => _PeerStats());
    _protocolStats.putIfAbsent(protocol, () => _ProtocolStats());

    _peerStats[peerId]!.messagesSent++;
    _peerStats[peerId]!.bytesSent += bytes;
    _protocolStats[protocol]!.messagesSent++;
  }

  void recordMessageReceived(String peerId, String protocol, int bytes) {
    _peerStats.putIfAbsent(peerId, () => _PeerStats());
    _protocolStats.putIfAbsent(protocol, () => _ProtocolStats());

    _peerStats[peerId]!.messagesReceived++;
    _peerStats[peerId]!.bytesReceived += bytes;
    _protocolStats[protocol]!.messagesReceived++;
  }

  void recordLatency(String peerId, Duration latency) {
    _peerStats.putIfAbsent(peerId, () => _PeerStats());
    _peerStats[peerId]!.updateLatency(latency.inMilliseconds);
  }

  void recordError(String peerId, String protocol, String errorType) {
    _peerStats.putIfAbsent(peerId, () => _PeerStats());
    _protocolStats.putIfAbsent(protocol, () => _ProtocolStats());

    _peerStats[peerId]!.errorCount++;
    _protocolStats[protocol]!.recordError(errorType);
  }

  // Update connection metrics
  Future<void> updateConnectionMetrics(ConnectionMetrics metrics) async {
    final stats = _peerStats.putIfAbsent(metrics.peerId, () => _PeerStats());

    // Update the stats from the metrics
    stats.messagesSent = metrics.messagesSent.toInt();
    stats.messagesReceived = metrics.messagesReceived.toInt();
    stats.bytesSent = metrics.bytesSent.toInt();
    stats.bytesReceived = metrics.bytesReceived.toInt();
    stats.averageLatencyMs = metrics.averageLatencyMs;
  }

  // Get aggregated network metrics
  NetworkMetrics getNetworkMetrics() {
    final metrics = NetworkMetrics()
      ..timestamp = DateTime.now().millisecondsSinceEpoch;

    // Convert peer stats to protobuf format
    _peerStats.forEach((peerId, stats) {
      metrics.peerMetrics[peerId] = PeerMetrics()
        ..messagesSent = fixnum.Int64(stats.messagesSent)
        ..messagesReceived = fixnum.Int64(stats.messagesReceived)
        ..bytesSent = fixnum.Int64(stats.bytesSent)
        ..bytesReceived = fixnum.Int64(stats.bytesReceived)
        ..averageLatencyMs = stats.averageLatencyMs
        ..errorCount = stats.errorCount;
    });

    // Convert protocol stats to protobuf format
    _protocolStats.forEach((protocol, stats) {
      metrics.protocolMetrics[protocol] = ProtocolMetrics()
        ..messagesSent = fixnum.Int64(stats.messagesSent)
        ..messagesReceived = fixnum.Int64(stats.messagesReceived)
        ..activeConnections = stats.activeConnections;

      stats.errorCounts.forEach((error, count) {
        metrics.protocolMetrics[protocol]!.errorCounts[error] =
            fixnum.Int64(count);
      });
    });

    return metrics;
  }
}

// Internal stats tracking classes
class _PeerStats {
  int messagesSent = 0;
  int messagesReceived = 0;
  int bytesSent = 0;
  int bytesReceived = 0;
  int averageLatencyMs = 0;
  int errorCount = 0;

  void updateLatency(int latencyMs) {
    // Exponential moving average with alpha = 0.1
    averageLatencyMs = ((latencyMs * 0.1) + (averageLatencyMs * 0.9)).round();
  }
}

class _ProtocolStats {
  int messagesSent = 0;
  int messagesReceived = 0;
  int activeConnections = 0;
  final Map<String, int> errorCounts = {};

  void recordError(String errorType) {
    errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
  }
}
