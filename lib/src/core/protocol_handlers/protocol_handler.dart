import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart' as pb;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/generate_message_id.dart';
import 'package:fixnum/fixnum.dart';
import 'package:p2plib/p2plib.dart' as p2p;

import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';

abstract class ProtocolHandler {
  final String protocolId;
  final p2p.PeerId peerId;

  ProtocolHandler(this.protocolId, this.peerId);

  Future<void> handleMessage(BaseMessage message);
  Future<void> sendMessage(p2p.PeerId targetPeerId, BaseMessage message);
}

class DHTProtocolHandler extends ProtocolHandler {
  final P2plibRouter _router;

  DHTProtocolHandler(this._router, p2p.PeerId peerId) : super('dht', peerId);

  @override
  Future<void> handleMessage(BaseMessage message) async {
    if (message is DHTMessage) {
      // Handle DHT specific message
    }
  }

  @override
  Future<void> sendMessage(p2p.PeerId targetPeerId, BaseMessage message) async {
    try {
      await _router.sendMessage(targetPeerId, message.toBytes());
    } catch (e) {
      print(
          'Error sending message to peer ${Base58().encode(targetPeerId.value)}: $e');
    }
  }

  Future<void> sendDHTMessage(
      p2p.PeerId targetPeerId, DHTMessage message) async {
    // Convert our custom DHTMessage to protobuf DHTMessage
    final pbMessage = pb.DHTMessage()
      ..messageId = generateMessageId()
      ..type = _convertMessageType(message.messageType)
      ..record = message.data
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch);

    // Now we can use writeToBuffer()
    final bytes = pbMessage.writeToBuffer();
    await _router.sendMessage(targetPeerId, bytes);
  }

  pb.DHTMessage_MessageType _convertMessageType(String type) {
    switch (type) {
      case 'FIND_NODE':
        return pb.DHTMessage_MessageType.FIND_NODE;
      case 'STORE':
        return pb.DHTMessage_MessageType.PUT_VALUE;
      // Add other cases as needed
      default:
        return pb.DHTMessage_MessageType.UNKNOWN;
    }
  }
}
