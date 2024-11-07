class NetworkMetrics {
  final Map<LibP2PPeerId, PeerMetrics> peerMetrics = {};
  final Map<String, ProtocolMetrics> protocolMetrics = {};

  void recordMessageSent(LibP2PPeerId peer, String protocol, int bytes) {
    peerMetrics[peer]?.messagesSent++;
    peerMetrics[peer]?.bytesSent += bytes;
    protocolMetrics[protocol]?.messagesSent++;
  }
}

class PeerMetrics {
  int messagesSent = 0;
  int messagesReceived = 0;
  int bytesSent = 0;
  int bytesReceived = 0;
  Duration averageLatency = Duration.zero;
}
