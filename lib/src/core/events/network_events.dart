import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';

abstract class NetworkEvent {
  final DateTime timestamp;
  final String eventType;

  NetworkEvent(this.eventType) : timestamp = DateTime.now();
}

class PeerEvent extends NetworkEvent {
  final LibP2PPeerId peerId;

  PeerEvent.connected(this.peerId) : super('peer_connected');
  PeerEvent.disconnected(this.peerId) : super('peer_disconnected');
}

class MessageEvent extends NetworkEvent {
  final BaseMessage message;
  final LibP2PPeerId sender;

  MessageEvent(this.message, this.sender) : super('message_received');
}
