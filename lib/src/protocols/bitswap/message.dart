import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' show Block;
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as pb;
// If needed for int64? priorities are int32.

/// Represents a Bitswap protocol message.
class Message {
  /// Creates an empty message.
  Message();

  /// List of blocks being sent (Payload)
  final List<Block> _blocks = [];

  /// The wantlist containing requested blocks
  final Wantlist _wantlist = Wantlist();

  /// Block presences for HAVE/DONT_HAVE responses
  final List<BlockPresence> _blockPresences = [];

  /// Transient field: The peer ID of the sender (not part of wire protocol)
  String? from;

  /// Transient field: Pending bytes (Bitswap 1.2)
  int pendingBytes = 0;

  /// Adds a block to the message payload.
  void addBlock(Block block) {
    _blocks.add(block);
  }

  /// Returns an unmodifiable list of blocks.
  List<Block> getBlocks() => List.unmodifiable(_blocks);

  /// Adds a wantlist entry for a CID.
  void addWantlistEntry(
    String cid, {
    int priority = 1,
    bool cancel = false,
    WantType wantType = WantType.block,
    bool sendDontHave = false,
  }) {
    _wantlist.addEntry(
      WantlistEntry(
        cid: cid,
        priority: priority,
        cancel: cancel,
        wantType: wantType,
        sendDontHave: sendDontHave,
      ),
    );
  }

  /// Returns the message wantlist.
  Wantlist getWantlist() => _wantlist;

  /// Adds a block presence notification.
  void addBlockPresence(String cid, BlockPresenceType type) {
    _blockPresences.add(BlockPresence(cid: cid, type: type));
  }

  /// Returns an unmodifiable list of block presences.
  List<BlockPresence> getBlockPresences() => List.unmodifiable(_blockPresences);

  /// Returns true if this message contains blocks.
  bool hasBlocks() => _blocks.isNotEmpty;

  /// Returns true if this message has wantlist entries.
  bool hasWantlist() => _wantlist.entries.isNotEmpty;

  /// Returns true if this message has block presence notifications.
  bool hasBlockPresences() => _blockPresences.isNotEmpty;

  /// Creates a Message from its protobuf byte representation
  static Future<Message> fromBytes(Uint8List bytes) async {
    final pbMessage = pb.Message.fromBuffer(bytes);
    final message = Message();

    // Parse pending bytes
    message.pendingBytes = pbMessage.pendingBytes;

    // Parse wantlist
    if (pbMessage.hasWantlist()) {
      for (var entry in pbMessage.wantlist.entries) {
        // Entry block is CID bytes.
        // We need to convert bytes to CID string for internal storage.
        try {
          // CID.fromBytes() handles both CIDv0 and CIDv1
          final cidObj = CID.fromBytes(Uint8List.fromList(entry.block));
          final cidStr = cidObj.encode();

          final wantType = entry.wantType == pb.Message_Wantlist_WantType.Have
              ? WantType.have
              : WantType.block;

          message.addWantlistEntry(
            cidStr,
            priority: entry.priority,
            cancel: entry.cancel,
            wantType: wantType,
            sendDontHave: entry.sendDontHave,
          );
        } catch (e) {
          // print('Error parsing wantlist entry CID: $e');
        }
      }
    }

    // Parse blocks (Payload - 1.1+)
    for (var payloadBlock in pbMessage.payload) {
      try {
        // Payload has prefix and data.
        // We need to reconstruct the block.
        // prefix logic?
        // Actually usually we just check data matches requested?
        // Block.fromData(data).
        final newBlock = await Block.fromData(
          Uint8List.fromList(payloadBlock.data),
          format: 'dag-pb', // Assume dag-pb default or infer?
        );
        message.addBlock(newBlock);
      } catch (e) {
        // print('Error parsing payload block: $e');
      }
    }

    // Parse legacy blocks (1.0)
    for (var blockBytes in pbMessage.blocks) {
      try {
        final newBlock = await Block.fromData(Uint8List.fromList(blockBytes), format: 'dag-pb');
        message.addBlock(newBlock);
      } catch (e) {
        // print('Error parsing legacy block: $e');
      }
    }

    // Parse block presences
    for (var pres in pbMessage.blockPresences) {
      try {
        final cidObj = CID.fromBytes(Uint8List.fromList(pres.cid));
        final type = pres.type == pb.Message_BlockPresence_Type.DontHave
            ? BlockPresenceType.dontHave
            : BlockPresenceType.have;
        message.addBlockPresence(cidObj.encode(), type);
      } catch (e) {
        // Ignore invalid block presence
      }
    }

    return message;
  }

  /// Converts the message to its protobuf byte representation
  Uint8List toBytes() {
    final pbMessage = pb.Message();

    pbMessage.pendingBytes = pendingBytes;

    // Add wantlist entries
    if (_wantlist.entries.isNotEmpty) {
      final pbWantlist = pb.Message_Wantlist();
      pbWantlist.full = false; // Default to partial unless specified?

      for (var entry in _wantlist.entries.values) {
        final pbEntry = pb.Message_Wantlist_Entry();
        // Convert CID string to bytes using standard CID class
        try {
          final cidObj = CID.decode(entry.cid);
          pbEntry.block = cidObj.toBytes(); // Using updated CID class method
          pbEntry.priority = entry.priority;
          pbEntry.cancel = entry.cancel;
          pbEntry.sendDontHave = entry.sendDontHave;
          pbEntry.wantType = entry.wantType == WantType.have
              ? pb.Message_Wantlist_WantType.Have
              : pb.Message_Wantlist_WantType.Block;

          pbWantlist.entries.add(pbEntry);
        } catch (e) {
          // print('Skipping invalid CID in wantlist: ${entry.cid}');
        }
      }
      pbMessage.wantlist = pbWantlist;
    }

    // Add blocks (Payload)
    for (var block in _blocks) {
      final pbBlock = pb.Message_Block();
      // Prefix? Usually empty for CIDv0. Or part of CIDv1?
      // Bitswap 1.1: Payload includes prefix and data.
      // Bitswap 1.1: Payload includes prefix and data.
      pbBlock.data = block.data;

      // Set prefix if needed for proper CID reconstruction on receiver (CIDv1)
      if (block.cid.version == 1) {
        final cidBytes = block.cid.toBytes();
        // Digest is at the end. Prefix is everything before it.
        final digestSize = block.cid.multihash.digest.length;
        if (cidBytes.length > digestSize) {
          pbBlock.prefix = cidBytes.sublist(0, cidBytes.length - digestSize);
        }
      }

      pbMessage.payload.add(pbBlock);
    }

    // Add block presences
    for (var pres in _blockPresences) {
      try {
        final cidObj = CID.decode(pres.cid);
        final pbPres = pb.Message_BlockPresence();
        pbPres.cid = cidObj.toBytes();
        pbPres.type = pres.type == BlockPresenceType.dontHave
            ? pb.Message_BlockPresence_Type.DontHave
            : pb.Message_BlockPresence_Type.Have;
        pbMessage.blockPresences.add(pbPres);
      } catch (e) {
        // Ignore invalid block presence
      }
    }

    return pbMessage.writeToBuffer();
  }
}

/// The type of block request.
enum WantType {
  /// Request the full block data.
  block,

  /// Request only whether the peer has the block.
  have,
}

/// Block presence response type.
enum BlockPresenceType {
  /// Peer has the block.
  have,

  /// Peer does not have the block.
  dontHave,
}

/// An entry in a Bitswap wantlist.
class WantlistEntry {
  /// Creates a wantlist entry.
  WantlistEntry({
    required this.cid,
    this.priority = 1,
    this.cancel = false,
    this.wantType = WantType.block,
    this.sendDontHave = false,
  });

  /// The CID being requested.
  final String cid;

  /// Priority for this request (higher = more urgent).
  final int priority;

  /// Whether this cancels a previous request.
  final bool cancel;

  /// The type of request (block or have).
  final WantType wantType;

  /// Whether to send DONT_HAVE if the peer lacks the block.
  final bool sendDontHave;
}

/// Manages a set of wantlist entries by CID.
class Wantlist {
  /// Map of CID to wantlist entry.
  final Map<String, WantlistEntry> entries = {};

  /// Adds or updates an entry.
  void addEntry(WantlistEntry entry) {
    entries[entry.cid] = entry;
  }

  /// Removes an entry by CID.
  void removeEntry(String cid) {
    entries.remove(cid);
  }

  /// Returns whether the wantlist contains a CID.
  bool contains(String cid) => entries.containsKey(cid);
}

/// A block presence notification (HAVE or DONT_HAVE).
class BlockPresence {
  /// Creates a block presence.
  BlockPresence({required this.cid, required this.type});

  /// The CID this presence is for.
  final String cid;

  /// The presence type.
  final BlockPresenceType type;
}
