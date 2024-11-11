import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap_messages.pb.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as domain;

class BitSwapHandler {
  static const String PROTOCOL_ID = '/ipfs/bitswap/1.2.0';
  final BlockStore _blockStore;
  final P2plibRouter _router;

  BitSwapHandler(this._router, this._blockStore) {
    _setupHandlers();
  }

  Future<void> sendWantHave(LibP2PPeerId peer, List<CID> cids) async {
    final message = BitSwapMessage(
      messageId: DateTime.now().toIso8601String(),
      type: BitSwapMessage_MessageType.WANT_HAVE,
      wantList: cids.map((cid) => WantList(
            cid: cid.multihash,
            wantBlock: false,
            priority: 1,
          )),
    );

    await _router.sendMessage(peer, message.writeToBuffer());
  }

  Future<void> _handleBitSwapMessage(LibP2PPacket packet) async {
    final message = BitSwapMessage.fromBuffer(packet.datagram);
    final peerId = packet.srcPeerId;

    switch (message.type) {
      case BitSwapMessage_MessageType.WANT_HAVE:
        await _handleWantHave(message, peerId);
        break;
      case BitSwapMessage_MessageType.BLOCK:
        await _handleBlock(message, peerId);
        break;
      // Handle other message types...
    }
  }

  Future<void> _handleWantHave(
      BitSwapMessage message, LibP2PPeerId sender) async {
    final responses = await Future.wait(message.wantList.map((want) async {
      final hasBlock = await _blockStore.has(
          CID.fromBytes(Uint8List.fromList(want.cid), 'dag-pb').toString());
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

  Future<void> _handleBlock(BitSwapMessage message, LibP2PPeerId sender) async {
    for (final block in message.blocks) {
      if (block.cid.isEmpty) {
        print('Received invalid block from $sender');
        continue;
      }

      try {
        final cid = CID.fromBytes(Uint8List.fromList(block.cid), 'dag-pb');

        // Create a Block instance using the fromData factory constructor
        final domainBlock = await domain.Block.fromData(
          Uint8List.fromList(block.data),
          format: 'dag-pb',
        );

        // Store the block in the blockstore
        await _blockStore.addBlock(domainBlock.toProto());

        // Send acknowledgment back to sender using protobuf Block
        final response = BitSwapMessage()
          ..messageId = message.messageId
          ..type = BitSwapMessage_MessageType.HAVE
          ..blocks.add(Block()
            ..cid = cid.multihash
            ..data = block.data);

        await _router.sendMessage(sender, response.writeToBuffer());
      } catch (e) {
        print('Error handling block from $sender: $e');

        // Send error response
        final errorResponse = BitSwapMessage()
          ..messageId = message.messageId
          ..type = BitSwapMessage_MessageType.DONT_HAVE
          ..blocks.add(Block()..cid = block.cid); // Use original cid bytes

        await _router.sendMessage(sender, errorResponse.writeToBuffer());
      }
    }
  }

  void _setupHandlers() {
    // Register the protocol first
    _router.registerProtocol(PROTOCOL_ID);

    // Then add the message handler
    _router.addMessageHandler(PROTOCOL_ID, _handleBitSwapMessage);

    print('Bitswap protocol handlers initialized');
  }
}
