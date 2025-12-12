import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;

abstract class KademliaMessage {
  final String messageId;
  final p2p.PeerId sender;
  final p2p.PeerId? recipient;

  KademliaMessage(this.messageId, this.sender, this.recipient);

  kad.Message toDHTMessage();
}

class PingMessage extends KademliaMessage {
  PingMessage(String messageId, p2p.PeerId sender, p2p.PeerId recipient)
      : super(messageId, sender, recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.PING;
  }
}

class StoreMessage extends KademliaMessage {
  final Uint8List key;
  final Uint8List value;

  StoreMessage(String messageId, p2p.PeerId sender, p2p.PeerId recipient,
      this.key, this.value)
      : super(messageId, sender, recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = (dht_pb.Record()..key = key ..value = value);
  }
}

class FindNodeMessage extends KademliaMessage {
  final p2p.PeerId targetId;

  FindNodeMessage(
      String messageId, p2p.PeerId sender, p2p.PeerId recipient, this.targetId)
      : super(messageId, sender, recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = targetId.value;
  }
}

class FindValueMessage extends KademliaMessage {
  final Uint8List key;

  FindValueMessage(
      String messageId, p2p.PeerId sender, p2p.PeerId recipient, this.key)
      : super(messageId, sender, recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;
  }
}
