import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// Base class for protocol-specific message handlers.
///
/// Each protocol (Bitswap, DHT, etc.) implements this to handle
/// incoming messages and send responses.
abstract class ProtocolHandler {
  /// Creates a handler for [protocolId].
  ProtocolHandler(this.protocolId, this.peerId);

  /// The protocol identifier (e.g., '/ipfs/bitswap/1.2.0').
  final String protocolId;

  /// The local peer's ID.
  final p2p.PeerId peerId;

  /// Handles an incoming [message].
  Future<void> handleMessage(BaseMessage message);

  /// Sends a [message] to [targetPeerId].
  Future<void> sendMessage(p2p.PeerId targetPeerId, BaseMessage message);
}
