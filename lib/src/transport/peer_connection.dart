import 'dart:async';
import 'dart:typed_data';

/// Represents a network message from a peer.
class PeerMessage {
  /// Creates a peer message.
  PeerMessage({required this.peerId, required this.data, this.protocolId});

  /// The peer ID that sent the message.
  final String peerId;

  /// The message data.
  final Uint8List data;

  /// Optional protocol identifier.
  final String? protocolId;
}

/// Abstract interface for peer-to-peer connections.
///
/// This abstraction allows different implementations for IO (using p2plib)
/// and web (using WebSocket) platforms.
abstract class PeerConnection {
  /// Connects to a peer at the specified multiaddress.
  Future<void> connect(String multiaddr);

  /// Disconnects from a peer.
  Future<void> disconnect(String peerId);

  /// Sends a message to a peer.
  Future<void> send(String peerId, Uint8List message);

  /// Broadcasts a message to all connected peers.
  Future<void> broadcast(Uint8List message);

  /// Stream of incoming messages from peers.
  Stream<PeerMessage> get messages;

  /// List of currently connected peer IDs.
  List<String> get connectedPeers;

  /// Returns true if connected to the specified peer.
  bool isConnected(String peerId);

  /// The local peer ID.
  String get localPeerId;

  /// Disposes of all connections and resources.
  void dispose();
}
