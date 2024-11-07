// lib/src/protocols/bitswap/bitswap.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:protobuf/protobuf.dart';
import 'package:p2plib/p2plib.dart'; // Import p2plib for peer management

import '../../core/data_structures/block.dart';
import '/../src/proto/generated/bitswap/bitswap.pb.dart' as bitswap;
import 'ledger.dart';
import '../../storage/datastore.dart';
import '../../utils/varint.dart';
import '../../core/ipfs_node/ipfs_node.dart';
import '../../core/types/p2p_types.dart';

class Bitswap {
  final P2plibRouter _router;
  final BitLedger _ledger;
  final Datastore _datastore;
  final String _nodeId;
  final Set<LibP2PPeerId> _peers = {};
  final dynamic config;

  Bitswap(this._router, this._ledger, this._datastore, this._nodeId, [this.config]);

  /// Starts the Bitswap protocol.
  Future<void> start() async {
    _router.onMessage((packet) => _handlePacket(packet));
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
    final wantlistEntry = bitswap.Wantlist.Entry()
      ..block = Uint8List.fromList(utf8.encode(cid))
      ..wantType = bitswap.WantType.WANT_TYPE_BLOCK;

    // Send the wantlist to peers
    for (var peer in _peers) {
      await _sendWantlist(peer.toBase58String(), wantlistEntry);
    }

    // Placeholder for actual block retrieval logic
    return null; 
  }

  /// Provides a block to the network.
  void provide(String cid) {
    print('Providing block with CID: $cid');

    // Notify peers about the available block
    for (var peer in _peers) {
      _sendHave(peer.toBase58String(), cid);
    }
  }

  /// Retrieves block data from the ledger.
  Uint8List getBlockData(String cid) {
    return _ledger.getBlockData(cid);
  }

  /// Handles incoming packets from peers.
  void _handlePacket(LibP2PPacket packet) {
    final message = NetworkMessage.fromBytes(packet.datagram);
    // Handle message
  }

  /// Handles received blocks from peers.
  void _handleReceivedBlock(String srcPeerId, bitswap.BlockMsg blockMsg) {
    print('Received block with CID prefix ${blockMsg.prefix} from $srcPeerId.');

    // Store received block in datastore
    _datastore.put(
      base64.encode(blockMsg.prefix),
      Block(data: blockMsg.data, cid: base64.encode(blockMsg.prefix)),
    );

    // Update ledger with received information
    _ledger.recordReceived(srcPeerId, base64.encode(blockMsg.prefix));
  }

  /// Handles requests for blocks from peers.
  void handleWantBlock(String peerId, bitswap.Wantlist.Entry entry) {
   final blockId = base64.encode(entry.block);

   // Check if we have the requested block locally
   _datastore.get(blockId).then((block) {
     if (block != null) { 
       print('Sending requested block $blockId to $peerId.'); 
       sendBlock(peerId, block.data); 
     } else if (entry.sendDontHave) { 
       sendDontHave(peerId, entry); 
     } 
   });
}

Future<void> sendBlock(String peerId, Uint8List data) async { 
   final message = bitswap.Message() 
     ..payload.add(bitswap.BlockMsg(
       prefix: Uint8List.fromList(utf8.encode(data.sublist(0, min(data.length, maxPrefixLength)).toString())), 
       data: data,
     ));
   await send(peerId, message); 
}

Future<void> sendWantlist(String peerId, bitswap.Wantlist.Entry entry) async {
   final message = bitswap.Message()
     ..wantlist = bitswap.Wantlist()
     ..wantlist.entries.add(entry);
   await send(peerId, message);
}

void addPeer(LibP2PPeerId peerId) { 
   _peers.add(peerId); 
   print('Peer ${peerId.toBase58()} added to Bitswap network.'); 
}

void removePeer(LibP2PPeerId peerId) { 
   _peers.remove(peerId); 
   print('Peer ${peerId.toBase58()} removed from Bitswap network.'); 
}

// --- Handlers for other message types ---

/// Handles incoming "have" requests from peers.
void handleHave(String peerId, bitswap.Wantlist.Entry entry) {
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
void handleCancel(String peerId, bitswap.Wantlist.Entry entry) {
   final blockId = base64.encode(entry.block); 

   // Log the cancellation
   print('Received cancel request for block $blockId from $peerId.');

   // Remove the block from our wantlist or any pending requests
   _removeFromWantlist(blockId, peerId);
}

/// Removes a block from the wantlist or pending requests.
void _removeFromWantlist(String blockId, String peerId) {
   if (_peers.contains(Peer.fromBase58(peerId))) { // Check if peer exists in local list
     print('Removing block $blockId from wantlist for peer $peerId.');
     // Implement actual removal logic based on your data structures here
   } else {
     print('Peer $peerId not found in local peers list.');
   }
}

// Helper function to send a Bitswap message to a peer
Future<void> send(String peerId, bitswap.Message message) async { 
   try { 
       await _router.sendMessage(peerId, message.writeToBuffer()); 
   } catch (e) { 
       print('Error sending message to $peerId: $e'); 
   } 
}
