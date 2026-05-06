// src/core/ipfs_node/protocol_manager.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Manages protocol-related operations for the IPFS node.
class ProtocolManager implements ILifecycle {
  /// Creates a [ProtocolManager] with injected dependencies.
  ProtocolManager({
    PubSubHandler? pubSubHandler,
    DHTHandler? dhtHandler,
    ContentRoutingHandler? contentRoutingHandler,
  }) : _pubSubHandler = pubSubHandler,
       _dhtHandler = dhtHandler,
       _contentRoutingHandler = contentRoutingHandler,
       _logger = Logger('ProtocolManager');

  final PubSubHandler? _pubSubHandler;
  final DHTHandler? _dhtHandler;
  final ContentRoutingHandler? _contentRoutingHandler;
  final Logger _logger;

  @override
  Future<void> start() async {
    _logger.debug('Starting ProtocolManager...');
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping ProtocolManager...');
  }

  /// Subscribes the node to a PubSub [topic].
  Future<void> subscribe(String topic) async {
    try {
      if (_pubSubHandler == null) {
        _logger.warning('PubSubHandler not available, skipping subscribe');
        return;
      }
      await _pubSubHandler.subscribe(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e, stackTrace) {
      _logger.error('Failed to subscribe to topic $topic', e, stackTrace);
      rethrow;
    }
  }

  /// Unsubscribes the node from a PubSub [topic].
  Future<void> unsubscribe(String topic) async {
    try {
      if (_pubSubHandler == null) return;
      await _pubSubHandler.unsubscribe(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e, stackTrace) {
      _logger.error('Failed to unsubscribe from topic $topic', e, stackTrace);
    }
  }

  /// Publishes a [message] to a PubSub [topic].
  Future<void> publish(String topic, String message) async {
    try {
      if (_pubSubHandler == null) {
        throw ComponentError(
          'PubSubHandler',
          'Required for publishing messages',
        );
      }
      await _pubSubHandler.publish(topic, message);
      _logger.debug('Published message to topic: $topic');
    } catch (e, stackTrace) {
      _logger.error('Failed to publish message to topic $topic', e, stackTrace);
      rethrow;
    }
  }

  /// A stream of incoming PubSub messages for all subscribed topics.
  Stream<PubSubMessage> get pubsubMessages {
    return _pubSubHandler?.messages ?? const Stream.empty();
  }

  /// Resolves an IPNS [name] to its corresponding CID.
  Future<String> resolveIPNS(String name) async {
    try {
      if (_dhtHandler == null) {
        throw ComponentError('DHTHandler', 'Required for IPNS resolution');
      }
      _logger.debug('Resolving IPNS name: $name');
      final cid = await _dhtHandler.resolveIPNS(name);
      _logger.info('Resolved IPNS $name to $cid');
      return cid;
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve IPNS name $name', e, stackTrace);
      rethrow;
    }
  }

  /// Publishes an IPNS record for the given [cid] using the specified [keyName].
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    try {
      if (_dhtHandler == null) {
        throw ComponentError(
          'DHTHandler',
          'Required for publishing IPNS records',
        );
      }
      _logger.info('Publishing IPNS record for $cid with key $keyName');
      await _dhtHandler.publishIPNS(cid, keyName: keyName);
    } catch (e, stackTrace) {
      _logger.error('Failed to publish IPNS record for $cid', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves a [domainName] via DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    try {
      _logger.debug('Resolving DNSLink for: $domainName');

      final cid = await _contentRoutingHandler?.resolveDNSLink(domainName);
      if (cid != null) {
        _logger.info('Resolved DNSLink $domainName to $cid via ContentRouting');
        return cid;
      }

      final dhtCid = await _dhtHandler?.resolveDNSLink(domainName);
      if (dhtCid != null) {
        _logger.info('Resolved DNSLink $domainName to $dhtCid via DHT');
        return dhtCid;
      }

      throw NodeStateError('Failed to resolve DNSLink for domain: $domainName');
    } catch (e, stackTrace) {
      _logger.error('Error resolving DNSLink for $domainName', e, stackTrace);
      rethrow;
    }
  }
}
