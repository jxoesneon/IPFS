import '../../generated/dht_messages.pb.dart';
import '../../core/messages/message_factory.dart';

class DHTProtocolHandler {
  static const String PROTOCOL_ID = '/ipfs/kad/1.0.0';
  final P2plibRouter _router;

  DHTProtocolHandler(this._router) {
    _setupHandlers();
  }

  void _setupHandlers() {
    _router.addMessageHandler(PROTOCOL_ID, _handleDHTMessage);
  }

  Future<void> _handleDHTMessage(LibP2PPacket packet) async {
    final message = DHTMessage.fromBuffer(packet.data);

    switch (message.type) {
      case DHTMessage_MessageType.FIND_NODE:
        await _handleFindNode(message, packet.sender);
        break;
      case DHTMessage_MessageType.STORE:
        await _handleStore(message, packet.sender);
        break;
      // Handle other message types...
    }
  }

  Future<void> _handleFindNode(DHTMessage message, LibP2PPeerId sender) async {
    final request = FindNodeRequest.fromBuffer(message.value);
    final closerPeers = await _findClosestPeers(request.targetId);

    final response = FindNodeResponse()
      ..closerPeers.addAll(closerPeers.map((peer) => Peer()
        ..peerId = peer.id.bytes
        ..addresses.addAll(peer.addresses.map((addr) => addr.toString()))));

    final responseMessage = DHTMessage()
      ..messageId = message.messageId
      ..type = DHTMessage_MessageType.FIND_NODE
      ..value = response.writeToBuffer();

    await _router.sendMessage(sender, responseMessage.writeToBuffer());
  }
}
