import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';

/// Base class for network-related events.
///
/// All events include a timestamp and event type identifier.
abstract class NetworkEvent {
  /// When this event occurred.
  final DateTime timestamp;

  /// The event type identifier.
  final String eventType;

  /// Creates a network event with the given [eventType].
  NetworkEvent(this.eventType) : timestamp = DateTime.now();
}

/// Events related to peer connection status.
class PeerEvent extends NetworkEvent {
  /// The peer this event relates to.
  final LibP2PPeerId peerId;

  /// Creates a peer connected event.
  PeerEvent.connected(this.peerId) : super('peer_connected');

  /// Creates a peer disconnected event.
  PeerEvent.disconnected(this.peerId) : super('peer_disconnected');
}

/// Event for received network messages.
class MessageEvent extends NetworkEvent {
  /// The received message.
  final BaseMessage message;

  /// The peer that sent the message.
  final LibP2PPeerId sender;

  /// Creates a message event.
  MessageEvent(this.message, this.sender) : super('message_received');
}
