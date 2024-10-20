// lib/src/core/pubsub_handler.dart

import 'dart:convert';
import 'dart:async'; // Make sure to import this if it's not already imported

import '../../ipfs.dart';
import '../protocols/bitswap/bitswap.dart';
import '../protocols/dht/dht_client.dart';

// Data structure for content update notifications
class ContentUpdate {
  ContentUpdate(this.cid, this.version);
  final String cid;
  final int version;
}

// Data structure for node events
class NodeEvent {
  NodeEvent(this.eventType);
  final String eventType; // e.g., 'node_started', 'node_stopped', etc.
}

// Data structure for peer events
class PeerEvent {
  PeerEvent(this.eventType, this.peerID);
  final String eventType; // e.g., 'peer_connected', 'peer_disconnected'
  final String peerID;
}

// Data structure for network events
class NetworkEvent {
  NetworkEvent(this.eventType, [this.peers = const []]);
  final String eventType; // e.g., 'network_changed'
  final List<String> peers;
}

// Data structure for bandwidth events
class BandwidthEvent {
  BandwidthEvent(this.eventType, this.limit, this.usage);
  final String eventType; // e.g., 'bandwidth_limit_exceeded'
  final int limit;
  final int usage;
}

// Data structure for pinning events
class PinningEvent {
  PinningEvent(this.eventType, this.cid);
  final String eventType; // e.g., 'cid_pinned', 'cid_unpinned'
  final String cid;
}

// Data structure for block events
class BlockEvent {
  BlockEvent(this.eventType, this.cid, this.peer);
  final String eventType; // e.g., 'block_received', 'block_sent'
  final String cid;
  final String peer;
}

// Data structure for datastore events
class DatastoreEvent {
  DatastoreEvent(this.eventType, this.capacity, this.used);
  final String eventType; // e.g., 'datastore_full'
  final int capacity;
  final int used;
}

// Data structure for application-specific messages
class ApplicationMessage {
  ApplicationMessage(this.topic, this.message);
  final String topic;
  final dynamic message;
}

// Data structure for provider records in DHT
class ProviderRecordEvent {
  ProviderRecordEvent(this.eventType, this.providerID);
  final String eventType; // e.g., 'provider_record'
  final String providerID;
}

// Helper function to handle incoming PubSub messages
void handlePubsubMessage(
  Bitswap bitswap,
  DHTClient dht,
  StreamController<String> newContentController,
  StreamController<ContentUpdate> contentUpdatedController,
  StreamController<String> peerJoinedController,
  StreamController<String> peerLeftController,
  StreamController<NodeEvent> nodeEventsController,
  StreamController<PeerEvent> peerEventsController,
  StreamController<NetworkEvent> networkEventsController,
  StreamController<BandwidthEvent> bandwidthEventsController,
  StreamController<PinningEvent> pinningEventsController,
  StreamController<BlockEvent> blockEventsController,
  StreamController<DatastoreEvent> datastoreEventsController,
  StreamController<ApplicationMessage> applicationMessageController,
  String topic,
  dynamic message,
) {
  // Handle different message types based on the topic
  switch (topic) {
    // Cases for content and peer updates
    case 'new_content':
      final cid = message['cid'] as String?;
      if (cid != null) {
        newContentController.add(cid);
      }
      break;

    case 'content_updated':
      final cid = message['cid'] as String?;
      final version = message['version'] as int?;
      if (cid != null && version != null) {
        contentUpdatedController.add(ContentUpdate(cid, version));
      }
      break;

    case 'peer_joined':
      final peerID = message['peerID'] as String?;
      if (peerID != null) {
        peerJoinedController.add(peerID);
      }
      break;

    case 'peer_left':
      final peerID = message['peerID'] as String?;
      if (peerID != null) {
        peerLeftController.add(peerID);
      }
      break;

    // Cases for Bitswap messages
    case 'bitswap_message':
      bitswap.handlePubsubMessage(message);
      break;

    case 'want_have':
      final List<dynamic> cids = message['cids'] as List<dynamic>?;
      if (cids != null) {
        bitswap.handleWantHave(cids.cast<String>());
      } else {
        print('Invalid WANT_HAVE message format: missing cids');
      }
      break;

    case 'want_block':
      final List<dynamic> cids = message['cids'] as List<dynamic>?;
      if (cids != null) {
        bitswap.handleWantBlock(cids.cast<String>());
      } else {
        print('Invalid WANT_BLOCK message format: missing cids');
      }
      break;

    case 'wantlist':
      bitswap.handleWantlistMessage(message);
      break;

    case 'block':
      final String? cid = message['cid'] as String?;
      final dynamic blockData = message['data'];
      if (cid != null && blockData != null) {
        bitswap.handleIncomingBlock(cid, blockData);
      } else {
        print('Invalid BLOCK message format: missing cid or block data');
      }
      break;

    case 'have':
      final String? cid = message['cid'] as String?;
      final String? peerID = message['peerID'] as String?;
      if (cid != null && peerID != null) {
        bitswap.handleBlockAvailability(cid, peerID);
      } else {
        print('Invalid HAVE message format: missing cid or peerID');
      }
      break;

    case 'cancel':
      final String? cid = message['cid'] as String?;
      final String? peerID = message['peerID'] as String?;
      if (cid != null && peerID != null) {
        bitswap.handleCancelRequest(cid, peerID);
      } else {
        print('Invalid CANCEL message format: missing cid or peerID');
      }
      break;

    // Cases for DHT messages
    case 'dht_message':
      final String? operation = message['operation'] as String?;

      switch (operation) {
        case 'put_value':
          final String? key = message['key'] as String?;
          final dynamic value = message['value'];
          if (key != null) {
            dht.putValue(key, value);
          } else {
            print('Invalid DHT PUT_VALUE message: missing key');
          }
          break;

        case 'get_value':
          final String? key = message['key'] as String?;
          if (key != null) {
            dht.getValue(key);
          } else {
            print('Invalid DHT GET_VALUE message: missing key');
          }
          break;

        case 'find_node':
          final String? peerID = message['peerID'] as String?;
          if (peerID != null) {
            dht.findNode(peerID);
          } else {
            print('Invalid DHT FIND_NODE message: missing peerID');
          }
          break;

        case 'add_provider':
          final String? providerID = message['providerID'] as String?;
          final String? cid = message['cid'] as String?;
          if (providerID != null && cid != null) {
            dht.addProvider(providerID, cid);
          } else {
            print(
                'Invalid DHT ADD_PROVIDER message: missing providerID or cid');
          }
          break;

        case 'get_providers':
          final String? cid = message['cid'] as String?;
          if (cid != null) {
            dht.getProviders(cid);
          } else {
            print('Invalid DHT GET_PROVIDERS message: missing cid');
          }
          break;

        case 'provider_record':
          final provider = message['provider'] as String?;
          if (provider != null) {
            // Add logic for handling the provider record
            print('Received provider record: $provider');
          }
          break;

        default:
          print('Unknown DHT operation: $operation');
      }
      break;

    // Cases for PubSub events
    case 'subscribe':
      final String? subscribedTopic = message['topic'] as String?;
      final String? subscriberID = message['subscriberID'] as String?;
      if (subscribedTopic != null && subscriberID != null) {
        print('Subscriber $subscriberID subscribed to topic: $subscribedTopic');
      } else {
        print('Invalid subscribe message: missing topic or subscriberID');
      }
      break;

    case 'unsubscribe':
      final String? unsubscribedTopic = message['topic'] as String?;
      final String? subscriberID = message['subscriberID'] as String?;
      if (unsubscribedTopic != null && subscriberID != null) {
        print(
            'Subscriber $subscriberID unsubscribed from topic: $unsubscribedTopic');
      } else {
        print('Invalid unsubscribe message: missing topic or subscriberID');
      }
      break;

    case 'unsubscribe_all':
      print('Unsubscribed from all topics');
      // Logic to unsubscribe from all topics
      break;

    // Cases for node events
    case 'node_started':
      final String? nodeID = message['nodeID'] as String?;
      final String? timestamp = message['timestamp'] as String?;
      if (nodeID != null && timestamp != null) {
        nodeEventsController.add(NodeEvent('node_started'));
        print('Node $nodeID started at $timestamp');
      } else {
        print('Invalid node_started message: missing nodeID or timestamp');
      }
      break;

    case 'node_stopped':
      final String? nodeID = message['nodeID'] as String?;
      final String? timestamp = message['timestamp'] as String?;
      if (nodeID != null && timestamp != null) {
        nodeEventsController.add(NodeEvent('node_stopped'));
        print('Node $nodeID stopped at $timestamp');
      } else {
        print('Invalid node_stopped message: missing nodeID or timestamp');
      }
      break;

    // Cases for peer events
    case 'peer_connected':
      final String? peerID = message['peerID'] as String?;
      if (peerID != null) {
        peerEventsController.add(PeerEvent('peer_connected', peerID));
        print('Peer connected: $peerID');
      } else {
        print('Invalid peer_connected message: missing peerID');
      }
      break;

    case 'peer_disconnected':
      final String? peerID = message['peerID'] as String?;
      if (peerID != null) {
        peerEventsController.add(PeerEvent('peer_disconnected', peerID));
        print('Peer disconnected: $peerID');
      } else {
        print('Invalid peer_disconnected message: missing peerID');
      }
      break;

    // Cases for network events
    case 'network_changed':
      final List<dynamic> peers = message['peers'] as List<dynamic>?;
      networkEventsController
          .add(NetworkEvent('network_changed', peers?.cast<String>() ?? []));
      break;

    // Cases for bandwidth events
    case 'bandwidth_limit_exceeded':
      final int? limit = message['limit'] as int?;
      final int? usage = message['usage'] as int?;
      if (limit != null && usage != null) {
        bandwidthEventsController
            .add(BandwidthEvent('bandwidth_limit_exceeded', limit, usage));
      } else {
        print(
            'Invalid bandwidth limit exceeded message: missing limit or usage');
      }
      break;

    // Cases for pinning events
    case 'cid_pinned':
      final String? cid = message['cid'] as String?;
      if (cid != null) {
        pinningEventsController.add(PinningEvent('cid_pinned', cid));
        print('CID pinned: $cid');
      } else {
        print('Invalid cid_pinned message: missing cid');
      }
      break;

    case 'cid_unpinned':
      final String? cid = message['cid'] as String?;
      if (cid != null) {
        pinningEventsController.add(PinningEvent('cid_unpinned', cid));
        print('CID unpinned: $cid');
      } else {
        print('Invalid cid_unpinned message: missing cid');
      }
      break;

    // Cases for block events
    case 'block_received':
      final String? cid = message['cid'] as String?;
      final String? peer = message['peer'] as String?;
      if (cid != null && peer != null) {
        blockEventsController.add(BlockEvent('block_received', cid, peer));
        print('Block received: $cid from peer: $peer');
      } else {
        print('Invalid block_received message: missing cid or peer');
      }
      break;

    case 'block_sent':
      final String? cid = message['cid'] as String?;
      final String? peer = message['peer'] as String?;
      if (cid != null && peer != null) {
        blockEventsController.add(BlockEvent('block_sent', cid, peer));
        print('Block sent: $cid to peer: $peer');
      } else {
        print('Invalid block_sent message: missing cid or peer');
      }
      break;

    // Cases for datastore events
    case 'datastore_full':
      final int? capacity = message['capacity'] as int?;
      final int? used = message['used'] as int?;
      if (capacity != null && used != null) {
        datastoreEventsController
            .add(DatastoreEvent('datastore_full', capacity, used));
      } else {
        print('Invalid datastore_full message: missing capacity or used');
      }
      break;

    // Application messages
    case 'app_message':
      final String? topic = message['topic'] as String?;
      final dynamic appMessage = message['message'];
      if (topic != null) {
        applicationMessageController.add(ApplicationMessage(topic, appMessage));
      } else {
        print('Invalid app_message: missing topic');
      }
      break;

    default:
      print('Unknown topic: $topic');
  }
}
