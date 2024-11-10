import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart';

abstract class KademliaMessage {
  final String messageId;
  final p2p.PeerId sender;
  final p2p.PeerId? recipient;

  KademliaMessage(this.messageId, this.sender, this.recipient);

  DHTMessage toDHTMessage();
}

class PingMessage extends KademliaMessage {
  PingMessage(String messageId, p2p.PeerId sender, p2p.PeerId recipient)
      : super(messageId, sender, recipient);

  @override
  DHTMessage toDHTMessage() {
    return DHTMessage()
      ..messageId = messageId
      ..type = DHTMessage_MessageType.PING;
  }
}

class StoreMessage extends KademliaMessage {
  final Uint8List key;
  final Uint8List value;

  StoreMessage(String messageId, p2p.PeerId sender, p2p.PeerId recipient,
      this.key, this.value)
      : super(messageId, sender, recipient);

  @override
  DHTMessage toDHTMessage() {
    return DHTMessage()
      ..messageId = messageId
      ..type = DHTMessage_MessageType.PUT_VALUE
      ..key = key
      ..record = value;
  }
}

class FindNodeMessage extends KademliaMessage {
  final p2p.PeerId targetId;

  FindNodeMessage(
      String messageId, p2p.PeerId sender, p2p.PeerId recipient, this.targetId)
      : super(messageId, sender, recipient);

  @override
  DHTMessage toDHTMessage() {
    return DHTMessage()
      ..messageId = messageId
      ..type = DHTMessage_MessageType.FIND_NODE
      ..key = targetId.value;
  }
}

class FindValueMessage extends KademliaMessage {
  final Uint8List key;

  FindValueMessage(
      String messageId, p2p.PeerId sender, p2p.PeerId recipient, this.key)
      : super(messageId, sender, recipient);

  @override
  DHTMessage toDHTMessage() {
    return DHTMessage()
      ..messageId = messageId
      ..type = DHTMessage_MessageType.FIND_VALUE
      ..key = key;
  }
}
