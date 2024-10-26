// lib/src/core/ipfs_node/pubsub_handler.dart

import 'dart:convert';
import '/../src/protocols/pubsub/pubsub_client.dart';
import '../utils/utils.dart'; // Assuming you have a utils file for common functions
import '../data_structures/node_stats.dart'; // Assuming you have a NodeStats class

/// Handles PubSub operations for an IPFS node.
class PubSubHandler {
  final PubSubClient _pubSubClient;

  PubSubHandler(config) : _pubSubClient = PubSubClient(config);

  /// Starts the PubSub client.
  Future<void> start() async {
    try {
      await _pubSubClient.start();
      print('PubSub client started.');
    } catch (e) {
      print('Error starting PubSub client: $e');
    }
  }

  /// Stops the PubSub client.
  Future<void> stop() async {
    try {
      await _pubSubClient.stop();
      print('PubSub client stopped.');
    } catch (e) {
      print('Error stopping PubSub client: $e');
    }
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    try {
      await _pubSubClient.subscribe(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribes from a PubSub topic.
  Future<void> unsubscribe(String topic) async {
    try {
      await _pubSubClient.unsubscribe(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    try {
      await _pubSubClient.publish(topic, message);
      print('Published message to topic: $topic');
    } catch (e) {
      print('Error publishing message to topic $topic: $e');
    }
  }

  /// Handles incoming messages on a subscribed topic.
  void onMessage(String topic, Function(String) handler) {
    try {
      _pubSubClient.onMessage(topic, (message) {
        // Decode the message if necessary
        final decodedMessage = utf8.decode(message);

        // Process the decoded message
        handler(decodedMessage);
        print('Processed message on topic: $topic');
      });
    } catch (e) {
      print('Error setting handler for messages on topic $topic: $e');
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      final cid = await IPFSUtils.resolveDNSLink(domainName);
      if (cid != null) {
        print('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
      } else {
        print('DNSLink for domain $domainName not found.');
        return null;
      }
    } catch (e) {
      print('Error resolving DNSLink for domain $domainName: $e');
      return null;
    }
  }

  /// Gets the node's statistics.
  Future<NodeStats> stats() async {
    try {
      final stats = await _pubSubClient.getNodeStats();
      print('Retrieved node statistics.');
      return stats;
    } catch (e) {
      print('Error retrieving node statistics: $e');
      throw Exception('Failed to retrieve node statistics.');
    }
  }
}
