// lib/src/protocols/identify/identify_push_handler.dart
//
// libp2p Identify Push protocol handler.
//
// Protocol ID: /ipfs/id/push/1.0.0
//
// When this node's protocols or addresses change, it pushes an updated
// Identify message to all connected peers. Conversely, when a remote peer
// pushes its updated info, this handler processes the incoming message and
// updates the local peer store / emits an event.
//
// Spec: https://github.com/libp2p/specs/blob/master/identify/README.md

import 'dart:async';

import '../../transport/router_interface.dart';
import '../../utils/logger.dart';
import 'identify_handler.dart';
import 'identify_pb.dart';

/// The protocol ID for the identify-push protocol.
const String identifyPushProtocolId = '/ipfs/id/push/1.0.0';

/// Event emitted when a remote peer pushes updated identify info.
class IdentifyPushEvent {
  /// Creates a push event.
  IdentifyPushEvent({required this.peerId, required this.identify});

  /// The peer that sent the push.
  final String peerId;

  /// The decoded identify message from the remote peer.
  final IdentifyPb identify;

  @override
  String toString() =>
      'IdentifyPushEvent(peerId: $peerId, agent: ${identify.agentVersion})';
}

/// Handler for the libp2p Identify Push protocol (/ipfs/id/push/1.0.0).
///
/// Receives pushed identify updates from remote peers and can push this
/// node's updated info to all connected peers.
class IdentifyPushHandler {
  /// Creates an identify-push handler.
  ///
  /// [router] provides the underlying P2P transport.
  /// [identifyHandler] is used to build the local Identify message when
  /// pushing updates.
  IdentifyPushHandler({
    required RouterInterface router,
    required IdentifyHandler identifyHandler,
    Logger? logger,
  }) : _router = router,
       _identifyHandler = identifyHandler,
       _logger = logger ?? Logger('IdentifyPushHandler') {
    _pushController = StreamController<IdentifyPushEvent>.broadcast();
  }

  final RouterInterface _router;
  final IdentifyHandler _identifyHandler;
  final Logger _logger;
  bool _started = false;

  late StreamController<IdentifyPushEvent> _pushController;

  /// Stream of incoming push events from remote peers.
  Stream<IdentifyPushEvent> get pushEvents => _pushController.stream;

  /// Whether the handler has been started.
  bool get isStarted => _started;

  /// Starts the handler by registering the protocol with the router.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _router.registerProtocolHandler(identifyPushProtocolId, _onPushReceived);
    _logger.info('Identify push handler started on $identifyPushProtocolId');
  }

  /// Stops the handler.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _router.removeMessageHandler(identifyPushProtocolId);
    await _pushController.close();
    _logger.info('Identify push handler stopped');
  }

  /// Handles an incoming push message from a remote peer.
  void _onPushReceived(NetworkPacket packet) {
    _logger.verbose('Identify push received from ${packet.srcPeerId}');

    try {
      if (packet.datagram.isEmpty) {
        _logger.warning('Empty identify push from ${packet.srcPeerId}');
        return;
      }

      final identify = IdentifyPb.decode(packet.datagram);
      final event = IdentifyPushEvent(
        peerId: packet.srcPeerId,
        identify: identify,
      );

      _pushController.add(event);
      _logger.debug(
        'Processed identify push from ${packet.srcPeerId}: '
        'protocols=${identify.protocols.length}, '
        'addrs=${identify.listenAddrs.length}',
      );
    } catch (e, st) {
      _logger.error('Failed to decode identify push', e, st);
    }
  }

  /// Pushes this node's updated identify info to all connected peers.
  ///
  /// This should be called when protocols or listen addresses change.
  Future<void> pushUpdate() async {
    if (!_started) {
      _logger.warning('Cannot push update: handler not started');
      return;
    }

    final peers = _router.listConnectedPeers();
    if (peers.isEmpty) {
      _logger.debug('No connected peers to push identify update to');
      return;
    }

    final message = await _identifyHandler.buildIdentifyMessage();
    final encoded = message.encode();

    _logger.debug('Pushing identify update to ${peers.length} peers');

    for (final peerId in peers) {
      try {
        await _router.sendMessage(
          peerId,
          encoded,
          protocolId: identifyPushProtocolId,
        );
      } catch (e) {
        _logger.warning('Failed to push identify to $peerId: $e');
      }
    }

    _logger.info('Identify update pushed to ${peers.length} peers');
  }

  /// Pushes an update to a single specific peer.
  Future<void> pushToPeer(String peerId) async {
    if (!_started) {
      _logger.warning('Cannot push update: handler not started');
      return;
    }

    final message = await _identifyHandler.buildIdentifyMessage();
    final encoded = message.encode();

    try {
      await _router.sendMessage(
        peerId,
        encoded,
        protocolId: identifyPushProtocolId,
      );
      _logger.debug('Pushed identify update to $peerId');
    } catch (e) {
      _logger.warning('Failed to push identify to $peerId: $e');
      rethrow;
    }
  }
}
