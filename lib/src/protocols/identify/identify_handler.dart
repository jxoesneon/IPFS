// lib/src/protocols/identify/identify_handler.dart
//
// libp2p Identify protocol v1.0.0 handler.
//
// Protocol ID: /ipfs/id/1.0.0
//
// When a remote peer opens a stream with this protocol ID, the handler
// responds with an Identify protobuf message containing this node's
// public key, listen addresses, supported protocols, agent/protocol
// version strings, and a signed peer record. The stream is then closed.
//
// Spec: https://github.com/libp2p/specs/blob/master/identify/README.md

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/peer/peer_record.dart';
import '../../core/peer/peer_record_pb.dart';
import '../../transport/router_interface.dart';
import '../../utils/logger.dart';
import 'identify_pb.dart';

/// The protocol ID for the identify protocol.
const String identifyProtocolId = '/ipfs/id/1.0.0';

/// The protocol version string advertised in Identify messages.
const String identifyProtocolVersion = 'ipfs/0.1.0';

/// The agent version string advertised in Identify messages.
const String identifyAgentVersion = 'dart_ipfs/1.11.5';

/// Handler for the libp2p Identify protocol (/ipfs/id/1.0.0).
///
/// Responds to incoming identify requests with this node's information.
/// Also provides a [identify] method to query remote peers.
class IdentifyHandler {
  /// Creates an identify handler.
  ///
  /// [router] provides the underlying P2P transport.
  /// [keyPair] is the node's Ed25519 key pair used to derive the public key.
  /// [publicKeyBytes] is the 32-byte Ed25519 public key.
  /// [peerIdBytes] is the marshalled peer ID bytes.
  /// [protocols] is the list of protocol IDs this node supports.
  /// [peerRecordSigner] optionally provides signed peer record generation.
  IdentifyHandler({
    required RouterInterface router,
    required SimpleKeyPair keyPair,
    required Uint8List publicKeyBytes,
    required Uint8List peerIdBytes,
    List<String> protocols = const [],
    PeerRecordSigner? peerRecordSigner,
    Logger? logger,
  }) : _router = router,
       _publicKeyBytes = publicKeyBytes,
       _peerIdBytes = peerIdBytes,
       _protocols = List<String>.from(protocols),
       _peerRecordSigner = peerRecordSigner,
       _logger = logger ?? Logger('IdentifyHandler');

  final RouterInterface _router;
  final Uint8List _publicKeyBytes;
  final Uint8List _peerIdBytes;
  final List<String> _protocols;
  final PeerRecordSigner? _peerRecordSigner;
  final Logger _logger;

  bool _started = false;

  /// Whether the handler has been started.
  bool get isStarted => _started;

  /// The list of supported protocols.
  List<String> get protocols => List.unmodifiable(_protocols);

  /// Adds a protocol to the supported list.
  void addProtocol(String protocolId) {
    if (!_protocols.contains(protocolId)) {
      _protocols.add(protocolId);
    }
  }

  /// Removes a protocol from the supported list.
  void removeProtocol(String protocolId) {
    _protocols.remove(protocolId);
  }

  /// Starts the handler by registering the protocol with the router.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _router.registerProtocolHandler(identifyProtocolId, _onIdentifyRequest);
    _logger.info('Identify handler started on $identifyProtocolId');
  }

  /// Stops the handler.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _router.removeMessageHandler(identifyProtocolId);
    _logger.info('Identify handler stopped');
  }

  /// Handles an incoming identify request.
  ///
  /// The identify protocol has no request body — the remote peer simply
  /// opens a stream and we respond with our Identify message. The
  /// [packet.datagram] may be empty; we use [packet.srcPeerId] as the
  /// observed address source context.
  void _onIdentifyRequest(NetworkPacket packet) {
    _logger.verbose('Identify request from ${packet.srcPeerId}');

    // Build and send the identify response asynchronously.
    _buildIdentifyResponse(remotePeerId: packet.srcPeerId)
        .then((message) {
          final encoded = message.encode();
          packet.responder?.call(encoded);
          _logger.debug('Sent identify response to ${packet.srcPeerId}');
        })
        .catchError((Object e, StackTrace st) {
          _logger.error('Failed to build identify response', e, st);
        });
  }

  /// Builds an Identify message for this node.
  ///
  /// [remotePeerId] is used for logging; the observedAddr field would
  /// normally be set to the multiaddr we observe the remote peer on.
  Future<IdentifyPb> buildIdentifyMessage({
    String? remotePeerId,
    Uint8List? observedAddr,
  }) async {
    return _buildIdentifyResponse(
      remotePeerId: remotePeerId,
      observedAddr: observedAddr,
    );
  }

  Future<IdentifyPb> _buildIdentifyResponse({
    String? remotePeerId,
    Uint8List? observedAddr,
  }) async {
    // Encode the public key as a protobuf PublicKey message.
    final publicKeyPb = PublicKeyPb(
      type: KeyType.ed25519,
      data: Uint8List.fromList(_publicKeyBytes),
    );
    final publicKeyBytes = publicKeyPb.encode();

    // Get listen addresses as multiaddr bytes.
    final listenAddrs = _router.listeningAddresses
        .map((addr) => Uint8List.fromList(utf8.encode(addr)))
        .toList();

    // Build signed peer record if a signer is available.
    Uint8List? signedPeerRecordBytes;
    if (_peerRecordSigner != null) {
      try {
        final spr = await _peerRecordSigner.create(listenAddrs);
        signedPeerRecordBytes = spr.envelopeBytes;
      } catch (e, st) {
        _logger.warning('Failed to create signed peer record: $e', e, st);
      }
    }

    return IdentifyPb(
      publicKey: publicKeyBytes,
      listenAddrs: listenAddrs,
      protocols: List<String>.from(_protocols),
      observedAddr: observedAddr,
      protocolVersion: identifyProtocolVersion,
      agentVersion: identifyAgentVersion,
      signedPeerRecord: signedPeerRecordBytes,
    );
  }

  /// Queries a remote peer for its identify information.
  ///
  /// Opens a stream to [peerId] on the identify protocol, reads the
  /// response, and returns the decoded [IdentifyPb].
  Future<IdentifyPb?> identify(String peerId) async {
    _logger.debug('Querying identify for peer $peerId');
    try {
      // The identify protocol: open a stream, the remote responds
      // immediately with the Identify message. We send an empty request.
      final response = await _router.sendRequest(
        peerId,
        identifyProtocolId,
        Uint8List(0),
      );
      if (response == null || response.isEmpty) {
        _logger.warning('Empty identify response from $peerId');
        return null;
      }
      final message = IdentifyPb.decode(response);
      _logger.debug(
        'Received identify from $peerId: '
        'agent=${message.agentVersion}, protocols=${message.protocols.length}',
      );
      return message;
    } catch (e, st) {
      _logger.error('Identify query failed for $peerId', e, st);
      return null;
    }
  }

  /// The peer ID bytes used by this handler.
  Uint8List get peerIdBytes => Uint8List.fromList(_peerIdBytes);
}
