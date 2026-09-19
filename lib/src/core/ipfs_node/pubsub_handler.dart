// src/core/ipfs_node/pubsub_handler.dart
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';
import '../../protocols/pubsub/pubsub_client.dart';
import '../../protocols/pubsub/pubsub_interface.dart';
import '../../protocols/pubsub/pubsub_message.dart';
import '../../transport/router_interface.dart';
import '../../utils/dnslink_resolver.dart';
import '../../utils/logger.dart';
import '../crypto/peer_key_registry.dart';
import '../data_structures/node_stats.dart';
import '../interfaces/i_lifecycle.dart';
import 'ipfs_node_network_events.dart';

/// Handles PubSub operations for an IPFS node.
class PubSubHandler implements IPubSub, ILifecycle {
  /// Constructs a [PubSubHandler] with the provided router, peer ID, and network events.
  PubSubHandler(
    RouterInterface router,
    String peerId,
    this._networkEvents, {
    PubSubClient? pubSubClient,
    SimpleKeyPair? keyPair,
    PeerKeyRegistry? keyRegistry,
    bool strictAuthentication = true,
  }) : _pubSubClient =
           pubSubClient ??
           PubSubClient(
             router,
             peerId,
             keyPair: keyPair,
             keyRegistry: keyRegistry,
             strictAuthentication: strictAuthentication,
           ) {
    // Register the pubsub protocol immediately upon construction
    router.registerProtocol('pubsub');
  }
  final PubSubClient _pubSubClient;
  final IpfsNodeNetworkEvents _networkEvents; // Reference to network events
  final Map<String, Set<void Function(String)>> _subscriptions = {};
  final StreamController<PubSubMessage> _messageController =
      StreamController<PubSubMessage>.broadcast();
  final Logger _logger = Logger('PubSubHandler');
  StreamSubscription<PubSubMessage>? _messageBridge;
  StreamSubscription<NetworkEvent>? _networkEventSub;
  int _messageCount = 0;

  /// Stream of incoming PubSub messages.
  Stream<PubSubMessage> get messages => _messageController.stream;

  /// Returns the topics this node is currently subscribed to.
  @override
  List<String> get subscribedTopics => _pubSubClient.subscribedTopics;

  /// Returns the peers known to be subscribed to [topic].
  @override
  Set<String> peersForTopic(String topic) => _pubSubClient.peersForTopic(topic);

  bool _started = false;

  /// Starts the PubSub client and listens for incoming messages.
  @override
  Future<void> start() async {
    if (_started) return;
    try {
      await _pubSubClient.start();
    } catch (e, stackTrace) {
      _logger.error('Error starting PubSub client', e, stackTrace);
      rethrow;
    }
    _started = true;

    // Bridge inbound client messages into the public [messages] stream.
    // Without this, publish works but subscribers can never observe a
    // message through the handler.
    _messageBridge = _pubSubClient.messagesStream.listen(
      _messageController.add,
      onError: _messageController.addError,
    );

    // Listen for various network events
    _networkEventSub = _networkEvents.networkEvents.listen((event) {
      if (event.hasPubsubMessageReceived()) {
        _handlePubsubMessage(event.pubsubMessageReceived);
      }
      // Add more event handlers as needed
    });
  }

  /// Stops the PubSub client.
  @override
  Future<void> stop() async {
    _started = false;
    await _messageBridge?.cancel();
    _messageBridge = null;
    await _networkEventSub?.cancel();
    _networkEventSub = null;
    await _pubSubClient.stop();
    // _messageController is `final` and must survive a stop/start cycle; it
    // is released with the handler.
  }

  /// Subscribes to a PubSub topic.
  @override
  Future<void> subscribe(String topic) async {
    await _pubSubClient.subscribe(topic);
    _subscriptions[topic] = <void Function(String)>{};
  }

  /// Unsubscribes from a PubSub topic.
  @override
  Future<void> unsubscribe(String topic) async {
    await _pubSubClient.unsubscribe(topic);
    _subscriptions.remove(topic);
  }

  /// Publishes a message to a PubSub topic.
  @override
  Future<void> publish(String topic, String message) async {
    await _pubSubClient.publish(topic, message);
    _messageCount++;
  }

  /// Handles incoming messages on a subscribed topic.
  @override
  void onMessage(String topic, void Function(String) handler) {
    _pubSubClient.onMessage(topic, handler);
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
