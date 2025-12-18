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
  /// Creates a ping message.
  PingMessage(super.messageId, super.sender, p2p.PeerId super.recipient);

  @override
  kad.Message toDHTMessage() {
    return kad.Message()..type = kad.Message_MessageType.PING;
  }
}

/// STORE message for putting values in the DHT.
class StoreMessage extends KademliaMessage {
  /// Creates a store message with [key] and [value].
  StoreMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.key,
    this.value,
  );

  /// The key to store.
  final Uint8List key;

  /// The value to store.
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

/// FIND_NODE message for locating peers.
class FindNodeMessage extends KademliaMessage {
  /// Creates a find node message for [targetId].
  FindNodeMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.targetId,
  );

  /// The target peer to find.
  final p2p.PeerId targetId;

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.FIND_NODE
      ..key = targetId.value;
  }
}

/// GET_VALUE message for retrieving values.
class FindValueMessage extends KademliaMessage {
  /// Creates a find value message for [key].
  FindValueMessage(
    super.messageId,
    super.sender,
    p2p.PeerId super.recipient,
    this.key,
  );

  /// The key to look up.
  final Uint8List key;

  @override
  kad.Message toDHTMessage() {
    return kad.Message()
      ..type = kad.Message_MessageType.GET_VALUE
      ..key = key;
  }
}
