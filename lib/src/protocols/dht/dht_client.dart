// lib/src/protocols/dht/dht_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '/../src/core/ipfs_node/ipfs_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/utils/base58.dart';
import '../../proto/generated/unixfs/unixfs.pb.dart';
import '../../proto/generated/dht/dht.pb.dart';
import '/../src/proto/bitswap/bitswap.pb.dart';
import '/../src/utils/varint.dart';

/// A DHT client implementation.
class DHTClient {
  /// Creates a new [DHTClient].
  DHTClient(IPFSNode node) : router = node.router.routerL0; // Access through _router

  final IPFSNode node;
  final p2p.RouterL0 router; // Store the RouterL0 instance

  // Routing table to store known peers in the DHT
  final Map<String, p2p.Peer> _routingTable = {}; // Using a Map to store peers by their ID

  /// Starts the DHT client.
  Future<void> start() async {
    // TODO: Implement DHT client startup logic
    // - Initialize the DHT client library
    // - Join the DHT network
    // - Connect to bootstrap nodes from _node.config.bootstrapPeers
    // - ...
  }

  /// Stops the DHT client.
  Future<void> stop() async {
    // TODO: Implement DHT client shutdown logic
    // - Leave the DHT network
    // - Close connections
    // - ...
  }

  /// Finds providers for the given [cid].
  Future<List<p2p.Peer>> findProviders(String cid) async {
    // TODO: Implement DHT provider finding logic using iterative queries
    // - Start with a set of known nodes (e.g., from the routing table)
    // - Send FIND_NODE queries to progressively closer nodes
    // - Collect the provider peer IDs from the responses
    // - Convert the peer IDs to p2p.Peer objects
    // - ...
    throw UnimplementedError();
  }

  /// Puts a value in the DHT.
  Future<void> putValue(String key, String value) async {
    // TODO: Implement DHT put value logic
    // - Encode the key and value
    // - Send a DHT put request
    // - ...
  }

  /// Gets a value from the DHT.
  Future<String?> getValue(String key) async {
    // TODO: Implement DHT get value logic using iterative queries
    // - Start with a set of known nodes
    // - Send GET_VALUE queries to progressively closer nodes
    // - Return the value from the response
    // - ...
    throw UnimplementedError();
  }

  /// Handles DHT messages from PubSub.
  void handlePubsubMessage(dynamic message) {
    // TODO: Implement more comprehensive logic to handle DHT messages from PubSub
    // - Decode the message
    // - Extract the relevant information (e.g., key, value, peer ID)
    // - Update the local DHT state or routing table
    // - Handle different DHT message types (PUT_VALUE, GET_VALUE, FIND_NODE, etc.)
    // - ...
  }

  // Helper function to decode incoming PubSub messages (if necessary)
  dynamic decodeMessage(dynamic message) {
    // ... (same as before)
  }

  // ... (other DHT-related methods)

  /// Adds a provider for the given [cid].
  Future<void> addProvider(String providerId, String cid) async {
    // TODO: Implement DHT add provider logic
    // - Encode the provider ID and CID
    // - Send a DHT add provider request
    // - ...
  }

  /// Gets providers for the given [cid].
  Future<List<String>> getProviders(String cid) async {
    // TODO: Implement DHT get providers logic
    // - Encode the CID
    // - Send a DHT get providers request
    // - Decoding the response and extracting the provider IDs
    // - ...
    throw UnimplementedError();
  }

  /// Finds a node with the given [nodeId].
  Future<p2p.Peer?> findNode(String nodeId) async {
    // TODO: Implement DHT find node logic
    // - Encode the node ID
    // - Sending a DHT find node request
    // - Decoding the response and extracting the node's information
    // - Converting the node's information to a p2p.Peer object
    // - ...
    throw UnimplementedError();
  }

  /// Puts a value in the DHT with the given key.
  Future<void> putValue(String key, Uint8List value) async {
    // 1. Encode the key
    final encodedKey = utf8.encode(key); // Encode the key as UTF-8 bytes

    // 2. Find the closest peers to the key
    final closestPeers = await _findClosestPeers(encodedKey); // You'll need to implement _findClosestPeers

    // 3. Send PUT_VALUE messages to the closest peers
    final putValueMessage = _createPutValueMessage(encodedKey, value); // You'll need to implement _createPutValueMessage
    for (var peer in closestPeers) {
      try {
        await _sendMessage(peer, putValueMessage); // You'll need to implement _sendMessage
      } catch (e) {
        print('Error sending PUT_VALUE message to peer ${peer.id}: $e');
      }
    }

    // 4. (Optional) Store the value locally
    // You might want to store the value locally as well, especially if it's related to the node itself
    // ...
  }

  // --- Helper methods for DHT operations ---

// Finds the closest peers to the given key in the DHT
  Future<List<p2p.Peer>> _findClosestPeers(Uint8List key) async {
    // 1. Initialize the set of closest peers with known nodes (e.g., from the routing table)
    final closestPeers = <p2p.Peer>{}; // Use a Set to avoid duplicates
    // TODO: Add initial peers from the routing table (if implemented)

    // 2. Perform iterative queries
    var queriedPeers = closestPeers.toList(); // Start with the initial peers
    while (queriedPeers.isNotEmpty) {
      final newPeers = <p2p.Peer>{};
      for (var peer in queriedPeers) {
        try {
          // 3. Send a FIND_NODE query to the peer
          final findNodeMessage = _createFindNodeMessage(key); // You'll need to implement _createFindNodeMessage
          final response = await _sendMessage(peer, findNodeMessage); // You'll need to update _sendMessage to return a response

          // 4. Parse the response and extract the closer peers
          final closerPeers = _extractPeersFromFindNodeResponse(response); // You'll need to implement _extractPeersFromFindNodeResponse
          newPeers.addAll(closerPeers);

          // 5. Update the closestPeers set
          closestPeers.addAll(closerPeers);
          // TODO: Keep only the 'k' closest peers (where 'k' is a configurable parameter)
        } catch (e) {
          print('Error sending FIND_NODE message to peer ${peer.id}: $e');
        }
      }
      queriedPeers = newPeers.toList(); // Update the list of peers to query in the next iteration
    }

    // 6. Return the closest peers
    return closestPeers.toList();
  }

  // --- Helper methods for DHT operations ---

  // ... (other helper methods)

  // Creates a FIND_NODE message
  bitswap.Message _createFindNodeMessage(Uint8List key) {
    // TODO: Implement logic to create a FIND_NODE message according to the DHT specification
    // This might involve:
    // - Creating a custom message format or using a predefined one
    // - Including the key in the message
    // - ...
    throw UnimplementedError();
  }

  // Sends a message to a peer and returns the response
  Future<Uint8List> _sendMessage(p2p.Peer peer, bitswap.Message message) async {
    // TODO: Implement logic to send the message to the peer using the router and receive the response
    // This might involve:
    // - Serializing the message
    // - Using the _node._router to send the message
    // - Waiting for and receiving the response message
    // - ...
    throw UnimplementedError();
  }

// Extracts peer information from a FIND_NODE response
  List<p2p.Peer> _extractPeersFromFindNodeResponse(Uint8List response) {
    // 1. Decode the response message
    // This will depend on your DHT implementation and message format
    // For example, if you are using a Kademlia-based DHT, the response might contain a list of NodeInfo objects
    // TODO: Decode the response message according to your DHT implementation
    final decodedResponse = decodeDHTMessage(response); // You'll need to implement decodeDHTMessage

    // 2. Extract the peer IDs and addresses
    final peerInfos = decodedResponse['closerPeers'] as List<dynamic>?; // Assuming the response contains a 'closerPeers' field
    if (peerInfos == null) {
      throw FormatException('Invalid FIND_NODE response format: missing closerPeers');
    }

    // 3. Convert the peer information to p2p.Peer objects
    final peers = <p2p.Peer>[];
    for (var peerInfo in peerInfos) {
      try {
        final peerId = peerIdToPeerId(peerInfo['id'] as String); // Assuming peerInfo has an 'id' field (base58 encoded)
        final addresses = (peerInfo['addresses'] as List<dynamic>?)?.cast<String>() ?? [];
        // TODO: Create p2p.Multiaddr objects from the addresses
        final multiaddresses = addresses.map((addr) => p2p.Multiaddr.fromAddress(addr)).toList(); // Placeholder - you'll need to implement Multiaddr.fromAddress
        peers.add(p2p.Peer(id: peerId, address: multiaddresses.first)); // Assuming you want to use the first address
      } catch (e) {
        print('Error creating peer from peerInfo: $e');
      }
    }

    // 4. Return the list of peers
    return peers;
  }

  // --- Helper methods for DHT operations ---

  // ... (other helper methods)

  // Decodes a DHT message
  dynamic decodeDHTMessage(Uint8List message) {
    // TODO: Implement logic to decode the DHT message according to your DHT implementation and message format
    // This might involve deserializing a Protobuf message, parsing a JSON string, etc.
    // ...
    throw UnimplementedError();
  }
// Creates a PUT_VALUE message
  p2p.Message _createPutValueMessage(Uint8List key, Uint8List value) {
    // 1. Create a PutValueRecord
    final record = PutValueRecord()
      ..key = key
      ..value = value; // Assuming PutValueRecord is defined in your DHT library

    // 2. Serialize the record
    final recordBytes = record.writeToBuffer(); // Assuming your DHT library uses Protobuf

    // 3. Create the p2plib Message
    final message = p2p.Message(
      header: p2p.PacketHeader(
        id: Random().nextInt(1 << 32), // Generate a message ID
        issuedAt: DateTime.now().millisecondsSinceEpoch,
        messageType: p2p.PacketType.regular, // Or the appropriate PacketType for DHT PUT_VALUE
      ),
      srcPeerId: p2p.PeerId.fromBase58String(_node.peerID),
      dstPeerId: p2p.PeerId(value: key), // The key is usually the peer ID of the recipient
      payload: recordBytes,
    );

    return message;
  }

// Sends a message to a peer
  Future<void> _sendMessage(p2p.Peer peer, bitswap.Message message) async {
    // 1. Serialize the message using Protobuf
    final messageBytes = message.writeToBuffer();

    // 2. Encode the message length as a varint
    final messageLength = messageBytes.lengthInBytes;
    final lengthPrefix = encodeVarint(messageLength);

    // 3. Combine the length prefix and the message bytes
    final data = Uint8List.fromList([...lengthPrefix, ...messageBytes]);

    // 4. Send the message using the router
    try {
      await _node._router.sendMessage(peer, data);
    } catch (e) {
      // Handle potential errors during message sending
      print('Error sending message to peer ${peer.id}: $e');
      // Rethrow to be handled by the calling function
      rethrow; 
    }
  }
}