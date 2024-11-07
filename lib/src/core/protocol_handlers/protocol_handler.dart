import '../types/p2p_types.dart';
import '../messages/network_messages.dart';

abstract class ProtocolHandler {
  final String protocolId;

  ProtocolHandler(this.protocolId);

  Future<void> handleMessage(BaseMessage message);
  Future<void> sendMessage(LibP2PPeerId peerId, BaseMessage message);
}

class DHTProtocolHandler extends ProtocolHandler {
  DHTProtocolHandler() : super('dht');

  @override
  Future<void> handleMessage(BaseMessage message) async {
    if (message is DHTMessage) {
      // Handle DHT specific message
    }
  }
}
