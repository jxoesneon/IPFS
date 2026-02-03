import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/router_interface.dart';

import '../core/config/ipfs_config.dart';
import '../core/data_structures/peer.dart';
import '../transport/libp2p_router.dart';
import '../utils/base58.dart';

/// High-level network router for IPFS peer communication.
///
/// Provides an abstraction over [RouterInterface] for message sending,
/// peer discovery, and connection management.
///
/// Example:
/// ```dart
/// final router = Router(config);
/// await router.start();
/// await router.sendMessage(peerId, messageBytes);
/// ```
class Router {
  /// Creates a router with the given [config].
  Router(IPFSConfig config)
    : _router = Libp2pRouter(config),
      _peerDiscoveryController = StreamController<Peer>.broadcast(),
      _connectedPeers = {};
  final RouterInterface _router;
  final StreamController<Peer> _peerDiscoveryController;
  final Set<Peer> _connectedPeers;

  /// The peer ID of this node
  String get peerID => _router.peerID;

  /// Stream of discovered peers
  Stream<Peer> get onPeerDiscovered => _peerDiscoveryController.stream;

  /// Currently connected peers
  Set<Peer> get connectedPeers => Set.unmodifiable(_connectedPeers);

  /// Whether the router has been initialized
  bool get isInitialized => _router.isInitialized;

  /// Starts the router
  Future<void> start() async {
    await _router.start();
  }

  /// Stops the router
  Future<void> stop() async {
    await _router.stop();
    await _peerDiscoveryController.close();
  }

  /// Sends a message to a specific peer
  Future<void> sendMessage(String peerId, Uint8List message) async {
    await _router.sendMessage(peerId, message);
  }

  /// Broadcasts a message to all connected peers
  Future<void> broadcast(Uint8List message) async {
    for (final peer in _connectedPeers) {
      await sendMessage(Base58().encode(peer.id.value), message);
    }
  }

  /// Connects to a peer
  Future<void> connectToPeer(String multiaddr) async {
    await _router.connect(multiaddr);
  }

  /// Disconnects from a peer
  Future<void> disconnectFromPeer(String multiaddr) async {
    await _router.disconnect(multiaddr);
  }
}
