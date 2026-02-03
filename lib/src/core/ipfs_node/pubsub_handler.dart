// src/core/ipfs_node/pubsub_handler.dart
import 'dart:async';
import 'dart:convert';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_interface.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';

import '../data_structures/node_stats.dart';

/// Handles PubSub operations for an IPFS node.
class PubSubHandler implements IPubSub {
  /// Constructs a [PubSubHandler] with the provided router, peer ID, and network events.
  PubSubHandler(RouterInterface router, String peerId, this._networkEvents)
    : _pubSubClient = PubSubClient(router, peerId) {
    // Register the pubsub protocol immediately upon construction
    router.registerProtocol('pubsub');
  }
  final PubSubClient _pubSubClient;
  final IpfsNodeNetworkEvents _networkEvents; // Reference to network events
  final Map<String, Set<void Function(String)>> _subscriptions = {};
  final StreamController<PubSubMessage> _messageController =
      StreamController<PubSubMessage>.broadcast();
  int _messageCount = 0;

  /// Stream of incoming PubSub messages.
  Stream<PubSubMessage> get messages => _messageController.stream;

  /// Starts the PubSub client and listens for incoming messages.
  Future<void> start() async {
    try {
      await _pubSubClient.start();
      // print('PubSub client started.');

      // Listen for various network events
      _networkEvents.networkEvents.listen((event) {
        if (event.hasPubsubMessageReceived()) {
          _handlePubsubMessage(event.pubsubMessageReceived);
        }
        // Add more event handlers as needed
      });
    } catch (e) {
      // print('Error starting PubSub client: $e');
    }
  }

  /// Stops the PubSub client.
  Future<void> stop() async {
    try {
      await _pubSubClient.stop();
      await _messageController.close();
      // print('PubSub client stopped.');
    } catch (e) {
      // print('Error stopping PubSub client: $e');
    }
  }

  /// Subscribes to a PubSub topic.
  @override
  Future<void> subscribe(String topic) async {
    try {
      await _pubSubClient.subscribe(topic);
      _subscriptions[topic] = <void Function(String)>{};
      // print('Subscribed to topic: $topic');
    } catch (e) {
      // print('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribes from a PubSub topic.
  @override
  Future<void> unsubscribe(String topic) async {
    try {
      await _pubSubClient.unsubscribe(topic);
      _subscriptions.remove(topic);
      // print('Unsubscribed from topic: $topic');
    } catch (e) {
      // print('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Publishes a message to a PubSub topic.
  @override
  Future<void> publish(String topic, String message) async {
    try {
      await _pubSubClient.publish(topic, message);
      _messageCount++;
      // print('Published message to topic: $topic');
    } catch (e) {
      // print('Error publishing message to topic $topic: $e');
    }
  }

  /// Handles incoming messages on a subscribed topic.
  @override
  void onMessage(String topic, void Function(String) handler) {
    try {
      _pubSubClient.onMessage(topic, handler);
    } catch (e) {
      // print('Error setting handler for messages on topic $topic: $e');
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      final cid = await DNSLinkResolver.resolve(
        domainName,
      ); // Assuming you have a DNSLinkResolver utility
      if (cid != null) {
        // print('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
      } else {
        throw Exception('DNSLink for domain $domainName not found.');
      }
    } catch (e) {
      // print('Error resolving DNSLink for domain $domainName: $e');
      return null;
    }
  }

  /// Gets the node's statistics.
  Future<NodeStats> stats() async {
    try {
      final stats = await _pubSubClient.getNodeStats();
      // print('Retrieved node statistics.');
      return stats;
    } catch (e) {
      // print('Error retrieving node statistics: $e');
      throw Exception('Failed to retrieve node statistics.');
    }
  }

  /// Handles a received Pubsub message event.
  void _handlePubsubMessage(PubsubMessageReceivedEvent event) {
    try {
      final message = utf8.decode(event.messageContent);
      // print('Received message on topic ${event.topic}: $message');

      // Further processing of the message can be done here
      // For example, dispatching it to specific handlers based on the topic

      _messageController.add(
        PubSubMessage(
          topic: event.topic,
          sender: event.peerId,
          content: message,
        ),
      );
    } catch (e) {
      // SEC-ZDAY-002: malformed UTF8 should not crash the listener
    }
  }

  /// Returns the current status of the PubSub handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'subscribed_topics': _subscriptions.keys.toList(),
      'total_subscribers': _subscriptions.length,
      'messages_published': _messageCount,
    };
  }
}
