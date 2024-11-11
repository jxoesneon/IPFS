// lib/src/protocols/pubsub/pubsub_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// For encoding utilities
import '../../core/data_structures/node_stats.dart';
import '/../src/transport/p2plib_router.dart'; // Import your router class
import 'package:http/http.dart' as http;
import 'package:p2plib/p2plib.dart' as p2p;
import '../../utils/base58.dart';

/// Handles PubSub operations for an IPFS node.
class PubSubClient {
  final P2plibRouter _router; // Router for sending and receiving messages
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final p2p.PeerId _peerId;

  PubSubClient(this._router, String peerIdStr)
      : _peerId = p2p.PeerId(value: Base58().base58Decode(peerIdStr));

  /// Starts the PubSub client.
  Future<void> start() async {
    _router.addMessageHandler('pubsub', (packet) {
      if (packet.datagram.isNotEmpty) {
        try {
          final decodedJson = jsonDecode(utf8.decode(packet.datagram));

          // Skip messages from self
          if (decodedJson['sender'] == Base58().encode(_peerId.value)) {
            return;
          }

          // Validate sender is a known peer
          final senderPeerId =
              p2p.PeerId(value: Base58().base58Decode(decodedJson['sender']));

          // Only process messages from valid peers
          if (_router.isConnectedPeer(senderPeerId)) {
            _messageController.add(decodedJson['content']);
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      }
    });

    _router.registerProtocol('pubsub');
    print(
        'PubSub client started with peer ID: ${Base58().encode(_peerId.value)}');
  }

  /// Stops the PubSub client.
  Future<void> stop() async {
    await _messageController.close();
    print('PubSub client stopped.');
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    try {
      final subscribeData = {
        'action': 'subscribe',
        'topic': topic,
        'subscriberId': Base58().encode(_peerId.value)
      };
      final peerIdObj = p2p.PeerId(value: Base58().base58Decode(topic));
      await _router.sendMessage(peerIdObj,
          Uint8List.fromList(utf8.encode(jsonEncode(subscribeData))));
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribes from a PubSub topic.
  Future<void> unsubscribe(String topic) async {
    try {
      // Convert string to PeerId object
      final peerIdObj = p2p.PeerId(value: Base58().base58Decode(topic));
      await _router.sendMessage(peerIdObj, encodeUnsubscribeRequest(topic));
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    try {
      // Convert string to PeerId object
      final peerIdObj = p2p.PeerId(value: Base58().base58Decode(topic));
      final encodedMessage = encodePublishRequest(topic, message);
      await _router.sendMessage(peerIdObj, encodedMessage);
      print('Published message to topic: $topic');
    } catch (e) {
      print('Error publishing message to topic $topic: $e');
    }
  }

  /// Handles incoming messages on a subscribed topic.
  Stream<String> get onMessage => _messageController.stream;

  /// Encodes a subscribe request for the given topic.
  Uint8List encodeSubscribeRequest(String topic) {
    // Implement encoding logic for subscribe request
    return Uint8List.fromList(utf8.encode('subscribe:$topic'));
  }

  /// Encodes an unsubscribe request for the given topic.
  Uint8List encodeUnsubscribeRequest(String topic) {
    // Implement encoding logic for unsubscribe request
    return Uint8List.fromList(utf8.encode('unsubscribe:$topic'));
  }

  /// Encodes a publish request for the given topic and message.
  Uint8List encodePublishRequest(String topic, String message) {
    // Include sender's peerId in the message format
    final messageWithSender = {
      'sender': Base58().encode(_peerId.value),
      'topic': topic,
      'content': message
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(messageWithSender)));
  }

  /// Decodes incoming messages from bytes to string.
  String decodeMessage(Uint8List messageBytes) {
    return utf8.decode(messageBytes);
  }

  /// Retrieves node statistics.
  Future<NodeStats> getNodeStats() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5001/stats'));
      if (response.statusCode == 200) {
        // Assuming response body contains JSON data for NodeStats
        return NodeStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load node stats');
      }
    } catch (e) {
      print('Error retrieving node stats: $e');
      throw e; // Rethrow the error for handling upstream
    }
  }
}
