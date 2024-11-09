import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' show Block;
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap_pb;

/// Represents a Bitswap protocol message
class Message {
  /// List of blocks being sent
  final List<Block> _blocks = [];

  /// The wantlist containing requested blocks
  final Wantlist _wantlist = Wantlist();

  /// The peer ID of the sender
  String? from;

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
    final pbMessage = bitswap_pb.Message.fromBuffer(bytes);
    final message = Message();

    // Parse wantlist
    if (pbMessage.hasWantlist()) {
      for (var entry in pbMessage.wantlist.entries) {
        message.addWantlistEntry(base64.encode(entry.block),
            priority: entry.priority,
            cancel: entry.cancel,
            wantType: _convertWantType(entry.wantType),
            sendDontHave: entry.sendDontHave);
      }
    }

    // Parse blocks using EncodingUtils
    for (var block in pbMessage.blocks) {
      final cid = CID.fromBytes(Uint8List.fromList(block.prefix), 'dag-pb');
      message.addBlock(await Block.fromData(
        Uint8List.fromList(block.data),
        format: 'dag-pb',
      ));
    }

    // Parse block presences using EncodingUtils
    for (var presence in pbMessage.blockPresences) {
      message.addBlockPresence(
          EncodingUtils.toBase58(Uint8List.fromList(presence.cid)),
          presence.type == bitswap_pb.BlockPresence_Type.HAVE
              ? BlockPresenceType.have
              : BlockPresenceType.dontHave);
    }

    return message;
  }

  /// Converts the message to its protobuf byte representation
  Uint8List toBytes() {
    final pbMessage = bitswap_pb.Message();

    // Add blocks
    for (var block in _blocks) {
      pbMessage.blocks.add(bitswap_pb.Block()
        ..prefix = EncodingUtils.cidToBytes(block.cid)
        ..data = block.data);
    }

    // Add block presences
    for (var presence in _blockPresences) {
      pbMessage.blockPresences.add(bitswap_pb.BlockPresence()
        ..cid = Uint8List.fromList(EncodingUtils.fromBase58(presence.cid))
        ..type = _convertPresenceType(presence.type));
    }

    return pbMessage.writeToBuffer();
  }

  static WantType _convertWantType(bitswap_pb.WantType pbType) {
    switch (pbType) {
      case bitswap_pb.WantType.WANT_TYPE_BLOCK:
        return WantType.block;
      case bitswap_pb.WantType.WANT_TYPE_HAVE:
        return WantType.have;
      default:
        return WantType.block;
    }
  }

  static bitswap_pb.BlockPresence_Type _convertPresenceType(
      BlockPresenceType type) {
    return type == BlockPresenceType.have
        ? bitswap_pb.BlockPresence_Type.HAVE
        : bitswap_pb.BlockPresence_Type.DONT_HAVE;
  }
}

enum WantType { block, have }

enum BlockPresenceType { have, dontHave }

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
