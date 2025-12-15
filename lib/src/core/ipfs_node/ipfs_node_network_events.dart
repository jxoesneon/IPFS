// lib/src/core/ipfs_node/ipfs_node_network_events.dart

import 'dart:async';
import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';

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
      switch (event.type) {
        case ConnectionEventType.connected:
          networkEvent.peerConnected = PeerConnectedEvent()
            ..peerId = event.peerId
            ..multiaddress = event.peerId;
          break;
        case ConnectionEventType.disconnected:
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
      networkEvent.messageReceived = MessageReceivedEvent()
        ..peerId = event.peerId
        ..messageContent = event.message;
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for DHT-related events from the router.
  void _listenForDHTEvents() {
    _router.dhtEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.type) {
        case DHTEventType.valueFound:
          networkEvent.dhtValueFound = DHTValueFoundEvent()
            ..key = event.data['key']
            ..value = event.data['value']
            ..peerId = event.data['peerId'];
          break;
        case DHTEventType.providerFound:
          networkEvent.dhtProviderQueried = DHTProviderQueriedEvent()
            ..key = event.data['key']
            ..providers.addAll(event.data['providers'] as List<String>);
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
            ..messageContent = event.message
            ..peerId = event.publisher;
          break;
        case 'pubsub_subscribed':
          networkEvent.pubsubSubscriptionCreated =
              PubsubSubscriptionCreatedEvent()..topic = event.topic;
          break;
        case 'pubsub_unsubscribed':
          networkEvent.pubsubSubscriptionCancelled =
              PubsubSubscriptionCancelledEvent()..topic = event.topic;
          break;
      }
      _networkEventsController.add(networkEvent);
    });
  }

  /// Listens for stream-related events.
  void _listenForStreamEvents() {
    _router.streamEvents.listen((event) {
      final networkEvent = NetworkEvent();
      switch (event.type) {
        case StreamEventType.opened:
          networkEvent.streamStarted = StreamStartedEvent()
            ..streamId = event.streamId;
          break;
        case StreamEventType.closed:
          networkEvent.streamEnded = StreamEndedEvent()
            ..streamId = event.streamId
            ..reason = 'Stream closed';
          break;
        case StreamEventType.data:
          // Handle data event if needed
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
            ..reason = event.errorMessage;
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
          networkEvent.circuitRelayDataReceived =
              CircuitRelayDataReceivedEvent()
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
        ..error = NodeErrorEvent(
          errorType: _mapToProtoErrorType(event.type.toString()),
          message: event.message,
          stackTrace: '',
          source: 'router',
        );
      _networkEventsController.add(networkEvent);
    });
  }

  // Helper function to map existing error types to the Proto enum
  NodeErrorEvent_ErrorType _mapToProtoErrorType(String errorType) {
    switch (errorType) {
      case 'invalidRequest':
        return NodeErrorEvent_ErrorType.INVALID_REQUEST;
      case 'notFound':
        return NodeErrorEvent_ErrorType.NOT_FOUND;
      case 'methodNotFound':
        return NodeErrorEvent_ErrorType.METHOD_NOT_FOUND;
      case 'internalError':
        return NodeErrorEvent_ErrorType.INTERNAL_ERROR;
      case 'networkError':
        return NodeErrorEvent_ErrorType.NETWORK;
      case 'protocolError':
        return NodeErrorEvent_ErrorType.PROTOCOL;
      case 'securityError':
        return NodeErrorEvent_ErrorType.SECURITY;
      case 'datastoreError':
        return NodeErrorEvent_ErrorType.DATASTORE;
      default:
        return NodeErrorEvent_ErrorType.UNKNOWN;
    }
  }

  /// Stops listening for network events and closes the stream controller.
  void dispose() {
    if (!_networkEventsController.isClosed) {
      _networkEventsController.close();
    }
  }
}
