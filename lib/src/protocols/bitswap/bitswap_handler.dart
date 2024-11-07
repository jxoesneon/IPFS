import '../../generated/bitswap_messages.pb.dart';
import '../../core/storage/block_store.dart';

class BitSwapHandler {
  static const String PROTOCOL_ID = '/ipfs/bitswap/1.2.0';
  final BlockStore _blockStore;
  final P2plibRouter _router;

  BitSwapHandler(this._router, this._blockStore) {
    _setupHandlers();
  }

  Future<void> sendWantHave(LibP2PPeerId peer, List<Cid> cids) async {
    final message = BitSwapMessage()
      ..messageId = DateTime.now().toIso8601String()
      ..type = BitSwapMessage_MessageType.WANT_HAVE
      ..wantList.addAll(cids.map((cid) => WantList()
        ..cid = cid.bytes
        ..wantBlock = false
        ..priority = 1));

    await _router.sendMessage(peer, message.writeToBuffer());
  }

  Future<void> _handleBitSwapMessage(LibP2PPacket packet) async {
    final message = BitSwapMessage.fromBuffer(packet.data);

    switch (message.type) {
      case BitSwapMessage_MessageType.WANT_HAVE:
        await _handleWantHave(message, packet.sender);
        break;
      case BitSwapMessage_MessageType.BLOCK:
        await _handleBlock(message, packet.sender);
        break;
      // Handle other message types...
    }
  }

  Future<void> _handleWantHave(
      BitSwapMessage message, LibP2PPeerId sender) async {
    final responses = await Future.wait(message.wantList.map((want) async {
      final hasBlock = await _blockStore.has(Cid.fromBytes(want.cid));
      return BitSwapMessage()
        ..messageId = message.messageId
        ..type = hasBlock
            ? BitSwapMessage_MessageType.HAVE
            : BitSwapMessage_MessageType.DONT_HAVE
        ..blocks.add(Block()..cid = want.cid);
    }));

    for (final response in responses) {
      await _router.sendMessage(sender, response.writeToBuffer());
    }
  }
}
