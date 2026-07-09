import '../types/p2p_types.dart';

/// Tracks network-level metrics for monitoring and analysis.
///
/// Collects per-peer and per-protocol statistics including message
/// counts, bandwidth usage, and latency measurements.
class NetworkMetrics {
  /// Metrics indexed by peer ID.
  final Map<LibP2PPeerId, PeerMetrics> peerMetrics = {};

  /// Metrics indexed by protocol ID.
  final Map<String, ProtocolMetrics> protocolMetrics = {};

  /// Records a message sent to [peer] via [protocol].
  void recordMessageSent(LibP2PPeerId peer, String protocol, int bytes) {
    peerMetrics.putIfAbsent(peer, () => PeerMetrics());
    protocolMetrics.putIfAbsent(protocol, () => ProtocolMetrics());
    peerMetrics[peer]!.messagesSent++;
    peerMetrics[peer]!.bytesSent += bytes;
    protocolMetrics[protocol]!.messagesSent++;
    protocolMetrics[protocol]!.bytesSent += bytes;
  }

  /// Records a message received from [peer] via [protocol].
  void recordMessageReceived(LibP2PPeerId peer, String protocol, int bytes) {
    peerMetrics.putIfAbsent(peer, () => PeerMetrics());
    protocolMetrics.putIfAbsent(protocol, () => ProtocolMetrics());
    peerMetrics[peer]!.messagesReceived++;
    peerMetrics[peer]!.bytesReceived += bytes;
    protocolMetrics[protocol]!.messagesReceived++;
    protocolMetrics[protocol]!.bytesReceived += bytes;
  }

  /// Records a round-trip latency observation for [peer].
  void recordLatency(LibP2PPeerId peer, Duration latency) {
    peerMetrics.putIfAbsent(peer, () => PeerMetrics());
    final metrics = peerMetrics[peer]!;
    final count = metrics.messagesSent + metrics.messagesReceived;
    if (count <= 1) {
      metrics.averageLatency = latency;
    } else {
      // Incremental moving average to avoid storing every sample.
      metrics.averageLatency = Duration(
        microseconds:
            ((metrics.averageLatency.inMicroseconds * (count - 1) +
                        latency.inMicroseconds) /
                    count)
                .round(),
      );
    }
  }
}

/// Per-peer metrics for bandwidth and message tracking.
class PeerMetrics {
  /// Total messages sent to this peer.
  int messagesSent = 0;

  /// Total messages received from this peer.
  int messagesReceived = 0;

  /// Total bytes sent to this peer.
  int bytesSent = 0;

  /// Total bytes received from this peer.
  int bytesReceived = 0;

  /// Average round-trip latency to this peer.
  Duration averageLatency = Duration.zero;
}

/// Per-protocol metrics for bandwidth and message tracking.
class ProtocolMetrics {
  /// Total messages sent via this protocol.
  int messagesSent = 0;

  /// Total messages received via this protocol.
  int messagesReceived = 0;

  /// Total bytes sent via this protocol.
  int bytesSent = 0;

  /// Total bytes received via this protocol.
  int bytesReceived = 0;
}
