// lib/src/transport/p2plib_router.dart

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:ipfs/src/core/config/config.dart';
import 'package:ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// A router implementation using the `p2plib` package.
class P2plibRouter {
  /// Creates a new [P2plibRouter] with the given [config].
  P2plibRouter(this._config)
      : _router = p2p.RouterL0(crypto: p2p.Crypto(p2p.Ed25519())) {
    // Initialize the router with the provided configuration
    _router.peerId = p2p.PeerId(value: _generateRandomPeerId());
    _router.transports = [p2p.TransportUdp(ip4: true, ip6: true)];
    _router.keepalivePeriod = const Duration(seconds: 30);
    _router.messageTTL = const Duration(minutes: 1);
  }

  final IPFSConfig _config;
  final p2p.RouterL0 _router;

  /// The peer ID of this node.
  String get peerID => _router.peerId.toBase58String();

  /// The connected peers.
  List<p2p.Peer> get connectedPeers =>
      _router.routes.values.map((e) => e.peer).toList();

  /// Starts the router.
  Future<void> start() async {
    await _router.start();
    // Connect to bootstrap peers
    for (final peer in _config.bootstrapPeers) {
      try {
        await _router.addPeer(p2p.PeerId.fromBase58String(peer));
      } catch (e) {
        print('Error adding bootstrap peer: $e');
      }
    }
  }

  /// Stops the router.
  Future<void> stop() async {
    await _router.stop();
  }

  /// Sends a message to a peer.
  Future<void> sendMessage(p2p.Peer peer, Uint8List message) async {
    await _router.sendDatagram(
      addresses: [peer.address.ip],
      datagram: message,
    );
  }

/// Receives a message from a peer.
  Future<Uint8List> receiveMessage(p2p.Peer peer) async {
    // Implement logic to receive messages with a timeout
    try {
      final datagram = await _router.receiveDatagram(
        timeout: Duration(seconds: 10), // Set a timeout of 10 seconds
      );
      return datagram.data;
    } catch (e) {
      if (e is TimeoutException) {
        print('Timeout while receiving message from peer: ${peer.id}');
        // Handle timeout, e.g., return null or throw a custom exception
        return null;
      } else {
        rethrow; // Re-throw other exceptions
      }
    }
  }


  /// Resolves a peer ID to a list of addresses.
  List<String> resolvePeerId(p2p.PeerId peerId) {
    return _router.resolvePeerId(peerId);
  }

  // Generates a random peer ID
  Uint8List _generateRandomPeerId() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)));
  }
}
