import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/transport/p2plib_router.dart';

/// Kademlia DHT protocol message handler.
///
/// Handles PING, FIND_NODE, GET_VALUE, and PUT_VALUE messages
/// according to the Kademlia protocol specification.
class DHTProtocolHandler {

  /// Creates a handler with [_router] and [_storage].
  DHTProtocolHandler(this._router, this._storage) {
    _setupHandlers();
  }
  /// Kademlia protocol ID.
  static const String PROTOCOL_ID = '/ipfs/kad/1.0.0';

  final P2plibRouter _router;
  final Datastore _storage;

  void _setupHandlers() {
    _router.registerProtocolHandler(PROTOCOL_ID, _handleDHTMessage);
  }

  Future<void> _handleDHTMessage(LibP2PPacket packet) async {
    final message = kad.Message.fromBuffer(packet.datagram);
    final response = kad.Message();

    switch (message.type) {
      case kad.Message_MessageType.PING:
        response.type = kad.Message_MessageType.PING;
        break;

      case kad.Message_MessageType.FIND_NODE:
        final closerPeers = await _findClosestPeers(message.key);
        response
          ..type = kad.Message_MessageType.FIND_NODE
          ..closerPeers.addAll(closerPeers);
        break;

      case kad.Message_MessageType.GET_VALUE:
        final keyStr = utf8.decode(message.key);
        final storageKey = Key('/dht/values/$keyStr');
        final value = await _storage.get(storageKey);
        response.type = kad.Message_MessageType.GET_VALUE;
        if (value != null) {
          response.record = (dht_pb.Record()..value = value);
        } else {
          final closerPeers = await _findClosestPeers(message.key);
          response.closerPeers.addAll(closerPeers);
        }
        break;

      case kad.Message_MessageType.PUT_VALUE:
        if (message.hasRecord()) {
          final keyStr = utf8.decode(message.key);
          final storageKey = Key('/dht/values/$keyStr');
          await _storage.put(
            storageKey,
            Uint8List.fromList(message.record.value),
          );
        }
        response.type = kad.Message_MessageType.PUT_VALUE;
        break;

      default:
        // print('Unhandled message type: ${message.type}');
        return;
    }

    await _router.sendMessage(packet.srcPeerId, response.writeToBuffer());
  }

  Future<List<kad.Peer>> _findClosestPeers(
    List<int> key, {
    int numPeers = 20,
  }) async {
    // Get the routing table from the router
    final routingTable = _router.getRoutingTable();

    // Find closest peers from the routing table
    final closestPeers = routingTable.getNearestPeers(key, numPeers);

    // Convert to List<kad.Peer>
    return closestPeers
        .map(
          (peer) => kad.Peer()..id = peer.value,
          //..addrs = [] // Add actual addresses if available
        )
        .toList();
  }
}
