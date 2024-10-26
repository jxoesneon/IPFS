// lib/src/protocols/bitswap/bitswap.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';
import '/../src/proto/bitswap/message_types.pb.dart' as bitswap;
import 'package:p2plib/p2plib.dart' as p2p;

import 'ledger.dart';
import '../../storage/datastore.dart';
import '../../utils/varint.dart';
import '../../utils/base58.dart';
import '../../core/ipfs_node/ipfs_node.dart';

class Bitswap {
  final p2p.RouterL0 _router;
  final BitLedger _ledger;
  final Datastore _datastore;
  final String _nodeId;
  final Set<String> _peers = <String>{};
  final dynamic config;  

  Bitswap(this._router, this._ledger, this._datastore, this._nodeId, [this.config]);

  Future<void> start() async {
    _router.onMessage((packet) => _handlePacket(packet));
    await _router.start();
    print('Bitswap started.');
  }

  Future<void> stop() async {
    await _router.stop();
    print('Bitswap stopped.');
  }

  Future<Block?> wantBlock(String cid) async {
    // Logic to request a block from the network
    // This could involve sending a message to peers asking for the block
    print('Requesting block with CID: $cid');
    
    // Here you would implement the logic to send a request for the block
    // For now, we'll just return null as a placeholder
    return null; 
  }

  void provide(String cid) {
    // Logic to announce that a block is available
    print('Providing block with CID: $cid');
    
    // Here you would implement the logic to notify peers about the available block
  }

  Uint8List getBlockData(String cid) {
    // Logic to retrieve block data from the ledger
    return _ledger.getBlockData(cid);
  }

  void _handlePacket(p2p.Packet packet) {
    if (packet.datagram.length > 4 * 1024 * 1024) {
      print('Message exceeds the maximum allowed size.');
      return;
    }

    try {
      // Decode the message length prefix
      final (messageLength, bytesRead) = decodeVarint(packet.datagram);

      // Extract the message bytes
      final messageBytes = packet.datagram.sublist(bytesRead);

      // Deserialize the message using Protobuf
      final message = bitswap.Message.fromBuffer(messageBytes);
      _processIncomingMessage(packet, message);
    } catch (e) {
      print('Error deserializing message: $e');
    }
  }

  void _processIncomingMessage(p2p.Packet packet, bitswap.Message message) {
    final srcPeerId = packet.getSrcPeerId().toBase58String();

    for (var entry in message.wantlist.entries) {
      if (entry.cancel) {
        _handleCancel(entry);
      } else {
        switch (entry.wantType) {
          case bitswap.WantType.WANT_TYPE_BLOCK:
            _handleBlockRequest(srcPeerId, entry);
            break;
          case bitswap.WantType.WANT_TYPE_HAVE:
            _handleHaveRequest(srcPeerId, entry);
            break;
        }
      }
    }

    for (var blockMsg in message.payload) {
      _handleReceivedBlock(srcPeerId, blockMsg);
    }

    for (var blockPresence in message.blockPresences) {
      _handleBlockPresence(srcPeerId, blockPresence);
    }
  }

  void _handleReceivedBlock(String srcPeerId, bitswap.BlockMsg blockMsg) {
    print('Received block with CID prefix ${blockMsg.prefix} from $srcPeerId.');
    
    // Store received block in datastore
    _datastore.put(
      base64.encode(blockMsg.prefix),
      Block(data: blockMsg.data, cid: blockMsg.prefix),
    );
    
    // Update ledger with received information
    _ledger.recordReceived(srcPeerId, blockMsg.prefix);
  }

  void _handleBlockRequest(String peerId, bitswap.Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);
    
    // Check if we have the requested block locally
    _datastore.get(blockId).then((block) {
      if (block != null) {
        print('Sending requested block $blockId to $peerId.');
        _sendBlock(peerId, block.data);
      } else if (entry.sendDontHave) {
        _sendDontHave(peerId, entry);
      }
    });
  }

  void _handleHaveRequest(String peerId, bitswap.Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);
    
   if (_ledger.hasBlock(blockId)) { 
     print('Responding to have request for block $blockId from $peerId.'); 
     _sendHave(peerId, entry); 
   } else if (entry.sendDontHave) { 
     _sendDontHave(peerId, entry); 
   } 
}

void sendBlock(String peerId, Uint8List data) { 
   final message = bitswap.Message() 
     ..wantlist = bitswap.Wantlist() 
     ..payload.add(bitswap.BlockMsg(data: data)); 

   // Send using router's send method 
   await send(peerId, message); 
}

void addPeer(String peerId) { 
   _peers.add(peerId); 
   print('Peer $peerId added to Bitswap network.'); 
}

void removePeer(String peerId) { 
   _peers.remove(peerId); 
   print('Peer $peerId removed from Bitswap network.'); 
}

void handleWantHave(String cid, p2p.Peer peer) { /* Implementation */ }
void handleWantBlock(String cid, p2p.Peer peer) { /* Implementation */ }
void handleBlock(bitswap.BlockMsg blockMsg, p2p.Peer peer) { /* Implementation */ }
void handleHave(String cid, p2p.Peer peer) { /* Implementation */ }
void handleCancel(String cid, p2p.Peer peer) { /* Implementation */ }

// Helper function to send a Bitswap message to a peer
void send(String peerId, bitswap.Message message) async { /* Implementation */ }
}
