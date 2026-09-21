// src/core/ipfs_node/pubsub_handler.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../protocols/gossipsub/gossipsub_rpc.dart';
import '../../protocols/pubsub/pubsub_client.dart';
import '../../protocols/pubsub/pubsub_interface.dart';
import '../../protocols/pubsub/pubsub_message.dart';
import '../../transport/router_interface.dart';
import '../../utils/dnslink_resolver.dart';
import '../../utils/logger.dart';
import '../crypto/peer_key_registry.dart';
import '../data_structures/node_stats.dart';
import '../interfaces/i_lifecycle.dart';

/// Handles PubSub operations for an IPFS node.
class PubSubHandler implements IPubSub, ILifecycle {
  /// Constructs a [PubSubHandler] with the provided router and peer ID.
  PubSubHandler(
    RouterInterface router,
    String peerId, {
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
    // Register the pubsub protocol immediately upon construction, plus the
    // real gossipsub (meshsub) protocol IDs so identify advertises wire
    // interop with Kubo/Helia/libp2p peers before the client starts.
    router.registerProtocol('pubsub');
    for (final protocolId in kMeshsubProtocolIds) {
      router.registerProtocol(protocolId);
    }
  }
  final PubSubClient _pubSubClient;
  final Map<String, Set<void Function(String)>> _subscriptions = {};
  final StreamController<PubSubMessage> _messageController =
      StreamController<PubSubMessage>.broadcast();
  final Logger _logger = Logger('PubSubHandler');
  StreamSubscription<PubSubMessage>? _messageBridge;
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
  }

  /// Stops the PubSub client.
  @override
  Future<void> stop() async {
    _started = false;
    await _messageBridge?.cancel();
    _messageBridge = null;
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
  ///
  /// Throws when the message cannot be delivered to any peer (see
  /// [PubSubClient.publish]).
  @override
  Future<void> publish(String topic, String message) async {
    await _pubSubClient.publish(topic, message);
    _messageCount++;
  }

  /// Publishes a binary payload to a PubSub topic (see
  /// [PubSubClient.publishData]).
  @override
  Future<void> publishData(String topic, Uint8List data) async {
    await _pubSubClient.publishData(topic, data);
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

  /// Returns the current status of the PubSub handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'subscribed_topics': _subscriptions.keys.toList(),
      'total_subscribers': _subscriptions.length,
      'messages_published': _messageCount,
    };
  }
}
