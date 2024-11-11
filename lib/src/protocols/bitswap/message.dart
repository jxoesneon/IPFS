import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' show Block;
import 'package:dart_ipfs/src/proto/generated/bitswap_messages.pb.dart'
    as bitswap_messages_pb;
import 'package:dart_ipfs/src/proto/generated/bitswap_messages.pbenum.dart'
    show BitSwapMessage_MessageType;

/// Represents a Bitswap protocol message
class Message {
  /// List of blocks being sent
  final List<Block> _blocks = [];

  /// The wantlist containing requested blocks
  final Wantlist _wantlist = Wantlist();

  /// The peer ID of the sender
  String? from;

  /// Message ID for tracking requests
  String? messageId;

  /// Message type
  MessageType? type;

  /// Block presences for HAVE/DONT_HAVE responses
  final List<BlockPresence> _blockPresences = [];

  Message();

  void addBlock(Block block) {
    _blocks.add(block);
  }

  List<Block> getBlocks() => List.unmodifiable(_blocks);

  void addWantlistEntry(String cid,
      {int priority = 1,
      bool cancel = false,
      WantType wantType = WantType.block,
      bool sendDontHave = false}) {
    _wantlist.addEntry(WantlistEntry(
        cid: cid,
        priority: priority,
        cancel: cancel,
        wantType: wantType,
        sendDontHave: sendDontHave));
  }

  Wantlist getWantlist() => _wantlist;

  void addBlockPresence(String cid, BlockPresenceType type) {
    _blockPresences.add(BlockPresence(cid: cid, type: type));
  }

  List<BlockPresence> getBlockPresences() => List.unmodifiable(_blockPresences);

  bool hasBlocks() => _blocks.isNotEmpty;
  bool hasWantlist() => _wantlist.entries.isNotEmpty;
  bool hasBlockPresences() => _blockPresences.isNotEmpty;

  /// Creates a Message from its protobuf byte representation
  static Future<Message> fromBytes(Uint8List bytes) async {
    final pbMessage = bitswap_messages_pb.BitSwapMessage.fromBuffer(bytes);
    final message = Message();

    // Set message ID and type if present
    if (pbMessage.hasMessageId()) {
      message.messageId = pbMessage.messageId;
    }
    if (pbMessage.hasType()) {
      message.type = _convertFromProtoMessageType(pbMessage.type);
    }

    // Parse wantlist
    for (var entry in pbMessage.wantList) {
      message.addWantlistEntry(
        base64.encode(entry.cid),
        priority: entry.priority,
        wantType: WantType.block, // Default to block for now
      );
    }

    // Parse blocks
    for (var block in pbMessage.blocks) {
      final newBlock = await Block.fromData(
        Uint8List.fromList(block.data),
        format: 'dag-pb',
      );
      message.addBlock(newBlock);
    }

    return message;
  }

  /// Converts the message to its protobuf byte representation
  Uint8List toBytes() {
    final pbMessage = bitswap_messages_pb.BitSwapMessage();

    // Set message ID if present
    if (messageId != null) {
      pbMessage.messageId = messageId!;
    }

    // Set message type if present
    if (type != null) {
      pbMessage.type = _convertMessageType(type!);
    }

    // Add wantlist entries
    for (var entry in _wantlist.entries.values) {
      final wantList = bitswap_messages_pb.WantList()
        ..cid = Uint8List.fromList(EncodingUtils.fromBase58(entry.cid))
        ..priority = entry.priority
        ..wantBlock = true;
      pbMessage.wantList.add(wantList);
    }

    // Add blocks
    for (var block in _blocks) {
      final pbBlock = bitswap_messages_pb.Block()
        ..cid = EncodingUtils.cidToBytes(block.cid)
        ..data = block.data;
      pbMessage.blocks.add(pbBlock);
    }

    return pbMessage.writeToBuffer();
  }

  static BitSwapMessage_MessageType _convertMessageType(MessageType type) {
    switch (type) {
      case MessageType.wantBlock:
        return BitSwapMessage_MessageType.WANT_BLOCK;
      case MessageType.wantHave:
        return BitSwapMessage_MessageType.WANT_HAVE;
      case MessageType.block:
        return BitSwapMessage_MessageType.BLOCK;
      case MessageType.have:
        return BitSwapMessage_MessageType.HAVE;
      case MessageType.dontHave:
        return BitSwapMessage_MessageType.DONT_HAVE;
      case MessageType.unknown:
      default:
        return BitSwapMessage_MessageType.UNKNOWN;
    }
  }

  static MessageType _convertFromProtoMessageType(
      BitSwapMessage_MessageType type) {
    switch (type) {
      case BitSwapMessage_MessageType.WANT_BLOCK:
        return MessageType.wantBlock;
      case BitSwapMessage_MessageType.WANT_HAVE:
        return MessageType.wantHave;
      case BitSwapMessage_MessageType.BLOCK:
        return MessageType.block;
      case BitSwapMessage_MessageType.HAVE:
        return MessageType.have;
      case BitSwapMessage_MessageType.DONT_HAVE:
        return MessageType.dontHave;
      case BitSwapMessage_MessageType.UNKNOWN:
      default:
        return MessageType.unknown;
    }
  }

  String? getMessageId() => messageId;
  void setMessageId(String id) => messageId = id;

  MessageType? getType() => type;
  void setType(MessageType t) => type = t;
}

enum WantType { block, have }

enum BlockPresenceType { have, dontHave }

enum MessageType { unknown, wantHave, wantBlock, have, dontHave, block }

class WantlistEntry {
  final String cid;
  final int priority;
  final bool cancel;
  final WantType wantType;
  final bool sendDontHave;

  WantlistEntry({
    required this.cid,
    this.priority = 1,
    this.cancel = false,
    this.wantType = WantType.block,
    this.sendDontHave = false,
  });
}

class Wantlist {
  final Map<String, WantlistEntry> entries = {};

  void addEntry(WantlistEntry entry) {
    entries[entry.cid] = entry;
  }

  void removeEntry(String cid) {
    entries.remove(cid);
  }

  bool contains(String cid) => entries.containsKey(cid);
}

class BlockPresence {
  final String cid;
  final BlockPresenceType type;

  BlockPresence({required this.cid, required this.type});
}
