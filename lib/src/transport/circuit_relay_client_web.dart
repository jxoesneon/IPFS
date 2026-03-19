import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;

import 'router_interface.dart';

/// Handles circuit relay operations for an IPFS node (web stub).
class CircuitRelayClient {
  /// Creates a new [CircuitRelayClient] using the provided router.
  CircuitRelayClient(RouterInterface router);

  final StreamController<CircuitRelayConnectionEvent>
  _circuitRelayEventsController =
      StreamController<CircuitRelayConnectionEvent>.broadcast();

  /// Starts the circuit relay client.
  Future<void> start() async {}

  /// Stops the circuit relay client.
  Future<void> stop() async {
    await _circuitRelayEventsController.close();
  }

  /// Requests a reservation from a relay peer (Circuit Relay v2 HOP).
  Future<Reservation?> reserve(
    String relayPeerId, {
    Duration duration = const Duration(minutes: 60),
    int limitData = 1024 * 1024 * 1024,
    int limitDuration = 7200,
  }) async {
    throw UnimplementedError('Circuit Relay not implemented on web');
  }

  /// Connects to a peer using a circuit relay.
  Future<void> connect(String peerId) async {
    throw UnimplementedError('Circuit Relay connect not implemented on web');
  }

  /// Disconnects from a peer using a circuit relay.
  Future<void> disconnect(String peerId) async {}

  /// Stream of circuit relay connection events.
  Stream<CircuitRelayConnectionEvent> get onCircuitRelayEvents =>
      _circuitRelayEventsController.stream;

  /// Stream of circuit relay connection events (alias).
  Stream<CircuitRelayConnectionEvent> get connectionEvents =>
      _circuitRelayEventsController.stream;

  /// Emits a new circuit relay event.
  void emitCircuitRelayEvent(CircuitRelayConnectionEvent event) {
    _circuitRelayEventsController.add(event);
  }
}

/// Represents a circuit relay event.
class CircuitRelayConnectionEvent {
  /// Creates a circuit relay connection event.
  CircuitRelayConnectionEvent({
    required this.eventType,
    required this.relayAddress,
    this.errorMessage = '',
    this.reason = '',
    fixnum.Int64? dataSize,
  }) : dataSize = dataSize ?? fixnum.Int64.ZERO;

  /// The type of relay event.
  final String eventType;

  /// The relay address.
  final String relayAddress;

  /// Error message if applicable.
  final String errorMessage;

  /// Reason for the event.
  final String reason;

  /// Data size transferred.
  final fixnum.Int64 dataSize;
}

/// Represents a Circuit Relay v2 reservation.
class Reservation {
  /// Creates a reservation.
  Reservation({
    required this.relayPeerId,
    required this.expireTime,
    required this.limitData,
    required this.limitDuration,
  });

  /// The relay peer ID.
  final String relayPeerId;

  /// When this reservation expires.
  final DateTime expireTime;

  /// Maximum data allowed in bytes.
  final fixnum.Int64 limitData;

  /// Maximum duration allowed.
  final fixnum.Int64 limitDuration;

  /// Returns true if this reservation has expired.
  bool get isExpired => DateTime.now().isAfter(expireTime);
}
