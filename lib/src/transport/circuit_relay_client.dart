import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart' as pb;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'p2plib_router.dart'; // Import the P2P library for peer-to-peer communication

/// Handles circuit relay operations for an IPFS node.
class CircuitRelayClient {
  static const String _protocolId = '/libp2p/circuit/relay/0.2.0/hop';
  final P2plibRouter _router; // Router instance for handling connections
  final StreamController<CircuitRelayConnectionEvent>
  _circuitRelayEventsController =
      StreamController<CircuitRelayConnectionEvent>.broadcast();

  // Pending reservations keyed by Relay Peer ID
  final Map<String, Completer<Reservation>> _pendingReservations = {};

  CircuitRelayClient(this._router);

  /// Starts the circuit relay client.
  Future<void> start() async {
    try {
      // Initialize any necessary resources or connections
      await _router.start();
      _router.registerProtocol(_protocolId);
      _router.registerProtocolHandler(_protocolId, _handlePacket);
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

  /// Requests a reservation from a relay peer (Circuit Relay v2 HOP).
  ///
  /// Returns [Reservation] details if successful.
  Future<Reservation?> reserve(
    String relayPeerId, {
    Duration duration = const Duration(minutes: 60),
    int limitData = 1024 * 1024 * 1024, // 1GB default
    int limitDuration = 7200, // 2 hours
  }) async {
    try {
      final msg = pb.HopMessage()
        ..type = pb.HopMessage_Type.RESERVE
        ..limit = (pb.Limit()
          ..duration = fixnum.Int64(limitDuration)
          ..data = fixnum.Int64(limitData));

      // Create completer for response
      final completer = Completer<Reservation>();
      _pendingReservations[relayPeerId] = completer;

      // Send message
      final peerIdBytes = Base58().base58Decode(relayPeerId);
      final addresses = _router.routerL0.resolvePeerId(
        p2p.PeerId(value: peerIdBytes),
      );

      if (addresses.isEmpty) {
        throw StateError(
          'Could not resolve address for relay peer: $relayPeerId',
        );
      }

      _router.routerL0.sendDatagram(
        addresses: addresses,
        datagram: msg.writeToBuffer(),
      );

      // Wait for response or timeout
      return await completer.future
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              _pendingReservations.remove(relayPeerId);
              throw TimeoutException('Reservation request timed out');
            },
          )
          .then((res) {
            _circuitRelayEventsController.add(
              CircuitRelayConnectionEvent(
                eventType: 'circuit_relay_reservation',
                relayAddress: relayPeerId,
                reason: 'Reservation acquired',
              ),
            );
            return res;
          });
    } catch (e) {
      _pendingReservations.remove(relayPeerId);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: relayPeerId,
          errorMessage: 'Reservation failed: $e',
        ),
      );
      return null;
    }
  }

  /// Handles incoming HOP messages
  void _handlePacket(p2p.Packet packet) {
    try {
      final msg = pb.HopMessage.fromBuffer(packet.datagram);
      final fromPeer = Base58().encode(packet.srcPeerId.value);

      if (msg.type == pb.HopMessage_Type.STATUS) {
        if (_pendingReservations.containsKey(fromPeer)) {
          final completer = _pendingReservations.remove(fromPeer)!;

          if (msg.status == pb.Status.OK) {
            final res = Reservation(
              relayPeerId: fromPeer,
              expireTime: DateTime.fromMillisecondsSinceEpoch(
                msg.reservation.expire.toInt() * 1000,
              ),
              limitData: msg.reservation.limitData,
              limitDuration: msg.reservation.limitDuration,
            );
            completer.complete(res);
          } else {
            completer.completeError('Reservation rejected: ${msg.status}');
          }
        }
      }
      // Handle other types (CONNECT, etc.) if needed in future
    } catch (e) {
      // ignore: avoid_print
      // print('Error handling HOP message: $e');
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

/// Represents a Circuit Relay v2 reservation.
class Reservation {
  final String relayPeerId;
  final DateTime expireTime;
  final fixnum.Int64 limitData;
  final fixnum.Int64 limitDuration;

  Reservation({
    required this.relayPeerId,
    required this.expireTime,
    required this.limitData,
    required this.limitDuration,
  });

  bool get isExpired => DateTime.now().isAfter(expireTime);
}
