import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart';

/// Implements the Circuit Relay v2 Server (Relay Service).
///
/// This service allows the node to act as a relay for other peers.
/// It implements:
/// - HOP protocol: Handling RESERVE requests from peers wanting to serve traffic.
/// - STOP protocol: Handling CONNECT requests destined for this node.
///
/// See: https://github.com/libp2p/specs/tree/master/relay
class CircuitRelayService {
  /// Creates a new [CircuitRelayService] with the given [_router] and [_config].
  CircuitRelayService(this._router, this._config);

  final RouterInterface _router;
  final IPFSConfig _config;
  final _logger = Logger('CircuitRelayService');

  // Protocol constants
  /// The HOP protocol ID for relay reservations.
  static const hopProtocolId = '/libp2p/circuit/relay/0.2.0/hop';

  /// The STOP protocol ID for incoming connections.
  static const stopProtocolId = '/libp2p/circuit/relay/0.2.0/stop';

  /// The transport protocol ID for relayed data.
  static const transportProtocolId = '/libp2p/circuit/relay/0.2.0/transport';

  // State
  /// Current reservations granted by this relay, keyed by Peer ID.
  final Map<String, Reservation> _reservations = {};

  /// Active circuits where we are currently relaying data, keyed by source Peer ID.
  final Map<String, _CircuitContext> _activeCircuits = {};

  /// Reverse lookup for active circuits: destination Peer ID -> source Peer ID.
  final Map<String, String> _reverseCircuits = {};

  /// Timer for periodic cleanup of expired reservations and circuits.
  Timer? _cleanupTimer;

  /// Starts the service and registers protocol handlers.
  void start() {
    if (!_config.enableCircuitRelay) {
      _logger.debug('Relay service is disabled in config.');
      return;
    }

    try {
      _router.registerProtocolHandler(hopProtocolId, _handleHop);
      _router.registerProtocolHandler(stopProtocolId, _handleStop);
      _router.registerProtocolHandler(transportProtocolId, _handleTransport);

      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _cleanupExpired();
      });

      _logger.info('Circuit Relay Service started.');
    } catch (e, stackTrace) {
      _logger.error('Failed to start Circuit Relay Service', e, stackTrace);
    }
  }

  /// Stops the service and cleans up resources.
  void stop() {
    _logger.debug('Stopping Circuit Relay Service...');
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _reservations.clear();
    _activeCircuits.clear();
    _reverseCircuits.clear();
    _logger.info('Circuit Relay Service stopped.');
  }

  /// Handles relayed traffic packets.
  void _handleTransport(NetworkPacket packet) {
    final senderId = packet.srcPeerId;

    // Check if this sender is a Source in an active circuit
    if (_activeCircuits.containsKey(senderId)) {
      final context = _activeCircuits[senderId]!;
      _forwardPacket(context.destinationPeerId, packet.datagram, context);
      return;
    }

    // Check if this sender is a Destination in an active circuit (replying)
    if (_reverseCircuits.containsKey(senderId)) {
      final sourceId = _reverseCircuits[senderId]!;
      // Find the context (owned by Source)
      if (_activeCircuits.containsKey(sourceId)) {
        final context = _activeCircuits[sourceId]!;
        // Forward back to Source
        _forwardPacket(context.sourcePeerId, packet.datagram, context);
        return;
      }
    }

    _logger.verbose(
      'Received transport packet from $senderId with no active circuit.',
    );
  }

  /// Forwards a packet to the target peer.
  void _forwardPacket(
    String targetPeerId,
    Uint8List payload,
    _CircuitContext context,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check limits
    if (context.expire < now) {
      _logger.debug(
        'Circuit expired: ${context.source} <-> ${context.destination}',
      );
      _closeCircuit(context);
      return;
    }

    if (context.bytesTransferred + payload.length > context.limitData) {
      _logger.debug(
        'Circuit limit exceeded for ${context.source} -> ${context.destination} '
        '(${context.bytesTransferred}/${context.limitData} bytes)',
      );
      _closeCircuit(context);
      return;
    }

    // Update stats
    context.bytesTransferred += payload.length;

    // Send
    try {
      _router.sendMessage(
        targetPeerId,
        payload,
        protocolId: transportProtocolId,
      );
    } catch (e) {
      _logger.warning('Failed to forward packet to $targetPeerId: $e');
      // If we can't send, should we close the circuit?
      // Maybe not immediately, might be transient.
    }
  }

  /// Closes an active circuit.
  void _closeCircuit(_CircuitContext context) {
    _activeCircuits.remove(context.source);
    _reverseCircuits.remove(context.destination);
    _logger.debug(
      'Closed circuit: ${context.source} <-> ${context.destination}',
    );
  }

  /// Handles incoming HOP messages (RESERVE, CONNECT).
  void _handleHop(NetworkPacket packet) {
    try {
      final message = HopMessage.fromBuffer(packet.datagram);

      switch (message.type) {
        case HopMessage_Type.RESERVE:
          _handleReserve(packet.srcPeerId, message);
          break;
        case HopMessage_Type.CONNECT:
          _handleConnect(packet.srcPeerId, message);
          break;
        case HopMessage_Type.STATUS:
          _logger.verbose(
            'Received HOP status ${message.status} from ${packet.srcPeerId}',
          );
          break;
        default:
          _logger.warning('Unknown HOP message type: ${message.type}');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to handle HOP message from ${packet.srcPeerId}',
        e,
        stackTrace,
      );
    }
  }

  /// Handles incoming STOP messages (CONNECT).
  void _handleStop(NetworkPacket packet) {
    try {
      final message = StopMessage.fromBuffer(packet.datagram);

      if (message.type == StopMessage_Type.CONNECT) {
        // Someone is connecting TO us via a relay.
        _logger.info(
          'Received relayed connection request (STOP) from ${packet.srcPeerId}',
        );

        final response = StopMessage()
          ..type = StopMessage_Type.STATUS
          ..status = Status.OK;

        _router.sendMessage(
          packet.srcPeerId,
          Uint8List.fromList(response.writeToBuffer()),
          protocolId: stopProtocolId,
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to handle STOP message from ${packet.srcPeerId}',
        e,
        stackTrace,
      );
    }
  }

  /// Handles a RESERVE request.
  void _handleReserve(String srcPeerId, HopMessage request) {
    _logger.debug('Handling RESERVE request from $srcPeerId');

    // Check if we already have a reservation or if we should grant one
    // In a production system, we'd check peer reputation, ACLs, etc.

    final now = DateTime.now().toUtc();
    final expireTime = now.add(const Duration(hours: 2)); // Default 2h

    // Limits
    final limit = Limit()
      ..duration =
          Int64(7200) // 2 hours
      ..data = Int64(1024 * 1024 * 1024); // 1 GB limit

    final reservation = Reservation()
      ..expire = Int64(expireTime.millisecondsSinceEpoch ~/ 1000)
      ..limitDuration = limit.duration
      ..limitData = limit.data;

    // Store it
    _reservations[srcPeerId] = reservation;

    // Send Response
    final response = HopMessage()
      ..type = HopMessage_Type.STATUS
      ..status = Status.OK
      ..reservation = reservation
      ..limit = limit;

    try {
      _router.sendMessage(
        srcPeerId,
        Uint8List.fromList(response.writeToBuffer()),
        protocolId: hopProtocolId,
      );
      _logger.verbose(
        'Granted reservation to $srcPeerId, expires at $expireTime',
      );
    } catch (e) {
      _logger.error('Failed to send RESERVE response to $srcPeerId', e);
    }
  }

  /// Handles a CONNECT request.
  Future<void> _handleConnect(String srcPeerId, HopMessage request) async {
    // 1. Validate Destination
    if (!request.hasPeer() || request.peer.id.isEmpty) {
      _logger.warning(
        'Invalid CONNECT request from $srcPeerId: missing destination peer',
      );
      _sendHopStatus(srcPeerId, Status.HOP_SRC_MULTIADDR_INVALID);
      return;
    }

    // Convert Dest Peer ID to string for lookup
    final destPeerIdStr = Base58().encode(Uint8List.fromList(request.peer.id));
    _logger.debug('Handling CONNECT request from $srcPeerId to $destPeerIdStr');

    // 2. Check Reservation for Destination
    if (!_reservations.containsKey(destPeerIdStr)) {
      _logger.debug('No reservation found for destination $destPeerIdStr');
      _sendHopStatus(srcPeerId, Status.FAILED);
      return;
    }

    final reservation = _reservations[destPeerIdStr]!;
    // Check expiration
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (reservation.expire < now) {
      _logger.debug('Reservation for $destPeerIdStr has expired');
      _reservations.remove(destPeerIdStr);
      _sendHopStatus(srcPeerId, Status.FAILED);
      return;
    }

    // 3. Initiate STOP handshake with Destination
    try {
      _logger.debug('Initiating STOP handshake to $destPeerIdStr');

      final stopMsg = StopMessage()
        ..type = StopMessage_Type.CONNECT
        ..peer = (Peer()..id = Base58().base58Decode(srcPeerId))
        ..limit = (Limit()
          ..duration = reservation.limitDuration
          ..data = reservation.limitData);

      final responseBytes = await _router.sendRequest(
        destPeerIdStr,
        stopProtocolId,
        Uint8List.fromList(stopMsg.writeToBuffer()),
      );

      if (responseBytes == null) {
        _logger.warning(
          'Destination $destPeerIdStr did not respond to STOP request',
        );
        _sendHopStatus(srcPeerId, Status.HOP_CANT_OPEN_DST_STREAM);
        return;
      }

      final stopResponse = StopMessage.fromBuffer(responseBytes);

      if (stopResponse.status == Status.OK) {
        _logger.info(
          'Circuit established between $srcPeerId and $destPeerIdStr',
        );

        // 4. Register Active Circuit
        final currentNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Use the reservation limits or default
        final durationLimit = reservation.limitDuration.toInt();
        final dataLimit = reservation.limitData.toInt();

        final context = _CircuitContext(
          source: srcPeerId,
          sourcePeerId: srcPeerId,
          destination: destPeerIdStr,
          destinationPeerId: destPeerIdStr,
          expire: currentNow + durationLimit,
          limitData: dataLimit,
        );

        _activeCircuits[srcPeerId] = context;
        _reverseCircuits[destPeerIdStr] = srcPeerId;

        // 5. Send Success to Source
        _sendHopStatus(srcPeerId, Status.OK);
      } else {
        _logger.warning(
          'Destination $destPeerIdStr rejected STOP connection: ${stopResponse.status}',
        );
        _sendHopStatus(srcPeerId, stopResponse.status);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to establish circuit to $destPeerIdStr',
        e,
        stackTrace,
      );
      _sendHopStatus(srcPeerId, Status.HOP_CANT_OPEN_DST_STREAM);
    }
  }

  /// Sends a HOP status message to a peer.
  void _sendHopStatus(String dest, Status status) {
    final response = HopMessage()
      ..type = HopMessage_Type.STATUS
      ..status = status;

    try {
      _router.sendMessage(
        dest,
        Uint8List.fromList(response.writeToBuffer()),
        protocolId: hopProtocolId,
      );
    } catch (e) {
      _logger.error('Failed to send HOP status $status to $dest', e);
    }
  }

  /// Cleans up expired reservations and circuits.
  void _cleanupExpired() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _reservations.removeWhere((id, res) {
      final expired = res.expire < now;
      if (expired) _logger.verbose('Cleaning up expired reservation for $id');
      return expired;
    });

    final expiredCircuits = _activeCircuits.values
        .where((ctx) => ctx.expire < now)
        .toList();

    for (final ctx in expiredCircuits) {
      _closeCircuit(ctx);
    }
  }
}

/// Internal context for an active relayed circuit.
class _CircuitContext {
  /// Creates a [_CircuitContext].
  _CircuitContext({
    required this.source,
    required this.sourcePeerId,
    required this.destination,
    required this.destinationPeerId,
    required this.expire,
    required this.limitData,
  });

  /// The source peer identifier (usually same as [sourcePeerId]).
  final String source;

  /// The source peer ID.
  final String sourcePeerId;

  /// The destination peer identifier (usually same as [destinationPeerId]).
  final String destination;

  /// The destination peer ID.
  final String destinationPeerId;

  /// Unix timestamp when this circuit expires.
  final int expire;

  /// Maximum number of bytes allowed to be transferred.
  final int limitData;

  /// Total number of bytes transferred in this circuit.
  int bytesTransferred = 0;
}
