// src/protocols/bitswap/bitswap.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap_pb;
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:dart_ipfs/src/protocols/bitswap/message.dart'
    as bitswap_message;
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

import 'ledger.dart';

/// Bitswap 1.2.0 block exchange protocol implementation.
///
/// Bitswap is IPFS's data trading module that manages requesting and
/// receiving blocks from peers. It implements a credit-based system
/// using a [BitLedger] to track exchanges with each peer.
///
/// **Key Features:**
/// - Wantlist management for requesting blocks
/// - Block presence notifications (HAVE/DONT_HAVE)
/// - Credit-based peer prioritization via ledger
///
/// Example:
/// ```dart
/// final bitswap = Bitswap(router, ledger, datastore);
/// await bitswap.start();
///
/// // Request a block from the network
/// final block = await bitswap.wantBlock(cidString);
///
/// // Provide a block to other peers
/// bitswap.provide(cidString);
/// ```
///
/// See also:
/// - [BitLedger] for peer credit tracking
/// - [BitswapHandler] for higher-level integration
/// - [IPFS Bitswap Spec](https://specs.ipfs.tech/bitswap-protocol/)
class Bitswap {
  /// Creates a Bitswap instance with the given dependencies.
  Bitswap(this._router, this._ledger, this._datastore, [this.config]);
  final RouterInterface _router;
  final BitLedger _ledger;
  final Datastore _datastore;
  final Set<LibP2PPeerId> _peers = {};

  /// Optional configuration for the Bitswap protocol.
  final dynamic config;

  final _logger = Logger('BitSwap');

  /// Maximum length for block prefixes in messages.
  static const int maxPrefixLength = 64;

  /// Starts the Bitswap protocol.
  Future<void> start() async {
    _router.registerProtocolHandler('/ipfs/bitswap/1.2.0', (
      NetworkPacket packet,
    ) {
      _handlePacket(packet);
    });
    await _router.start();
    // print('Bitswap started.');
  }

  /// Stops the Bitswap protocol.
  Future<void> stop() async {
    await _router.stop();
    // print('Bitswap stopped.');
  }

  /// Requests a block from the network.
  Future<Block?> wantBlock(String cid) async {
    // print('Requesting block with CID: $cid');

    // Create a Wantlist entry for the requested block
    final wantlistEntry = proto.Message_Wantlist_Entry()
      ..block =
          Uint8List.fromList(
            utf8.encode(cid),
          ) // Entry uses 'block' for cid bytes? Proto says 'block' field 1.
      ..priority = 1
      ..cancel = false
      ..wantType = proto.Message_Wantlist_WantType.Block
      ..sendDontHave = true;

    // Send the wantlist to peers
    for (var peer in _peers) {
      await sendWantlist(peer, wantlistEntry);
    }

    // Placeholder for actual block retrieval logic
    return null;
  }

  /// Provides a block to the network.
  void provide(String cid) {
    // print('Providing block with CID: $cid');

    // Notify peers about the available block
    for (var peer in _peers) {
      _sendHave(peer, cid);
    }
  }

  /// Retrieves block data from the ledger.
  Uint8List getBlockData(String cid) {
    return _ledger.getBlockData(cid);
  }

  /// Handles incoming packets from peers.
  void _handlePacket(NetworkPacket packet) async {
    try {
      final message = await bitswap_message.Message.fromBytes(packet.datagram);
      final peerId = packet.srcPeerId;

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
          final protoEntry = bitswap_pb.Message_Wantlist_Entry()
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
            // print('Peer $peerId has block ${presence.cid}');
          } else {
            // print('Peer $peerId does not have block ${presence.cid}');
          }
        }
      }
    } catch (e) {
      // print('Error handling BitSwap packet: $e');
    }
  }

  /// Handles received blocks from peers.
  Future<void> _handleReceivedBlock(String srcPeerId, Block block) async {
    final blockId = block.cid.toString();

    // Store received block in datastore using Key
    final key = Key('/blocks/$blockId');
    await _datastore.put(key, block.data);

    // Store block data in ledger and update received bytes
    _ledger.storeBlockData(blockId, block.data);
    _ledger.addReceivedBytes(block.data.length);
  }

  /// Handles requests for blocks from peers.
  Future<void> handleWantBlock(
    String peerId,
    bitswap_pb.Message_Wantlist_Entry entry,
  ) async {
    final blockId = base64.encode(entry.block);

    // Check if we have the requested block locally
    final key = Key('/blocks/$blockId');
    final data = await _datastore.get(key);
    if (data != null) {
      await sendBlock(peerId, data);
    } else if (entry.sendDontHave) {
      await sendDontHave(peerId, entry);
    }
  }

  /// Sends a block to a peer.
  Future<void> sendBlock(String peerId, Uint8List data) async {
    final message = proto.Message()..blocks.add(data);
    await send(peerId, message);
  }

  /// Sends a wantlist to a peer.
  Future<void> sendWantlist(
    String peerId,
    proto.Message_Wantlist_Entry entry,
  ) async {
    final wantlist = proto.Message_Wantlist();
    wantlist.entries.add(entry);

    final message = proto.Message()..wantlist = wantlist;

    await send(peerId, message);
  }

  /// Adds a peer to the Bitswap network.
  void addPeer(LibP2PPeerId peerId) {
    _peers.add(peerId);
    _logger.debug('Peer $peerId added to Bitswap network');
    _logger.verbose('Current peer count: ${_peers.length}');
  }

  /// Removes a peer from the Bitswap network.
  void removePeer(LibP2PPeerId peerId) {
    _peers.remove(peerId);
    // print(
    //   'Peer $peerId removed from Bitswap network.',
    // );
  }

  // --- Handlers for other message types ---

  /// Handles incoming "have" requests from peers.
  void handleHave(String peerId, proto.Message_Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);
    _logger.verbose('Received have request for block $blockId from $peerId');

    if (_ledger.hasBlock(blockId)) {
      _logger.debug(
        'Responding to have request for block $blockId from $peerId',
      );
      sendHave(peerId, entry);
    } else if (entry.sendDontHave) {
      _logger.debug('Sending dont-have response for block $blockId to $peerId');
      sendDontHave(peerId, entry);
    }
  }

  /// Handles cancel requests from peers.
  void handleCancel(String peerId, proto.Message_Wantlist_Entry entry) {
    final blockId = base64.encode(entry.block);

    // Log the cancellation
    // print('Received cancel request for block $blockId from $peerId.');

    // Remove the block from our wantlist or any pending requests
    _removeFromWantlist(blockId, peerId);
  }

  /// Removes a block from the wantlist or pending requests.
  void _removeFromWantlist(String blockId, String peerId) {
    try {
      final peer = Peer.fromId(peerId);
      if (_peers.contains(peer.id.toString())) {
        // print('Removing block $blockId from wantlist for peer $peerId.');
        // Implement actual removal logic based on your data structures here
      } else {
        // print('Peer $peerId not found in local peers list.');
      }
    } catch (e) {
      // print('Error creating peer from ID: $e');
    }
  }

  /// Sends a Bitswap message to a peer.
  Future<void> send(String peerId, proto.Message message) async {
    try {
      await _router.sendMessage(peerId, message.writeToBuffer());
    } catch (e) {
      // print('Error sending message to $peerId: $e');
    }
  }

  /// Sends a HAVE message to a peer for a specific block
  Future<void> _sendHave(String peerId, String cid) async {
    final message = proto.Message()
      ..blockPresences.add(
        proto.Message_BlockPresence()
          ..cid = Uint8List.fromList(utf8.encode(cid))
          ..type = proto.Message_BlockPresence_Type.Have,
      );

    await send(peerId, message);
  }

  /// Sends a DONT_HAVE message to a peer for a specific wantlist entry
  Future<void> sendDontHave(
    String peerId,
    proto.Message_Wantlist_Entry entry,
  ) async {
    final message = proto.Message()
      ..blockPresences.add(
        proto.Message_BlockPresence()
          ..cid = entry.block
          ..type = proto.Message_BlockPresence_Type.DontHave,
      );

    await send(peerId, message);
  }

  /// Sends a HAVE message to a peer for a specific wantlist entry
  Future<void> sendHave(
    String peerId,
    proto.Message_Wantlist_Entry entry,
  ) async {
    final message = proto.Message()
      ..blockPresences.add(
        proto.Message_BlockPresence()
          ..cid = entry.block
          ..type = proto.Message_BlockPresence_Type.Have,
      );

    await send(peerId, message);
  }

  // Add this helper method to convert between WantType enums
  proto.Message_Wantlist_WantType _convertToProtoWantType(
    bitswap_message.WantType type,
  ) {
    switch (type) {
      case bitswap_message.WantType.block:
        return proto.Message_Wantlist_WantType.Block;
      case bitswap_message.WantType.have:
        return proto.Message_Wantlist_WantType.Have;
    }
  }
}
