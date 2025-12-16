import 'dart:async';
import 'package:fixnum/fixnum.dart' as fixnum;

import 'p2plib_router.dart'; // Import the P2P library for peer-to-peer communication

/// Handles circuit relay operations for an IPFS node.
class CircuitRelayClient {
  final P2plibRouter _router; // Router instance for handling connections
  final StreamController<CircuitRelayConnectionEvent>
  _circuitRelayEventsController =
      StreamController<CircuitRelayConnectionEvent>.broadcast();

  CircuitRelayClient(this._router);

  /// Starts the circuit relay client.
  Future<void> start() async {
    try {
      // Initialize any necessary resources or connections
      await _router.start();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  /// Stops the circuit relay client.
  Future<void> stop() async {
    try {
      // Clean up resources and close connections
      await _router.stop();
      await _circuitRelayEventsController.close(); // Close the event stream
      // print('Circuit Relay Client stopped.');
    } catch (e) {
      // ignore: empty_catches
    }
  }

  /// Connects to a peer using a circuit relay.
  Future<void> connect(String peerId) async {
    try {
      await _router.connect(peerId);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_created',
          relayAddress: peerId,
        ),
      );
    } catch (e) {
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: peerId,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Disconnects from a peer using a circuit relay.
  Future<void> disconnect(String peerId) async {
    try {
      await _router.disconnect(peerId);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_closed',
          relayAddress: peerId,
          reason: 'disconnected',
        ),
      );
    } catch (e) {
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: peerId,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Listens for incoming circuit relay events.
  Stream<CircuitRelayConnectionEvent> get onCircuitRelayEvents =>
      _circuitRelayEventsController.stream;

  Stream<CircuitRelayConnectionEvent> get connectionEvents =>
      _circuitRelayEventsController.stream;

  /// Emits a new circuit relay event.
  void emitCircuitRelayEvent(CircuitRelayConnectionEvent event) {
    _circuitRelayEventsController.add(event);
  }
}

/// Represents a circuit relay event.
class CircuitRelayConnectionEvent {
  final String eventType;
  final String relayAddress;
  final String errorMessage;
  final String reason;
  final fixnum.Int64 dataSize;

  CircuitRelayConnectionEvent({
    required this.eventType,
    required this.relayAddress,
    this.errorMessage = '',
    this.reason = '',
    fixnum.Int64? dataSize,
  }) : dataSize = dataSize ?? fixnum.Int64.ZERO;
}
