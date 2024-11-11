import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import '../core/config/ipfs_config.dart';
import '../core/types/p2p_types.dart';
import '../transport/p2plib_router.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../core/data_structures/peer.dart';

/// Router handles network communication between IPFS nodes
class Router {
  final P2plibRouter _router;
  final StreamController<Peer> _peerDiscoveryController;
  final Set<Peer> _connectedPeers;

  Router(IPFSConfig config)
      : _router = P2plibRouter(config),
        _peerDiscoveryController = StreamController<Peer>.broadcast(),
        _connectedPeers = {};

  /// The peer ID of this node
  String get peerID => _router.peerID;

  /// Stream of discovered peers
  Stream<Peer> get onPeerDiscovered => _peerDiscoveryController.stream;

  /// Currently connected peers
  Set<Peer> get connectedPeers => Set.unmodifiable(_connectedPeers);

  /// Starts the router
  Future<void> start() async {
    await _router.routerL0.start();
  }

  /// Stops the router
  Future<void> stop() async {
    _router.routerL0.stop();
    await _peerDiscoveryController.close();
  }

  /// Sends a message to a specific peer
  Future<void> sendMessage(dynamic peerId, Uint8List message) async {
    if (peerId is String) {
      _router.routerL0.sendDatagram(
        addresses: [_getPeerAddress(peerId)],
        datagram: message,
      );
    } else if (peerId is p2p.PeerId) {
      await _router.sendMessage(peerId, message);
    } else {
      throw ArgumentError('peerId must be either String or PeerId');
    }
  }

  /// Broadcasts a message to all connected peers
  Future<void> broadcast(Uint8List message) async {
    for (final peer in _connectedPeers) {
      await sendMessage(peer.id, message);
    }
  }

  /// Connects to a peer
  Future<void> connectToPeer(String multiaddr) async {
    // Implementation depends on p2plib connection handling
    throw UnimplementedError();
  }

  /// Disconnects from a peer
  Future<void> disconnectFromPeer(String peerId) async {
    // Implementation depends on p2plib connection handling
    throw UnimplementedError();
  }

  /// Gets the address for a peer ID
  LibP2PFullAddress _getPeerAddress(String peerId) {
    // This is a placeholder - actual implementation would need to look up
    // the peer's address from a DHT or routing table
    return LibP2PFullAddress(address: InternetAddress('127.0.0.1'), port: 4001);
  }
}
