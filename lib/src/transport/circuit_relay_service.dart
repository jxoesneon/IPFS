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
  final Map<String, Reservation> _reservations = {};

  // Circuit Map: Source PeerId String -> CircuitContext
  final Map<String, _CircuitContext> _activeCircuits = {};
  // Reverse Map: Dest PeerId String -> Source PeerId String (for bidirectionality simple lookup)
  // Note: For full multiplexing, we'd need Circuit IDs.
  // This MVP assumes one active relayed connection per peer pair direction.
  final Map<String, String> _reverseCircuits = {};

  /// Starts the service and registers protocol handlers.
  void start() {
    if (!_config.enableCircuitRelay) {
      _logger.debug('Relay service is disabled in config.');
      return;
    }

    _router.registerProtocolHandler(hopProtocolId, _handleHop);
    _router.registerProtocolHandler(stopProtocolId, _handleStop);
    _router.registerProtocolHandler(transportProtocolId, _handleTransport);
    _logger.info('Circuit Relay Service started.');
  }

  /// Stops the service.
  void stop() {
    // Cleanup logic if needed
    _reservations.clear();
    _activeCircuits.clear();
    _reverseCircuits.clear();
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
        // We don't enforce limits strictly on replies in this MVP,
        // or we share the limit of the circuit.
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
      _closeCircuit(context);
      return;
    }

    if (context.bytesTransferred + payload.length > context.limitData) {
      _logger.debug(
        'Circuit limit exceeded for ${context.source} -> ${context.destination}',
      );
      _closeCircuit(context);
      return;
    }

    // Update stats
    context.bytesTransferred += payload.length;

    // Send
    // Note: In a real v2 implementation, we'd wrap this to indicate source.
    // Here we forward raw payload on the transport protocol.
    // The receiver must know context or we imply it by the customized connection.
    try {
      _router.sendMessage(targetPeerId, payload);
    } catch (e) {
      _logger.warning('Failed to forward packet to $targetPeerId: $e');
    }
  }

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
          // We shouldn't receive status messages as a server usually,
          // unless checking our own reservation?
          break;
        default:
          _logger.warning('Unknown HOP message type: ${message.type}');
      }
    } catch (e) {
      _logger.warning('Failed to handle HOP message: $e');
    }
  }

  /// Handles incoming STOP messages (CONNECT).
  void _handleStop(NetworkPacket packet) {
    try {
      final message = StopMessage.fromBuffer(packet.datagram);

      if (message.type == StopMessage_Type.CONNECT) {
        // Someone is connecting TO us via a relay.
        // We should accept the connection.
        _logger.info(
          'Received relayed connection request (STOP) from ${packet.srcPeerId}',
        );

        final response = StopMessage()
          ..type = StopMessage_Type.STATUS
          ..status = Status.OK;

        _router.sendMessage(
          packet.srcPeerId,
          Uint8List.fromList(response.writeToBuffer()),
        );
      }
    } catch (e) {
      _logger.warning('Failed to handle STOP message: $e');
    }
  }

  /// Handles a RESERVE request.
  void _handleReserve(String srcPeerId, HopMessage request) {
    // 1. Create Reservation
    final now = DateTime.now().toUtc();
    final expireTime = now.add(const Duration(hours: 2)); // Default 2h

    // Limits
    final limit = Limit()
      ..duration =
          Int64(7200) // 2 hours
      ..data = Int64(1024 * 1024 * 1024); // 1 GB limit for example

    final reservation = Reservation()
      ..expire = Int64(expireTime.millisecondsSinceEpoch ~/ 1000)
      ..limitDuration = limit.duration
      ..limitData = limit.data
    // Add our addresses to the reservation so the client knows how to reach us?
    // For now, empty or standard addrs managed by router.
    ;

    // Store it
    // Use base58 encoded peerId as key
    final srcIdStr = srcPeerId;
    _reservations[srcIdStr] = reservation;

    // Send Response
    final response = HopMessage()
      ..type = HopMessage_Type.STATUS
      ..status = Status.OK
      ..reservation = reservation
      ..limit = limit;

    _router.sendMessage(
      srcPeerId,
      Uint8List.fromList(response.writeToBuffer()),
    );
    _logger.verbose('Granted reservation to $srcIdStr');
  }

  Future<void> _handleConnect(String srcPeerId, HopMessage request) async {
    // 1. Validate Destination
    if (!request.hasPeer() || request.peer.id.isEmpty) {
      _sendHopStatus(srcPeerId, Status.HOP_SRC_MULTIADDR_INVALID);
      return;
    }

    // Convert Dest Peer ID to string for lookup
    // Assuming request.peer.id is the raw bytes of the PeerId
    final destPeerIdStr = Base58().encode(Uint8List.fromList(request.peer.id));

    // 2. Check Reservation
    if (!_reservations.containsKey(destPeerIdStr)) {
      _logger.debug('No reservation found for $destPeerIdStr');
      _sendHopStatus(srcPeerId, Status.FAILED);
      return;
    }

    final reservation = _reservations[destPeerIdStr]!;
    // Check expiration
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (reservation.expire < now) {
      _reservations.remove(destPeerIdStr);
      _sendHopStatus(srcPeerId, Status.FAILED);
      return;
    }

    // 3. Initiate STOP handshake with Destination
    try {
      _logger.debug('Initiating STOP handshake to $destPeerIdStr');

      final stopMsg = StopMessage()
        ..type = StopMessage_Type.CONNECT
        ..peer =
            (Peer()..id = Base58().base58Decode(srcPeerId)
            // addrs is repeated, so it's initialized as empty list in new Peer()
            )
        ..limit = (Limit()
          ..duration = reservation.limitDuration
          ..data = reservation.limitData);

      final responseBytes = await _router.sendRequest(
        destPeerIdStr,
        stopProtocolId,
        Uint8List.fromList(stopMsg.writeToBuffer()),
      );

      if (responseBytes == null) {
        _sendHopStatus(srcPeerId, Status.HOP_CANT_OPEN_DST_STREAM);
        return;
      }

      final stopResponse = StopMessage.fromBuffer(responseBytes);

      if (stopResponse.status == Status.OK) {
        _logger.info(
          'Circuit established between $srcPeerId and $destPeerIdStr',
        );

        // 4. Register Active Circuit
        final srcIdStr = srcPeerId;
        final currentNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Use the reservation limits or default
        final durationLimit = reservation.limitDuration.toInt();
        final dataLimit = reservation.limitData.toInt();

        final context = _CircuitContext(
          source: srcIdStr,
          sourcePeerId: srcPeerId,
          destination: destPeerIdStr,
          destinationPeerId: destPeerIdStr,
          expire: currentNow + durationLimit,
          limitData: dataLimit,
        );

        _activeCircuits[srcIdStr] = context;
        _reverseCircuits[destPeerIdStr] = srcIdStr;

        // 5. Send Success to Source
        _sendHopStatus(srcPeerId, Status.OK);
      } else {
        _logger.warning(
          'Destination rejected STOP connection: ${stopResponse.status}',
        );
        _sendHopStatus(srcPeerId, stopResponse.status);
      }
    } catch (e) {
      _logger.warning('Failed to connect to destination: $e');
      _sendHopStatus(srcPeerId, Status.HOP_CANT_OPEN_DST_STREAM);
    }
  }

  void _sendHopStatus(String dest, Status status) {
    final response = HopMessage()
      ..type = HopMessage_Type.STATUS
      ..status = status;

    _router.sendMessage(dest, Uint8List.fromList(response.writeToBuffer()));
  }
}

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
  final String source;
  final String sourcePeerId;
  final String destination;
  final String destinationPeerId;
  final int expire;
  final int limitData;
  int bytesTransferred = 0;
}
