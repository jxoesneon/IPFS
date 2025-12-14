import 'package:dart_ipfs/src/core/types/p2p_types.dart';

/// Base class for network-related errors.
///
/// Network errors include connection failures, protocol errors,
/// and peer communication issues. Each error includes a timestamp.
abstract class NetworkError implements Exception {
  /// The error message.
  final String message;

  /// When the error occurred.
  final DateTime timestamp;

  /// Creates a network error with the given [message].
  NetworkError(this.message) : timestamp = DateTime.now();
}

class PeerConnectionError extends NetworkError {
  final LibP2PPeerId peerId;

  PeerConnectionError(this.peerId, String message) : super(message);
}

class ProtocolError extends NetworkError {
  final String protocolId;

  ProtocolError(this.protocolId, String message) : super(message);
}
