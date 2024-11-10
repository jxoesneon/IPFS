import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';

class DHTProtocolHandler {
  static const String PROTOCOL_ID = '/ipfs/kad/1.0.0';
  final P2plibRouter _router;
  final Datastore _storage;

  DHTProtocolHandler(this._router, this._storage) {
    _setupHandlers();
  }

  void _setupHandlers() {
    _router.addMessageHandler(PROTOCOL_ID, _handleDHTMessage);
  }

  Future<void> _handleDHTMessage(LibP2PPacket packet) async {
    final message = DHTMessage.fromBuffer(packet.datagram);
    final response = DHTMessage()..messageId = message.messageId;

    switch (message.type) {
      case DHTMessage_MessageType.PING:
        response..type = DHTMessage_MessageType.PING;
        break;

      case DHTMessage_MessageType.FIND_NODE:
        final closerPeers = await _findClosestPeers(message.key);
        response
          ..type = DHTMessage_MessageType.FIND_NODE
          ..closerPeers.addAll(closerPeers);
        break;

      case DHTMessage_MessageType.FIND_VALUE:
        final value = await _storage.get(utf8.decode(message.key));
        response..type = DHTMessage_MessageType.GET_VALUE;
        if (value != null) {
          response.record = value.data;
        } else {
          final closerPeers = await _findClosestPeers(message.key);
          response.closerPeers.addAll(closerPeers);
        }
        break;

      case DHTMessage_MessageType.PUT_VALUE:
        final block = await Block.fromData(Uint8List.fromList(message.record),
            format: 'raw');
        await _storage.put(utf8.decode(message.key), block);
        response..type = DHTMessage_MessageType.PUT_VALUE;
        break;

      default:
        print('Unhandled message type: ${message.type}');
        return;
    }

    await _router.sendMessage(packet.srcPeerId, response.writeToBuffer());
  }

  Future<List<Peer>> _findClosestPeers(List<int> key,
      {int numPeers = 20}) async {
    // Get the routing table from the router
    final routingTable = _router.getRoutingTable();

    // Find closest peers from the routing table
    final closestPeers = routingTable.getNearestPeers(key, numPeers);

    // Convert to List<Peer>
    return closestPeers
        .map((peer) => Peer(
              peerId: peer.value,
              addresses: [], // Add actual addresses if available
            ))
        .toList();
  }
}
