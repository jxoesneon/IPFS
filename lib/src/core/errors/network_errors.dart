import 'package:dart_ipfs/src/core/types/p2p_types.dart';

/// Base class for network-related errors.
///
/// Network errors include connection failures, protocol errors,
/// and peer communication issues. Each error includes a timestamp.
abstract class NetworkError implements Exception {

  /// Creates a network error with the given [message].
  NetworkError(this.message) : timestamp = DateTime.now();
  /// The error message.
  final String message;

  /// When the error occurred.
  final DateTime timestamp;
}

class PeerConnectionError extends NetworkError {

  PeerConnectionError(this.peerId, String message) : super(message);
  final LibP2PPeerId peerId;
}

class ProtocolError extends NetworkError {

  ProtocolError(this.protocolId, String message) : super(message);
  final String protocolId;
}
