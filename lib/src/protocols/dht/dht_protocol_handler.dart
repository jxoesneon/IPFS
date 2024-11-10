import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/messages/message_factory.dart';
import 'package:dart_ipfs/src/proto/generated/dht_messages.pb.dart';

class DHTProtocolHandler {
  static const String PROTOCOL_ID = '/ipfs/kad/1.0.0';
  final P2plibRouter _router;

  DHTProtocolHandler(this._router) {
    _setupHandlers();
  }

  void _setupHandlers() {
    _router.addMessageHandler(PROTOCOL_ID, _handleDHTMessage);
  }

  Future<void> _handleDHTMessage(LibP2PPacket packet) async {
    final message = DHTMessage.fromBuffer(packet.datagram);

    switch (message.type) {
      case DHTMessage_MessageType.FIND_NODE:
        await _handleFindNode(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.PUT_VALUE:
        await _handlePutValue(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.GET_VALUE:
        await _handleGetValue(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.ADD_PROVIDER:
        await _handleAddProvider(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.GET_PROVIDERS:
        await _handleGetProviders(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.PING:
        await _handlePing(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.FIND_VALUE:
        await _handleFindValue(message, packet.srcPeerId);
        break;
      case DHTMessage_MessageType.UNKNOWN:
        print('Received unknown message type from ${packet.srcPeerId}');
        break;
    }
  }

  Future<void> _handleFindNode(DHTMessage message, LibP2PPeerId sender) async {
    final request = FindNodeRequest.fromBuffer(message.record);
    final closerPeers = await _findClosestPeers(request.key);

    final response = FindNodeResponse()
      ..closerPeers.addAll(closerPeers.map((peer) => Peer()
        ..peerId = peer.id.bytes
        ..addresses.addAll(peer.addresses.map((addr) => addr.toString()))));

    final responseMessage = DHTMessage()
      ..messageId = message.messageId
      ..type = DHTMessage_MessageType.FIND_NODE
      ..record = response.writeToBuffer();

    await _router.sendMessage(sender, responseMessage.writeToBuffer());
  }

  Future<void> _handlePutValue(DHTMessage message, LibP2PPeerId sender) async {
    final request = PutValueRequest.fromBuffer(message.record);
    
    // Store the key-value pair in local storage
    // Note: You'll need to implement the actual storage logic
    try {
      // Create response message
      final response = PutValueResponse()
        ..success = true;

      final responseMessage = DHTMessage()
        ..messageId = message.messageId
        ..type = DHTMessage_MessageType.PUT_VALUE
        ..record = response.writeToBuffer();

      // Send response back to the requesting peer
      await _router.sendMessage(sender, responseMessage.writeToBuffer());
    } catch (e) {
      print('Error handling PUT_VALUE request: $e');
      // Send failure response
      final response = PutValueResponse()
        ..success = false;

      final responseMessage = DHTMessage()
        ..messageId = message.messageId
        ..type = DHTMessage_MessageType.PUT_VALUE
        ..record = response.writeToBuffer();

      await _router.sendMessage(sender, responseMessage.writeToBuffer());
    }
  }

  Future<List<LibP2PPeerId>> _findClosestPeers(List<int> key, {int numPeers = 20}) async {
    // Get the routing table from the router
    final routingTable = _router.getRoutingTable();
    
    // Find closest peers from the routing table
    final closestPeers = routingTable.getNearestPeers(key, numPeers);
    
    // Convert to List<LibP2PPeerId>
    return closestPeers.map((peer) => LibP2PPeerId(peer.id.bytes)).toList();
  }

  Future<void> _handleGetValue(DHTMessage message, LibP2PPeerId sender) async {
    final request = GetValueRequest.fromBuffer(message.record);
    // TODO: Implement value retrieval from local storage
    final value = await _getValue(request.key);
    
    final response = GetValueResponse()
      ..value = value ?? Uint8List(0)
      ..closerPeers.addAll(value == null 
        ? await _findClosestPeers(request.key) 
        : []);

    final responseMessage = DHTMessage()
      ..messageId = message.messageId
      ..type = DHTMessage_MessageType.GET_VALUE
      ..record = response.writeToBuffer();

    await _router.sendMessage(sender, responseMessage.writeToBuffer());
  }

  Future<void> _handleAddProvider(DHTMessage message, LibP2PPeerId sender) async {
    // Implementation similar to _handlePutValue but for provider records
    // This would store provider information in the local DHT store
  }

  Future<void> _handleGetProviders(DHTMessage message, LibP2PPeerId sender) async {
    // Implementation to return list of providers for a given key
    // Similar to _handleFindNode but returns provider information
  }

  Future<void> _handlePing(DHTMessage message, LibP2PPeerId sender) async {
    // Simple ping response
    final responseMessage = DHTMessage()
      ..messageId = message.messageId
      ..type = DHTMessage_MessageType.PING;
    
    await _router.sendMessage(sender, responseMessage.writeToBuffer());
  }

  Future<void> _handleFindValue(DHTMessage message, LibP2PPeerId sender) async {
    // Similar to _handleGetValue but specifically for DHT key-value lookups
    // This would typically be used for IPNS records and other DHT-stored values
  }
}
