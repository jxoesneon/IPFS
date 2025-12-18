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

/// Error when connecting to a remote peer fails.
class PeerConnectionError extends NetworkError {
  /// Creates an error for a failed connection to [peerId].
  PeerConnectionError(this.peerId, String message) : super(message);

  /// The peer ID we failed to connect to.
  final LibP2PPeerId peerId;
}

/// Error in a P2P protocol (e.g., Bitswap, DHT).
class ProtocolError extends NetworkError {
  /// Creates an error for [protocolId].
  ProtocolError(this.protocolId, String message) : super(message);

  /// The protocol that encountered the error.
  final String protocolId;
}
