import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import '/../src/utils/base58.dart';
import '../core/types/p2p_types.dart';
import '/../src/core/config/config.dart';
import 'package:p2plib/p2plib.dart' as p2p;
// lib/src/transport/p2plib_router.dart

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

  // Getter to access the RouterL0 instance
  p2p.RouterL0 get routerL0 => _router; // Expose _router as routerL0

  /// The peer ID of this node.
  String get peerID => _router.peerId.toBase58String();

  /// The connected peers.
  List<p2p.Peer> get connectedPeers =>
      _router.routes.values.map((e) => e.peer).toList();

  get connectionEvents => null;

  get messageEvents => null;

  get dhtEvents => null;

  get pubSubEvents => null;

  get errorEvents => null;

  get streamEvents => null;

  get routes => InternetAddress(address.ip);

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

  /// Receives messages from a specific peer.
  Stream<String> receiveMessages(String peerId) async* {
    while (true) {
      try {
        // Assuming _router.receiveMessage returns a Future<Uint8List>
        Uint8List? messageBytes = await _router.receiveMessage(peerId);
        if (messageBytes != null) {
          yield utf8.decode(messageBytes);
        } else {
          // Handle the case where receiveMessage returns null (e.g., timeout)
          // You might want to add a delay or break the loop here
          await Future.delayed(Duration(seconds: 1));
        }
      } catch (e) {
        print('Error receiving messages from peer $peerId: $e');
        // You might want to rethrow the exception or break the loop here
        break;
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

  connect(String multiaddress) {}

  disconnect(String multiaddress) {}

  listConnectedPeers() {}

  /// Registers a callback for handling incoming messages
  void onMessage(void Function(Message) handler) {
    _router.onDatagram((datagram) {
      // Convert datagram to Message and call handler
      final message = Message.fromBytes(datagram.data);
      handler(message);
    });
  }

  void addMessageHandler(
      String protocolId, void Function(p2p.Packet packet) handlePacket) {
    _router.addMessageHandler(protocolId, handlePacket);
  }

  void registerProtocol(String protocolId) {
    _router.registerProtocol(protocolId);
  }
}

mixin MultiAddressHandler {
  String get multiaddr;
  void setMultiaddr(String addr);
}

class NetworkMessage {
  final Uint8List data;

  NetworkMessage(this.data);

  static NetworkMessage fromBytes(Uint8List bytes) {
    return NetworkMessage(bytes);
  }
}
