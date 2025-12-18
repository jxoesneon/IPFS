import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:p2plib/p2plib.dart' as p2p;

/// Base class for Kademlia DHT protocol messages.
abstract class KademliaMessage {

  /// Creates a message with [messageId], [sender], and optional [recipient].
  KademliaMessage(this.messageId, this.sender, this.recipient);
  /// Unique message identifier.
  final String messageId;

  /// Sender peer ID.
  final p2p.PeerId sender;

  /// Optional recipient peer ID.
  final p2p.PeerId? recipient;

  /// Converts to protobuf DHT message.
  kad.Message toDHTMessage();
}

/// PING message for liveness checks.
class PingMessage extends KademliaMessage {
  PingMessage(super.messageId, super.sender, p2p.PeerId super.recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()..type = kad.Message_MessageType.PING;
  }
}

class StoreMessage extends KademliaMessage {

  StoreMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.key,
    this.value,
  );
  final Uint8List key;
  final Uint8List value;

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.PUT_VALUE
      ..key = key
      ..record = (dht_pb.Record()
        ..key = key
        ..value = value);
  }
}

class FindNodeMessage extends KademliaMessage {

  FindNodeMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.targetId,
  );
  final p2p.PeerId targetId;

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = targetId.value;
  }
}

class FindValueMessage extends KademliaMessage {

  FindValueMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.key,
  );
  final Uint8List key;

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;
  }
}
