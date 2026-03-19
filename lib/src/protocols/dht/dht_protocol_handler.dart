import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/transport/router_interface.dart';

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
  static const String protocolId = '/ipfs/kad/1.0.0';

  final RouterInterface _router;
  final Datastore _storage;

  void _setupHandlers() {
    _router.registerProtocolHandler(protocolId, _handleDHTMessage);
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
    // TODO: The routing table is P2plibRouter-specific. For now, return connected peers.
    // In a complete migration, this would be exposed via RouterInterface or
    // a separate DHT routing abstraction.

    // Get connected peers from router interface
    final connectedPeers = _router.connectedPeers.take(numPeers);

    // Convert to List<kad.Peer>
    return connectedPeers
        .map((peerId) => kad.Peer()..id = utf8.encode(peerId))
        .toList();
  }
}
