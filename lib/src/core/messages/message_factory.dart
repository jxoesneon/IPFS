import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart';

class MessageFactory {
  static IPFSMessage createBaseMessage({
    required String protocolId,
    required Uint8List payload,
    required String senderId,
    required IPFSMessage_MessageType type,
  }) {
    return IPFSMessage()
      ..protocolId = protocolId
      ..payload = payload
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..senderId = senderId
      ..type = type;
  }

  static DHTMessage createFindNodeMessage({
    required Uint8List targetId,
    required int numClosestPeers,
  }) {
    final findNodeRequest = FindNodeRequest()
      ..key = targetId
      ..numClosestPeers = numClosestPeers;

    final message = DHTMessage()
      ..messageId = _generateMessageId()
      ..type = DHTMessage_MessageType.FIND_NODE
      ..key = targetId
      ..record = findNodeRequest.writeToBuffer()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch);

    message.closerPeers.addAll([]);

    return message;
  }

  static String _generateMessageId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
