// lib/src/core/ipfs_node/ipfs_node_network_events.dart

import 'dart:async';
import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';
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
    _listenForErrorEvents();
  }

  /// Listens for router-related events and emits corresponding network events.
  void _listenForRouterEvents() {
    _listenForConnectionEvents();
    _listenForMessageEvents();
    _listenForDHTEvents();
    _listenForPubSubEvents();
    _listenForStreamEvents();
  }

  /// Listens for connection events from the router.
  void _listenForConnectionEvents() {
    _router.connectionEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'peer_connected':
          networkEvent.peerConnected = PeerConnectedEvent()
            ..peerId = event.peerId
            ..multiaddress = event.multiaddress;
          break;
        case 'peer_disconnected':
          networkEvent.peerDisconnected = PeerDisconnectedEvent()
            ..peerId = event.peerId;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for message events from the router.
  void _listenForMessageEvents() {
    _router.messageEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'message_received':
          networkEvent.messageReceived = MessageReceivedEvent()
            ..peerId = event.peerId
            ..messageContent = event.messageContent;
          break;
        case 'message_sent':
          networkEvent.messageSent = MessageSentEvent()
            ..peerId = event.peerId
            ..messageContent = event.messageContent;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for DHT-related events from the router.
  void _listenForDHTEvents() {
    _router.dhtEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'dht_value_found':
          networkEvent.dhtValueFound = DHTValueFoundEvent()
            ..key = event.key
            ..value = event.value
            ..peerId = event.peerId; // Added to match the proto
          break;
        case 'dht_value_not_found':
          networkEvent.dhtValueNotFound = DHTValueNotFoundEvent()
            ..key = event.key;
          break;
        case 'dht_provider_added':
          networkEvent.dhtProviderAdded = DHTProviderAddedEvent()
            ..key = event.key
            ..peerId = event.peerId; // Added to match the proto
          break;
        case 'dht_provider_queried':
          networkEvent.dhtProviderQueried = DHTProviderQueriedEvent()
            ..key = event.key
            ..providers.addAll(event.providers); // List of providers
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for PubSub-related events from the router.
  void _listenForPubSubEvents() {
    _router.pubSubEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'pubsub_message_received':
          networkEvent.pubsubMessageReceived = PubsubMessageReceivedEvent()
            ..topic = event.topic
            ..messageContent = event.messageContent
            ..peerId = event.peerId; // Added to match the proto
          break;
        case 'pubsub_subscribed':
          networkEvent.pubsubSubscriptionCreated = PubsubSubscriptionCreatedEvent()
            ..topic = event.topic;
          break;
        case 'pubsub_unsubscribed':
          networkEvent.pubsubSubscriptionCancelled = PubsubSubscriptionCancelledEvent()
            ..topic = event.topic;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for stream-related events.
  void _listenForStreamEvents() {
    // Assuming there's a StreamEvents class in the router.
    _router.streamEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'stream_started':
          networkEvent.streamStarted = StreamStartedEvent()
            ..streamId = event.streamId
            ..peerId = event.peerId;
          break;
        case 'stream_ended':
          networkEvent.streamEnded = StreamEndedEvent()
            ..streamId = event.streamId
            ..peerId = event.peerId
            ..reason = event.reason;
          break;
        case 'peer_discovered':
          networkEvent.peerDiscovered = PeerDiscoveredEvent()
            ..peerId = event.peerId;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for circuit relay-related events and emits corresponding network events.
  void _listenForCircuitRelayEvents() {
    _circuitRelayClient.connectionEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.eventType) {
        case 'circuit_relay_created':
          networkEvent.circuitRelayCreated = CircuitRelayCreatedEvent()
            ..relayAddress = event.relayAddress;
          break;
        case 'circuit_relay_failed':
          networkEvent.circuitRelayFailed = CircuitRelayFailedEvent()
            ..relayAddress = event.relayAddress
            ..errorMessage = event.errorMessage;
          break;
        case 'circuit_relay_closed':
          networkEvent.circuitRelayClosed = CircuitRelayClosedEvent()
            ..relayAddress = event.relayAddress
            ..reason = event.reason;
          break;
        case 'circuit_relay_traffic':
          networkEvent.circuitRelayTraffic = CircuitRelayTrafficEvent()
            ..relayAddress = event.relayAddress
            ..dataSize = event.dataSize;
          break;
        case 'circuit_relay_data_received':
          networkEvent.circuitRelayDataReceived = CircuitRelayDataReceivedEvent()
            ..relayAddress = event.relayAddress
            ..dataSize = event.dataSize;
          break;
        case 'circuit_relay_data_sent':
          networkEvent.circuitRelayDataSent = CircuitRelayDataSentEvent()
            ..relayAddress = event.relayAddress
            ..dataSize = event.dataSize;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for error events and emits corresponding network error events.
  void _listenForErrorEvents() {
    _router.errorEvents.listen((event) {
      final networkEvent = NetworkEvent()
        ..error = ErrorEvent()
        ..errorType = event.errorType
        ..message = event.message
        ..stackTrace = event.stackTrace;
      _networkEventsController.add(networkEvent);
    });
  }

  /// Stops listening for network events and closes the stream controller.
  void dispose() {
    if (!_networkEventsController.isClosed) {
      _networkEventsController.close();
    }
  }
}
