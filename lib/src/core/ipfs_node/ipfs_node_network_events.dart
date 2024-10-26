// lib/src/core/ipfs_node/ipfs_node_network_events.dart
import 'dart:async';

import '/../src/proto/transport/ipfs_node_network_events.pb.dart';
import '/../src/transport/circuit_relay_client.dart';
import '/../src/transport/p2plib_router.dart';

/// Handles network events for an IPFS node.
class IpfsNodeNetworkEvents {
  final CircuitRelayClient _circuitRelayClient;
  final P2plibRouter _router;
  final _networkEventsController = StreamController<NetworkEvent>.broadcast();

  IpfsNodeNetworkEvents(this._circuitRelayClient, this._router);

  /// A stream of network events.
  Stream<NetworkEvent> get networkEvents => _networkEventsController.stream;

  /// Starts listening for and emitting network events.
  void start() {
    _listenForRouterEvents();
    _listenForCircuitRelayEvents();
  }

  void _listenForRouterEvents() {
    _router.connectionEvents.listen((event) {
      switch (event.eventType) {
        case 'peer_connected':
          _networkEventsController.add(NetworkEvent()
            ..peerConnected = PeerConnectedEvent()
              ..peerId = event.peerId
              ..multiaddress = event.multiaddress);
          break;
        case 'peer_disconnected':
          _networkEventsController.add(NetworkEvent()
            ..peerDisconnected = PeerDisconnectedEvent()
              ..peerId = event.peerId);
          break;
        // Add more cases for other connection-related events if needed
      }
    });

    _router.messageEvents.listen((event) {
      switch (event.eventType) {
        case 'message_received':
          _networkEventsController.add(NetworkEvent()
            ..messageReceived = MessageReceivedEvent()
              ..peerId = event.peerId
              ..messageContent = event.messageContent);
          break;
        case 'message_sent':
          _networkEventsController.add(NetworkEvent()
            ..messageSent = MessageSentEvent()
              ..peerId = event.peerId
              ..messageContent = event.messageContent);
          break;
        // Add more cases for other message-related events if needed
      }
    });

    // Listen for DHT-related events
    _router.dhtEvents.listen((event) {
      switch (event.eventType) {
        case 'dht_value_found':
          _networkEventsController.add(NetworkEvent()
            ..dhtValueFound = DHTValueFoundEvent()
              ..key = event.key
              ..value = event.value);
          break;
        case 'dht_value_not_found':
          _networkEventsController.add(NetworkEvent()
            ..dhtValueNotFound = DHTValueNotFoundEvent()
              ..key = event.key);
          break;
        // Add more cases for other DHT-related events if needed
      }
    });

    // Listen for PubSub-related events
    _router.pubSubEvents.listen((event) {
      switch (event.eventType) {
        case 'pubsub_message_received':
          _networkEventsController.add(NetworkEvent()
            ..pubSubMessageReceived = PubSubMessageReceivedEvent()
              ..topic = event.topic
              ..messageContent = event.messageContent);
          break;
        case 'pubsub_subscribed':
          _networkEventsController.add(NetworkEvent()
            ..pubSubSubscribed = PubSubSubscribedEvent()
              ..topic = event.topic);
          break;
        // Add more cases for other PubSub-related events if needed
      }
    });
  }

  void _listenForCircuitRelayEvents() {
    _circuitRelayClient.connectionEvents.listen((event) {
      switch (event.eventType) {
        case 'circuit_relay_created':
          _networkEventsController.add(NetworkEvent()
            ..circuitRelayCreated = CircuitRelayCreatedEvent()
              ..relayAddress = event.relayAddress);
          break;
        case 'circuit_relay_failed':
          _networkEventsController.add(NetworkEvent()
            ..circuitRelayFailed = CircuitRelayFailedEvent()
              ..relayAddress = event.relayAddress
              ..errorMessage = event.errorMessage);
          break;
        // Add more cases for other circuit relay-related events if needed
      }
    });
  }

  /// Stops listening for network events and closes the stream controller.
  void dispose() {
    _networkEventsController.close();
  }
}
