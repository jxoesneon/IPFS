class Libp2pNode {
  // Required protocols
  final Map<String, ProtocolHandler> protocols;

  // Transport requirements
  Future<void> enableTransport(String transport) {
    // Support TCP, QUIC, WebSocket, etc.
  }

  // Security requirements
  Future<void> enableSecurity(String security) {
    // Support Noise, TLS, etc.
  }

  // Multiplexing requirements
  Future<void> enableMuxer(String muxer) {
    // Support yamux, mplex
  }
}
