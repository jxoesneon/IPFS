// lib/src/core/ipfs_node/ipfs_node_network_events.dart

import 'dart:async';

import 'package:dart_ipfs/src/transport/router_interface.dart';

import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';

/// Handles network events for an IPFS node.
class IpfsNodeNetworkEvents {
  /// Creates a network events handler with relay client and router.
  IpfsNodeNetworkEvents(this._router);
  final RouterInterface _router;
  final _networkEventsController = StreamController<NetworkEvent>.broadcast();

  /// A stream of network events.
  Stream<NetworkEvent> get networkEvents => _networkEventsController.stream;

  /// Starts listening for and emitting network events.
  void start() {
    _listenForRouterEvents();
    _listenForCircuitRelayEvents();
  }

  /// Listens for router-related events and emits corresponding network events.
  void _listenForRouterEvents() {
    _listenForConnectionEvents();
    // _listenForMessageEvents(); // RouterInterface has messageEvents but types might differ
    // _listenForDHTEvents(); // Not available on RouterInterface yet
    // _listenForPubSubEvents(); // Not available on RouterInterface yet
    // _listenForStreamEvents(); // Not available on RouterInterface yet
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

  /// Listens for circuit relay-related events and emits corresponding network events.
  void _listenForCircuitRelayEvents() {
    // CircuitRelayClient generic events not fully implemented yet
    // Stubbed for migration
  }

  /// Stops listening for network events and closes the stream controller.
  void dispose() {
    if (!_networkEventsController.isClosed) {
      _networkEventsController.close();
    }
  }
}
