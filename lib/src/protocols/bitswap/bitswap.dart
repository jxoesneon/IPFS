import 'dart:math';
import 'ledger.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as bitswap_message;
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as bitswap_pb;

// lib/src/protocols/bitswap/bitswap.dart

class Bitswap {
  final P2plibRouter _router;
  final BitLedger _ledger;
  final Datastore _datastore;
  final Set<LibP2PPeerId> _peers = {};
  final dynamic config;

  static const int maxPrefixLength =
      64; // Or whatever maximum prefix length is appropriate

  Bitswap(this._router, this._ledger, this._datastore, [this.config]);

  /// Starts the Bitswap protocol.
  Future<void> start() async {
    _router.addMessageHandler('/ipfs/bitswap/1.2.0', (LibP2PPacket packet) {
      _handlePacket(packet);
    });
    await _router.start();
    print('Bitswap started.');
  }

  /// Stops the Bitswap protocol.
  Future<void> stop() async {
    await _router.stop();
    print('Bitswap stopped.');
  }

  /// Requests a block from the network.
  Future<Block?> wantBlock(String cid) async {
    print('Requesting block with CID: $cid');

    // Create a Wantlist entry for the requested block
    final wantlistEntry = proto.WantlistEntry()
      ..block = Uint8List.fromList(utf8.encode(cid))
      ..wantType = proto.WantType.WANT_TYPE_BLOCK;

    // Send the wantlist to peers
    for (var peer in _peers) {
      await sendWantlist(EncodingUtils.toBase58(peer.value), wantlistEntry);
    }

    // Placeholder for actual block retrieval logic
    return null;
  }

  /// Provides a block to the network.
  void provide(String cid) {
    print('Providing block with CID: $cid');

    // Notify peers about the available block
    for (var peer in _peers) {
      _sendHave(EncodingUtils.toBase58(peer.value), cid);
    }
  }

  /// Retrieves block data from the ledger.
  Uint8List getBlockData(String cid) {
    return _ledger.getBlockData(cid);
  }

  /// Handles incoming packets from peers.
  void _handlePacket(LibP2PPacket packet) async {
    try {
      final message = await bitswap_message.Message.fromBytes(packet.datagram);
      final peerId = EncodingUtils.toBase58(packet.srcPeerId.value);

      // Handle blocks if present
      if (message.hasBlocks()) {
        for (final block in message.getBlocks()) {
          await _handleReceivedBlock(peerId, block);
        }
      }

      // Handle wantlist if present
      if (message.hasWantlist()) {
        final wantlist = message.getWantlist();
        for (final entry in wantlist.entries.values) {
          // Convert the custom WantlistEntry to protobuf WantlistEntry
          final protoEntry = bitswap_pb.WantlistEntry()
            ..block = Uint8List.fromList(utf8.encode(entry.cid))
            ..priority = entry.priority
            ..cancel = entry.cancel
            ..wantType = _convertToProtoWantType(entry.wantType)
            ..sendDontHave = entry.sendDontHave;
          
          await handleWantBlock(peerId, protoEntry);
        }
      }

      // Handle block presences if present
      if (message.hasBlockPresences()) {
        for (final presence in message.getBlockPresences()) {
          if (presence.type == bitswap_message.BlockPresenceType.have) {
            print('Peer $peerId has block ${presence.cid}');
          } else {
            print('Peer $peerId does not have block ${presence.cid}');
          }
        }
      }
    } catch (e) {
      print('Error handling BitSwap packet: $e');
    }
  }

  /// Handles received blocks from peers.
  Future<void> _handleReceivedBlock(
      String srcPeerId, Block block) async {
    final blockId = block.cid.toString();
    print('Received block with CID $blockId from $srcPeerId.');

    // Store received block in datastore
    await _datastore.put(blockId, block);

    // Store block data in ledger and update received bytes
    _ledger.storeBlockData(blockId, block.data);
    _ledger.addReceivedBytes(block.data.length);
  }

  /// Handles requests for blocks from peers.
  Future<void> handleWantBlock(
      String peerId, bitswap_pb.WantlistEntry entry) async {
    final blockId = base64.encode(entry.block);

    // Check if we have the requested block locally
    final block = await _datastore.get(blockId);
    if (block != null) {
      print('Sending requested block $blockId to $peerId.');
      await sendBlock(peerId, block.data);
    } else if (entry.sendDontHave) {
      await sendDontHave(peerId, entry);
    }
  }

  Future<void> sendBlock(String peerId, Uint8List data) async {
    final message = proto.Message()
      ..blocks.add(proto.Block()
        ..prefix = Uint8List.fromList(utf8.encode(
            data.sublist(0, min(data.length, maxPrefixLength)).toString()))
        ..data = data);
    await send(peerId, message);
  }

  Future<void> sendWantlist(String peerId, proto.WantlistEntry entry) async {
    final wantlist = proto.Wantlist();
    wantlist.entries.add(entry);

    final message = proto.Message()..wantlist = wantlist;

    await send(peerId, message);
  }

  void addPeer(LibP2PPeerId peerId) {
    _peers.add(peerId);
    print(
        'Peer ${EncodingUtils.toBase58(peerId.value)} added to Bitswap network.');
  }

  void removePeer(LibP2PPeerId peerId) {
    _peers.remove(peerId);
    print(
        'Peer ${EncodingUtils.toBase58(peerId.value)} removed from Bitswap network.');
  }

  // --- Handlers for other message types ---

  /// Handles incoming "have" requests from peers.
  void handleHave(String peerId, proto.WantlistEntry entry) {
    final blockId = base64.encode(entry.block);

    // Check if we have the requested block in our ledger
    if (_ledger.hasBlock(blockId)) {
      print('Responding to have request for block $blockId from $peerId.');
      sendHave(peerId, entry);
    } else if (entry.sendDontHave) {
      sendDontHave(peerId, entry);
    }
  }

  /// Handles cancel requests from peers.
  void handleCancel(String peerId, proto.WantlistEntry entry) {
    final blockId = base64.encode(entry.block);

    // Log the cancellation
    print('Received cancel request for block $blockId from $peerId.');

    // Remove the block from our wantlist or any pending requests
    _removeFromWantlist(blockId, peerId);
  }

  /// Removes a block from the wantlist or pending requests.
  void _removeFromWantlist(String blockId, String peerId) {
    try {
      final peer = Peer.fromId(peerId);
      if (_peers.contains(peer.id)) {
        print('Removing block $blockId from wantlist for peer $peerId.');
        // Implement actual removal logic based on your data structures here
      } else {
        print('Peer $peerId not found in local peers list.');
      }
    } catch (e) {
      print('Error creating peer from ID: $e');
    }
  }

  // Helper function to send a Bitswap message to a peer
  Future<void> send(String peerId, proto.Message message) async {
    try {
      await _router.sendMessage(peerId, message.writeToBuffer());
    } catch (e) {
      print('Error sending message to $peerId: $e');
    }
  }

  /// Sends a HAVE message to a peer for a specific block
  Future<void> _sendHave(String peerId, String cid) async {
    final message = proto.Message()
      ..blockPresences.add(proto.BlockPresence()
        ..cid = Uint8List.fromList(utf8.encode(cid))
        ..type = proto.BlockPresence_Type.HAVE);

    await send(peerId, message);
  }

  /// Sends a DONT_HAVE message to a peer for a specific wantlist entry
  Future<void> sendDontHave(String peerId, proto.WantlistEntry entry) async {
    final message = proto.Message()
      ..blockPresences.add(proto.BlockPresence()
        ..cid = entry.block
        ..type = proto.BlockPresence_Type.DONT_HAVE);

    await send(peerId, message);
  }

  /// Sends a HAVE message to a peer for a specific wantlist entry
  Future<void> sendHave(String peerId, proto.WantlistEntry entry) async {
    final message = proto.Message()
      ..blockPresences.add(proto.BlockPresence()
        ..cid = entry.block
        ..type = proto.BlockPresence_Type.HAVE);

    await send(peerId, message);
  }

  // Add this helper method to convert between WantType enums
  bitswap_pb.WantType _convertToProtoWantType(bitswap_message.WantType type) {
    switch (type) {
      case bitswap_message.WantType.block:
        return bitswap_pb.WantType.WANT_TYPE_BLOCK;
      case bitswap_message.WantType.have:
        return bitswap_pb.WantType.WANT_TYPE_HAVE;
      default:
        return bitswap_pb.WantType.WANT_TYPE_UNSPECIFIED;
    }
  }
}
