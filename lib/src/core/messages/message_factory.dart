import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import '../generated/base_messages.pb.dart';
import '../generated/dht_messages.pb.dart';
import '../generated/bitswap_messages.pb.dart';
import 'package:p2plib/p2plib.dart' as p2p;

class MessageFactory {
  static IPFSMessage createBaseMessage({
    required String protocolId,
    required Uint8List payload,
    required String senderId,
    required MessageType type,
  }) {
    return IPFSMessage()
      ..protocolId = protocolId
      ..payload = payload
      ..timestamp = Int64.now()
      ..senderId = senderId
      ..type = type;
  }

  static DHTMessage createFindNodeMessage({
    required Uint8List targetId,
    required int numClosestPeers,
  }) {
    final request = FindNodeRequest()
      ..targetId = targetId
      ..numClosestPeers = numClosestPeers;

    return DHTMessage()
      ..messageId = _generateMessageId()
      ..type = DHTMessage_MessageType.FIND_NODE
      ..key = targetId
      ..timestamp = Int64.now();
  }

  static String _generateMessageId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
