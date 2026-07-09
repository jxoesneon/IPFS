import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;

import '../core/config/network_config.dart';
import 'router_interface.dart';

/// Handles circuit relay operations for an IPFS node (web stub).
///
/// Note: Circuit relay support on web is limited or not yet implemented.
class CircuitRelayClient {
  /// Creates a new [CircuitRelayClient] using the provided router.
  CircuitRelayClient(RouterInterface router, {CircuitRelayConfig? config});

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
  ///
  /// [relayPeerId]: The peer ID of the relay.
  /// [duration]: Requested reservation duration.
  /// [limitData]: Maximum data allowed in bytes.
  /// [limitDuration]: Maximum connection duration in seconds.
  ///
  /// Throws [UnimplementedError] on web.
  Future<Reservation?> reserve(
    String relayPeerId, {
    Duration? duration,
    int? limitData,
    int? limitDuration,
  }) async {
    throw UnimplementedError('Circuit Relay not implemented on web');
  }

  /// Connects to [targetPeerId] through a circuit relay at [relayAddr].
  ///
  /// Throws [UnimplementedError] on web.
  Future<RelayedConnection> connectThroughRelay(
    String relayAddr,
    String targetPeerId,
  ) async {
    throw UnimplementedError('Circuit Relay connect not implemented on web');
  }

  /// List of relay addresses for which we hold an active reservation.
  List<String> get activeRelayAddrs => const [];

  /// Connects to a peer using a circuit relay.
  ///
  /// [peerId]: The target peer ID.
  ///
  /// Throws [UnimplementedError] on web.
  Future<void> connect(String peerId) async {
    throw UnimplementedError('Circuit Relay connect not implemented on web');
  }

  /// Disconnects from a peer using a circuit relay.
  ///
  /// [peerId]: The peer ID to disconnect from.
  Future<void> disconnect(String peerId) async {}

  /// Stream of circuit relay connection events.
  Stream<CircuitRelayConnectionEvent> get onCircuitRelayEvents =>
      _circuitRelayEventsController.stream;

  /// Stream of circuit relay connection events (alias).
  Stream<CircuitRelayConnectionEvent> get connectionEvents =>
      _circuitRelayEventsController.stream;

  /// Emits a new circuit relay event.
  ///
  /// [event]: The event to emit.
  void emitCircuitRelayEvent(CircuitRelayConnectionEvent event) {
    if (!_circuitRelayEventsController.isClosed) {
      _circuitRelayEventsController.add(event);
    }
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
    this.relayAddr = '',
  });

  /// The relay peer ID.
  final String relayPeerId;

  /// The relay address (or peer ID) used to reach the relay.
  final String relayAddr;

  /// When this reservation expires.
  final DateTime expireTime;

  /// Maximum data allowed in bytes.
  final fixnum.Int64 limitData;

  /// Maximum duration allowed.
  final fixnum.Int64 limitDuration;

  /// Returns true if this reservation has expired.
  bool get isExpired => DateTime.now().isAfter(expireTime);
}

/// Represents an active relayed connection (web stub; never instantiated).
class RelayedConnection {
  /// Creates a [RelayedConnection].
  RelayedConnection({
    required this.relayAddr,
    required this.relayPeerId,
    required this.targetPeerId,
    required this.reservation,
  });

  /// The relay address used for this connection.
  final String relayAddr;

  /// The relay peer ID.
  final String relayPeerId;

  /// The target peer reached through the relay.
  final String targetPeerId;

  /// The reservation that keeps this circuit alive.
  final Reservation reservation;

  /// When the connection was established.
  final DateTime connectedAt = DateTime.now();
}

/// Exception thrown by [CircuitRelayClient] operations.
class CircuitRelayException implements Exception {
  /// Creates a [CircuitRelayException] with the given [message].
  CircuitRelayException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'CircuitRelayException: $message';
}
