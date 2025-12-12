
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/messages/network_messages.dart';

abstract class ProtocolHandler {
  final String protocolId;
  final p2p.PeerId peerId;

  ProtocolHandler(this.protocolId, this.peerId);

  Future<void> handleMessage(BaseMessage message);
  Future<void> sendMessage(p2p.PeerId targetPeerId, BaseMessage message);
}
