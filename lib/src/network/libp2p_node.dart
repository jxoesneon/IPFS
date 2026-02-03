import 'package:dart_ipfs/src/core/protocol_handlers/protocol_handler.dart';

/// libp2p node abstraction for protocol, transport, and security configuration.
///
/// Manages registered protocols and provides methods to enable
/// transports (TCP, QUIC), security (Noise, TLS), and muxers (yamux, mplex).
class Libp2pNode {
  /// Creates a node with the given [protocols].
  Libp2pNode({required this.protocols});

  /// Registered protocol handlers by protocol ID.
  final Map<String, ProtocolHandler> protocols;

  /// Enables a transport protocol (e.g., TCP, QUIC, WebSocket).
  Future<void> enableTransport(String transport) async {
    return Future.value();
  }

  /// Enables a security protocol (e.g., Noise, TLS).
  Future<void> enableSecurity(String security) async {
    return Future.value();
  }

  /// Enables a stream multiplexer (e.g., yamux, mplex).
  Future<void> enableMuxer(String muxer) async {
    return Future.value();
  }
}
