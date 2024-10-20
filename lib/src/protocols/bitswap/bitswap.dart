import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';
import '/../src/proto/bitswap/message_types.pb.dart' as bitswap;
import 'package:p2plib/p2plib.dart' as p2p;

import 'ledger.dart';
import '../../storage/datastore.dart';
import '../../utils/varint.dart';
import '../../utils/base58.dart';
import '../../core/ipfs_node.dart';

class Bitswap {
  final p2p.RouterL0 _router;
  final BitLedger _ledger;
  final Datastore _datastore;
  final String _nodeId;
  final Set<String> _peers = <String>{};

  Bitswap(this._router, this._ledger, this._datastore, this._nodeId);

  Future<void> start() async {
    _router.onMessage((packet) => _handlePacket(packet));
    await _router.start();
  }

  void _handlePacket(p2p.Packet packet) {
    if (packet.datagram.length > 4 * 1024 * 1024) {
      print('Message exceeds the maximum allowed size.');
      return;
    }

    try {
      // 1. Decode the message length prefix
      final (messageLength, bytesRead) = decodeVarint(packet.datagram);

      // 2. Extract the message bytes
      final messageBytes = packet.datagram.sublist(bytesRead);

      // 3. Deserialize the message using the generated Protobuf code
      final message = bitswap.Message.fromBuffer(messageBytes);
      _processIncomingMessage(packet, message);
    } catch (e) {
      print('Error deserializing message: $e');
    }
  }

  void _processIncomingMessage(p2p.Packet packet, bitswap.Message message) {
    // Extract source peer ID from the p2plib message
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
    _ledger.recordReceived(srcPeerId, blockMsg.prefix);

    // Store the received block in the datastore
    _datastore.put(
      base64.encode(blockMsg.prefix),
      Block(data: blockMsg.data, cid: blockMsg.prefix),
    );
  }

  void _handleBlockRequest(String peerId, bitswap.Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);
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

  void _handleBlockPresence(
      String srcPeerId, bitswap.BlockPresence blockPresence) {
    print(
        'Peer $srcPeerId has status ${blockPresence.type} for CID ${blockPresence.cid}');
  }

  void _handleCancel(bitswap.Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);
    print('Cancelled request for block $blockId.');
    _ledger.removeRequestedBlock(blockId);
  }

  void sendBlock(String peerId, String blockId) {
    if (_peers.contains(peerId)) {
      print('Sending block $blockId to peer $peerId.');
      final blockData = _ledger.getBlockData(blockId);
      _sendBlock(peerId, blockData);
    } else {
      print('Peer $peerId not found in the network.');
    }
  }

  void addPeer(String peerId) {
    _peers.add(peerId);
    print('Peer $peerId added to Bitswap network.');
  }

  void removePeer(String peerId) {
    _peers.remove(peerId);
    print('Peer $peerId removed from Bitswap network.');
  }

  void _sendBlock(String peerId, Uint8List blockData) {
    final message = bitswap.Message()
      ..wantlist = bitswap.Wantlist()
      ..payload.add(bitswap.BlockMsg(data: blockData));

    _send(peerId, message);
  }

  void _sendHave(String peerId, bitswap.Wantlist_Entry entry) {
    final message = bitswap.Message()
      ..wantlist = bitswap.Wantlist(entries: [entry])
      ..blockPresences.add(bitswap.BlockPresence(
          cid: entry.block,
          type: bitswap.BlockPresenceType.BLOCK_PRESENCE_HAVE));

    _send(peerId, message);
  }

  void _sendDontHave(String peerId, bitswap.Wantlist_Entry entry) {
    final message = bitswap.Message()
      ..wantlist = bitswap.Wantlist(entries: [entry])
      ..blockPresences.add(bitswap.BlockPresence(
          cid: entry.block,
          type: bitswap.BlockPresenceType.BLOCK_PRESENCE_DONT_HAVE));

    _send(peerId, message);
  }

  // --- Helper methods for Bitswap message handling ---

  // Method to handle WANT_HAVE messages
  void handleWantHave(String cid, p2p.Peer peer) {
    // Check if the node has the requested CID
    _datastore.has(cid).then((hasBlock) {
      if (hasBlock) {
        // Send a HAVE message back to the requesting peer
        final haveMessage = bitswap.Message()
          ..blockPresences.add(bitswap.BlockPresence(
              cid: base58Decode(cid),
              type: bitswap.BlockPresenceType.BLOCK_PRESENCE_HAVE));
        _send(peer.getId().toBase58String(), haveMessage); // Send using peerId
      }
    });
  }

  // Method to handle WANT_BLOCK messages
  void handleWantBlock(String cid, p2p.Peer peer) {
    // Retrieve the block from the datastore
    _datastore.get(cid).then((block) {
      if (block != null) {
        // Send the block to the requesting peer
        final blockMessage = bitswap.Message()
          ..payload.add(bitswap.BlockMsg(prefix: block.cid, data: block.data));
        _send(peer.getId().toBase58String(), blockMessage); // Send using peerId

        // (Optional) Update Bitswap ledger (if using a credit system)
        _ledger.update(peer.getId().toBase58String(),
            (credit) => credit + block.data.length,
            ifAbsent: () => block.data.length);
      } else {
        // Block not found, handle appropriately (e.g., send DONT_HAVE, ignore)
        print('Block $cid not found');
      }
    });
  }

  // Method to handle BLOCK messages
  void handleBlock(bitswap.BlockMsg blockMsg, p2p.Peer peer) {
    // Store the received block in the datastore
    _datastore.put(base64.encode(blockMsg.prefix),
        Block(data: blockMsg.data, cid: blockMsg.prefix));
    // (Optional) Update Bitswap ledger (if using a credit system)
    _ledger.recordReceived(peer.getId().toBase58String(), blockMsg.prefix);
  }

  // Method to handle HAVE messages
  void handleHave(String cid, p2p.Peer peer) {
    // Update the ledger to indicate that the peer has the block
    _ledger.recordHas(peer.getId().toBase58String(), base58Decode(cid));
  }

  // Method to handle CANCEL messages
  void handleCancel(String cid, p2p.Peer peer) {
    // Update the ledger to remove the request for the block
    _ledger.removeRequestedBlock(cid);
  }

  // Method to handle Bitswap messages from PubSub
  void handlePubsubMessage(dynamic message) {
    // 1. Determine the message type
    final messageType = message['type'] as String?;

    // 2. Handle the message based on its type
    switch (messageType) {
      case 'want_have':
        final List<dynamic> cids = message['cids'] as List<dynamic>?;
        if (cids != null) {
          handleWantHave(cids.cast<String>());
        } else {
          print('Invalid WANT_HAVE message format: missing cids');
        }
        break;

      case 'want_block':
        final List<dynamic> cids = message['cids'] as List<dynamic>?;
        if (cids != null) {
          handleWantBlock(cids.cast<String>());
        } else {
          print('Invalid WANT_BLOCK message format: missing cids');
        }
        break;

      // ... (handle other Bitswap message types)

      default:
        print('Unknown Bitswap message type: $messageType');
    }
  }

  // Helper function to send a Bitswap message to a peer
  void _send(String peerId, bitswap.Message message) async {
    // Changed to accept peerId
    // Encode the message length as a varint
    final messageBytes = message.writeToBuffer();
    final messageLength = messageBytes.lengthInBytes;
    final lengthPrefix = encodeVarint(messageLength);

    // Combine the length prefix and the message bytes
    final data = Uint8List.fromList([...lengthPrefix, ...messageBytes]);

    // Send the message using the router
    await _router.sendDatagram(
      addresses: _router.resolvePeerId(
          peerIdToPeerId(peerId)), // Resolve peer ID to addresses
      datagram: data,
    );
  }
}
