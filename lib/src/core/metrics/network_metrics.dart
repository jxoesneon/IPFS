import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/metrics.pb.dart';

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
    peerMetrics[peer]?.messagesSent++;
    peerMetrics[peer]?.bytesSent += bytes;
    protocolMetrics[protocol]?.messagesSent++;
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
