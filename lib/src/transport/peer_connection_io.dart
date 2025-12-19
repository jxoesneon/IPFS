import 'dart:async';
import 'dart:typed_data';

import 'package:p2plib/p2plib.dart' as p2p;

import 'peer_connection.dart';

/// IO implementation of [PeerConnection] using p2plib.
///
/// This implementation uses the native p2plib router for
/// UDP/TCP transport on desktop and mobile platforms.
class PeerConnectionIO implements PeerConnection {
  /// Creates a peer connection using p2plib router.
  PeerConnectionIO(this._router);

  final p2p.RouterL2 _router;
  final _messagesController = StreamController<PeerMessage>.broadcast();
  bool _disposed = false;

  @override
  Future<void> connect(String multiaddr) async {
    // p2plib handles connection through its router
    // Multiaddr parsing would be needed here
    // For now, this is a simplified implementation
  }

  @override
  Future<void> disconnect(String peerId) async {
    // p2plib manages connections internally
  }

  @override
  Future<void> send(String peerId, Uint8List message) async {
    // Would need to convert peerId string to p2p.PeerId
    // and use router.sendMessage
  }

  @override
  Future<void> broadcast(Uint8List message) async {
    // Broadcast to all connected peers
  }

  @override
  Stream<PeerMessage> get messages => _messagesController.stream;

  @override
  List<String> get connectedPeers => [];

  @override
  bool isConnected(String peerId) => false;

  @override
  String get localPeerId => _router.selfId.toString();

  @override
  void dispose() {
    if (!_disposed) {
      _messagesController.close();
      _disposed = true;
    }
  }
}

/// Factory function for IO platform.
PeerConnection createPeerConnection(dynamic router) =>
    PeerConnectionIO(router as p2p.RouterL2);
