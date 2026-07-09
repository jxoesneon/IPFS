import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;

import '../core/config/network_config.dart';
import '../proto/generated/circuit_relay.pb.dart' as pb;
import '../utils/base58.dart';
import '../utils/logger.dart';
import 'router_interface.dart';

/// Handles circuit relay operations for an IPFS node.
///
/// Implements the Circuit Relay v2 protocol (HOP and STOP).
class CircuitRelayClient {
  /// Creates a new [CircuitRelayClient] using the provided [_router].
  CircuitRelayClient(this._router, {CircuitRelayConfig? config})
    : _config = config ?? const CircuitRelayConfig() {
    _logger = Logger('CircuitRelayClient');
  }

  static const String _protocolId = '/libp2p/circuit/relay/0.2.0/hop';
  static const String _stopProtocolId = '/libp2p/circuit/relay/0.2.0/stop';
  final RouterInterface _router;
  late final Logger _logger;
  final CircuitRelayConfig _config;

  final StreamController<CircuitRelayConnectionEvent>
  _circuitRelayEventsController =
      StreamController<CircuitRelayConnectionEvent>.broadcast();

  // Pending reservations keyed by relay Peer ID.
  final Map<String, Completer<Reservation>> _pendingReservations = {};

  // Pending CONNECT requests keyed by relay Peer ID.
  final Map<String, _PendingConnect> _pendingConnects = {};

  // Active reservations keyed by relay Peer ID.
  final Map<String, Reservation> _reservations = {};

  // Refresh timers keyed by relay Peer ID.
  final Map<String, Timer> _refreshTimers = {};

  // Active relayed circuits keyed by target Peer ID.
  final Map<String, RelayedConnection> _activeCircuits = {};

  // Completers waiting for an available circuit slot.
  final List<Completer<void>> _pendingCircuitSlots = [];

  StreamSubscription<ConnectionEvent>? _connectionEventsSubscription;

  /// Starts the circuit relay client.
  Future<void> start() async {
    try {
      _logger.debug('Starting CircuitRelayClient...');
      if (!_router.hasStarted) {
        await _router.start();
      }
      _router.registerProtocol(_protocolId);
      _router.registerProtocolHandler(_protocolId, _handlePacket);
      _router.registerProtocol(_stopProtocolId);
      _router.registerProtocolHandler(_stopProtocolId, _handleStopPacket);

      await _connectionEventsSubscription?.cancel();
      _connectionEventsSubscription = _router.connectionEvents.listen((event) {
        if (event.type == ConnectionEventType.disconnected) {
          _onPeerDisconnected(event.peerId);
        }
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to start CircuitRelayClient', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the circuit relay client.
  Future<void> stop() async {
    try {
      _logger.debug('Stopping CircuitRelayClient...');
      await _connectionEventsSubscription?.cancel();
      _connectionEventsSubscription = null;

      for (final timer in _refreshTimers.values) {
        timer.cancel();
      }
      _refreshTimers.clear();

      for (final completer in _pendingReservations.values) {
        if (!completer.isCompleted) {
          completer.completeError('Client stopped');
        }
      }
      _pendingReservations.clear();

      for (final pending in _pendingConnects.values) {
        if (!pending.completer.isCompleted) {
          pending.completer.completeError('Client stopped');
        }
      }
      _pendingConnects.clear();

      for (final slot in _pendingCircuitSlots) {
        if (!slot.isCompleted) {
          slot.completeError('Client stopped');
        }
      }
      _pendingCircuitSlots.clear();

      _activeCircuits.clear();
      await _circuitRelayEventsController.close();
      _logger.info('CircuitRelayClient stopped');
    } catch (e, stackTrace) {
      _logger.error('Error stopping CircuitRelayClient', e, stackTrace);
    }
  }

  /// Requests a reservation from a relay peer (Circuit Relay v2 HOP).
  ///
  /// [relayAddrOrPeerId]: The relay multiaddress or peer ID of the relay.
  /// [duration]: Requested reservation duration (legacy; kept for compatibility).
  /// [limitData]: Maximum data allowed in bytes.
  /// [limitDuration]: Maximum connection duration in seconds.
  ///
  /// Returns [Reservation] details if successful, null otherwise.
  Future<Reservation?> reserve(
    String relayAddrOrPeerId, {
    Duration? duration,
    int? limitData,
    int? limitDuration,
  }) async {
    if (!_config.enabled) {
      _logger.debug('Circuit relay is disabled; skipping reservation');
      return null;
    }

    final info = _parseRelayAddrOrPeerId(relayAddrOrPeerId);
    final relayPeerId = info.relayPeerId;
    final relayAddr = info.relayAddr;
    _logger.debug('Requesting reservation from relay: $relayPeerId');

    final reqLimitData = limitData ?? 1024 * 1024 * 1024; // 1GB default
    final reqLimitDuration = limitDuration ?? 7200; // 2 hours

    try {
      final msg = pb.HopMessage()
        ..type = pb.HopMessage_Type.RESERVE
        ..limit = (pb.Limit()
          ..duration = fixnum.Int64(reqLimitDuration)
          ..data = fixnum.Int64(reqLimitData));

      final completer = Completer<Reservation>();
      _pendingReservations[relayPeerId] = completer;

      final responseFuture = completer.future
          .timeout(
            _config.reservationTimeout,
            onTimeout: () {
              _pendingReservations.remove(relayPeerId);
              throw TimeoutException(
                'Reservation request to $relayPeerId timed out',
              );
            },
          )
          .then((res) {
            _reservations[relayPeerId] = res;
            _scheduleReservationRefresh(relayPeerId, res);
            _circuitRelayEventsController.add(
              CircuitRelayConnectionEvent(
                eventType: 'circuit_relay_reservation',
                relayAddress: relayAddr,
                reason: 'Reservation acquired',
              ),
            );
            return res;
          });

      await _router.sendMessage(
        relayPeerId,
        msg.writeToBuffer(),
        protocolId: _protocolId,
      );

      return await responseFuture;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to acquire reservation from $relayPeerId',
        e,
        stackTrace,
      );
      _pendingReservations.remove(relayPeerId);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: relayAddr,
          errorMessage: 'Reservation failed: $e',
        ),
      );
      return null;
    }
  }

  /// Connects to [targetPeerId] through a circuit relay at [relayAddr].
  ///
  /// Sends a CONNECT HopMessage, waits for a SUCCESS status, and exposes the
  /// resulting virtual connection through the router.
  Future<RelayedConnection> connectThroughRelay(
    String relayAddr,
    String targetPeerId,
  ) async {
    if (!_config.enabled) {
      throw CircuitRelayException('Circuit relay is disabled');
    }
    if (targetPeerId.isEmpty) {
      throw CircuitRelayException('targetPeerId must not be empty');
    }
    _logger.debug('Connecting to $targetPeerId via relay $relayAddr');

    final info = _parseRelayAddrOrPeerId(relayAddr);
    final relayPeerId = info.relayPeerId;
    final normalizedRelayAddr = info.relayAddr;
    if (relayPeerId.isEmpty) {
      throw CircuitRelayException(
        'Could not extract relay peer ID from $relayAddr',
      );
    }

    // Ensure we have a valid, non-expired reservation.
    var reservation = _reservations[relayPeerId];
    if (reservation == null || reservation.isExpired) {
      _logger.debug('No valid reservation for $relayPeerId; acquiring one');
      final newReservation = await reserve(relayAddr);
      if (newReservation == null) {
        throw CircuitRelayException(
          'Failed to acquire reservation for relay $relayPeerId',
        );
      }
      reservation = newReservation;
    }

    // Respect the configured circuit limit.
    await _acquireCircuitSlot();

    try {
      final msg = pb.HopMessage()
        ..type = pb.HopMessage_Type.CONNECT
        ..peer = (pb.Peer()..id = Base58().base58Decode(targetPeerId))
        ..limit = (pb.Limit()
          ..duration = reservation.limitDuration
          ..data = reservation.limitData);

      final completer = Completer<pb.Status>();
      _pendingConnects[relayPeerId] = _PendingConnect(completer, targetPeerId);

      final responseFuture = completer.future.timeout(
        _config.reservationTimeout,
        onTimeout: () {
          _pendingConnects.remove(relayPeerId);
          throw TimeoutException(
            'CONNECT request to $relayPeerId for $targetPeerId timed out',
          );
        },
      );

      await _router.sendMessage(
        relayPeerId,
        msg.writeToBuffer(),
        protocolId: _protocolId,
      );

      final status = await responseFuture;

      if (status != pb.Status.OK) {
        _releaseCircuitSlot();
        _circuitRelayEventsController.add(
          CircuitRelayConnectionEvent(
            eventType: 'circuit_relay_failed',
            relayAddress: normalizedRelayAddr,
            errorMessage: 'CONNECT rejected by $relayPeerId: $status',
          ),
        );
        throw CircuitRelayException(
          'CONNECT rejected by $relayPeerId: $status',
        );
      }

      // Expose the relayed connection through the router so that higher-level
      // protocols see the target peer as connected.
      final relayedMultiaddr = _buildRelayedMultiaddr(
        normalizedRelayAddr,
        targetPeerId,
      );
      try {
        await _router.connect(relayedMultiaddr);
      } catch (e, stackTrace) {
        _logger.warning(
          'Router could not connect to relayed multiaddr $relayedMultiaddr; '
          'registering as relayed peer instead',
          e,
          stackTrace,
        );
      }
      _router.registerRelayedConnection(targetPeerId, normalizedRelayAddr);

      final connection = RelayedConnection(
        relayAddr: normalizedRelayAddr,
        relayPeerId: relayPeerId,
        targetPeerId: targetPeerId,
        reservation: reservation,
      );
      _activeCircuits[targetPeerId] = connection;

      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_created',
          relayAddress: normalizedRelayAddr,
          reason: 'Connected to $targetPeerId',
        ),
      );

      return connection;
    } catch (e, stackTrace) {
      _releaseCircuitSlot();
      _logger.error(
        'Failed to connect via relay to $targetPeerId',
        e,
        stackTrace,
      );
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: normalizedRelayAddr,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// List of relay addresses for which we hold an active reservation.
  List<String> get activeRelayAddrs => _reservations.values
      .where((r) => !r.isExpired)
      .map((r) => r.relayAddr)
      .toList();

  /// Connects to a peer using a circuit relay.
  ///
  /// [peerId]: The target peer ID to connect to via relay.
  ///
  /// This is the legacy one-step API. Prefer [connectThroughRelay] for full
  /// Circuit Relay v2 flow.
  Future<void> connect(String peerId) async {
    _logger.debug('Connecting to peer via relay: $peerId');
    try {
      await _router.connect(peerId);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_created',
          relayAddress: peerId,
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to connect via relay to $peerId', e, stackTrace);
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_failed',
          relayAddress: peerId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Disconnects from a peer using a circuit relay.
  ///
  /// [peerId]: The peer ID to disconnect from.
  Future<void> disconnect(String peerId) async {
    _logger.debug('Disconnecting from relayed peer: $peerId');
    try {
      await _router.disconnect(peerId);
      if (_activeCircuits.remove(peerId) != null) {
        _releaseCircuitSlot();
      }
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_closed',
          relayAddress: peerId,
          reason: 'disconnected',
        ),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error disconnecting from relayed peer $peerId',
        e,
        stackTrace,
      );
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

  /// Handles incoming HOP messages.
  void _handlePacket(NetworkPacket packet) {
    try {
      final msg = pb.HopMessage.fromBuffer(packet.datagram);
      final fromPeer = packet.srcPeerId;

      if (msg.type == pb.HopMessage_Type.STATUS) {
        if (msg.hasReservation() &&
            _pendingReservations.containsKey(fromPeer)) {
          // Successful reservation response.
          final completer = _pendingReservations.remove(fromPeer)!;
          final relayAddr = _reservations.containsKey(fromPeer)
              ? _reservations[fromPeer]!.relayAddr
              : fromPeer;
          final res = Reservation(
            relayPeerId: fromPeer,
            relayAddr: relayAddr,
            expireTime: DateTime.fromMillisecondsSinceEpoch(
              msg.reservation.expire.toInt() * 1000,
            ),
            limitData: msg.reservation.limitData,
            limitDuration: msg.reservation.limitDuration,
          );
          Future.microtask(() => completer.complete(res));
        } else if (_pendingConnects.containsKey(fromPeer)) {
          // CONNECT status (OK or failure).
          final pending = _pendingConnects.remove(fromPeer)!;
          Future.microtask(() => pending.completer.complete(msg.status));
        }

        if (msg.status != pb.Status.OK &&
            _pendingReservations.containsKey(fromPeer)) {
          final completer = _pendingReservations.remove(fromPeer)!;
          Future.microtask(
            () => completer.completeError(
              'Reservation rejected by $fromPeer: ${msg.status}',
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling HOP message from ${packet.srcPeerId}',
        e,
        stackTrace,
      );
    }
  }

  /// Handles incoming STOP messages for relayed connections.
  void _handleStopPacket(NetworkPacket packet) {
    try {
      final msg = pb.StopMessage.fromBuffer(packet.datagram);
      final fromPeer = packet.srcPeerId;

      if (msg.type == pb.StopMessage_Type.CONNECT) {
        // An incoming relayed connection request. Accept it and reply with OK.
        final response = pb.StopMessage()
          ..type = pb.StopMessage_Type.STATUS
          ..status = pb.Status.OK;

        unawaited(
          _router.sendMessage(
            fromPeer,
            response.writeToBuffer(),
            protocolId: _stopProtocolId,
          ),
        );

        _circuitRelayEventsController.add(
          CircuitRelayConnectionEvent(
            eventType: 'circuit_relay_incoming',
            relayAddress: fromPeer,
            reason: 'Incoming relayed connection',
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling STOP message from ${packet.srcPeerId}',
        e,
        stackTrace,
      );
    }
  }

  void _scheduleReservationRefresh(
    String relayPeerId,
    Reservation reservation,
  ) {
    _refreshTimers[relayPeerId]?.cancel();
    final refreshAt = reservation.expireTime.subtract(
      _config.reservationRefreshInterval,
    );
    final delay = refreshAt.difference(DateTime.now());
    final timer = Timer(
      delay > Duration.zero ? delay : Duration.zero,
      () async {
        _logger.debug('Refreshing reservation for relay $relayPeerId');
        await reserve(relayPeerId);
      },
    );
    _refreshTimers[relayPeerId] = timer;
  }

  Future<void> _acquireCircuitSlot() async {
    if (_activeCircuits.length < _config.maxCircuits) {
      return;
    }
    _logger.debug(
      'Max circuits reached (${_config.maxCircuits}); queuing new attempt',
    );
    final completer = Completer<void>();
    _pendingCircuitSlots.add(completer);
    await completer.future.timeout(
      _config.reservationTimeout,
      onTimeout: () {
        _pendingCircuitSlots.remove(completer);
        throw CircuitRelayException(
          'Timed out waiting for an available circuit slot',
        );
      },
    );
  }

  void _releaseCircuitSlot() {
    if (_pendingCircuitSlots.isNotEmpty) {
      final next = _pendingCircuitSlots.removeAt(0);
      if (!next.isCompleted) {
        next.complete();
      }
    }
  }

  void _onPeerDisconnected(String peerId) {
    if (_activeCircuits.remove(peerId) != null) {
      _releaseCircuitSlot();
      _circuitRelayEventsController.add(
        CircuitRelayConnectionEvent(
          eventType: 'circuit_relay_closed',
          relayAddress: peerId,
          reason: 'peer disconnected',
        ),
      );
    }
  }

  ({String relayPeerId, String relayAddr}) _parseRelayAddrOrPeerId(
    String input,
  ) {
    if (input.contains('/')) {
      final peerId = _extractPeerIdFromRelayAddr(input);
      return (relayPeerId: peerId ?? '', relayAddr: input);
    }
    return (relayPeerId: input, relayAddr: input);
  }

  String? _extractPeerIdFromRelayAddr(String relayAddr) {
    final parts = relayAddr.split('/');
    final p2pCircuitIndex = parts.indexOf('p2p-circuit');
    if (p2pCircuitIndex <= 0) {
      // For addresses without /p2p-circuit, use the last /p2p/ segment.
      final p2pIndex = parts.lastIndexOf('p2p');
      if (p2pIndex != -1 && p2pIndex + 1 < parts.length) {
        return parts[p2pIndex + 1];
      }
      return null;
    }
    // Find /p2p/ immediately before /p2p-circuit.
    for (var i = p2pCircuitIndex - 2; i >= 0; i -= 2) {
      if (parts[i] == 'p2p' && i + 1 < parts.length) {
        return parts[i + 1];
      }
    }
    return null;
  }

  String _buildRelayedMultiaddr(String relayAddr, String targetPeerId) {
    final base = relayAddr.endsWith('/')
        ? relayAddr.substring(0, relayAddr.length - 1)
        : relayAddr;
    if (base.endsWith('/p2p-circuit')) {
      return '$base/p2p/$targetPeerId';
    }
    return '$base/p2p-circuit/p2p/$targetPeerId';
  }
}

class _PendingConnect {
  _PendingConnect(this.completer, this.targetPeerId);
  final Completer<pb.Status> completer;
  final String targetPeerId;
}

/// Represents a circuit relay event.
class CircuitRelayConnectionEvent {
  /// Creates a [CircuitRelayConnectionEvent].
  CircuitRelayConnectionEvent({
    required this.eventType,
    required this.relayAddress,
    this.errorMessage = '',
    this.reason = '',
    fixnum.Int64? dataSize,
  }) : dataSize = dataSize ?? fixnum.Int64.ZERO;

  /// The type of relay event (e.g., 'circuit_relay_created').
  final String eventType;

  /// The multiaddress or peer ID of the relay.
  final String relayAddress;

  /// Error message if the event signifies a failure.
  final String errorMessage;

  /// Reason for the event or closure.
  final String reason;

  /// Total data size transferred during the session.
  final fixnum.Int64 dataSize;
}

/// Represents a Circuit Relay v2 reservation.
class Reservation {
  /// Creates a [Reservation] from relay details.
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

/// Represents an active relayed connection.
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
