import 'package:dart_ipfs/src/core/types/p2p_types.dart';

abstract class NetworkError implements Exception {
  final String message;
  final DateTime timestamp;

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
