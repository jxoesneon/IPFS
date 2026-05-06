// lib/src/transport/router_interface.dart
import 'dart:async';
import 'dart:typed_data';

import 'router_events.dart';

// Re-export NetworkPacket and event types for convenience
export 'router_events.dart'
    show
        NetworkPacket,
        ConnectionEvent,
        ConnectionEventType,
        MessageEvent,
        NetworkMessage;

/// Abstract interface for P2P network routers.
///
/// This interface ensures that protocol handlers (DHT, Bitswap, PubSub, etc.)
/// are compatible with any underlying transport implementation.
///
/// Implementations:
/// - `Libp2pRouter`: Uses dart_libp2p for standard IPFS networking
abstract class RouterInterface {
  /// The local peer ID string of this node.
  String get peerID;

  /// Whether the router has been started.
  bool get hasStarted;

  /// Whether the router has been initialized.
  bool get isInitialized;

  /// Set of currently connected peer IDs.
  Set<String> get connectedPeers;

  /// Stream of connection events (peer connected/disconnected).
  Stream<ConnectionEvent> get connectionEvents;

  /// Stream of message events from peers.
  Stream<MessageEvent> get messageEvents;

  /// Initializes the router with configuration.
  ///
  /// Must be called before [start].
  Future<void> initialize();

  /// Starts the router and begins accepting connections.
  Future<void> start();

  /// Stops the router and disconnects all peers.
  Future<void> stop();

  /// Connects to a peer using its multiaddress.
  ///
  /// Example: `/ip4/127.0.0.1/tcp/4001/p2p/Qm...`
  Future<void> connect(String multiaddress);

  /// Disconnects from a peer.
  ///
  /// [peerIdOrMultiaddress] - The peer ID or multiaddress to disconnect from.
  Future<void> disconnect(String peerIdOrMultiaddress);

  /// Returns list of addresses the router is listening on.
  List<String> get listeningAddresses;

  /// Returns a list of connected peer IDs.
  List<String> listConnectedPeers();

  /// Checks if a peer is currently connected.
  ///
  /// [peerIdStr] - The peer ID to check.
  bool isConnectedPeer(String peerIdStr);

  /// Sends a message to a specific peer.
  ///
  /// [peerIdStr] - The target peer's ID.
  /// [message] - The raw message bytes.
  /// [protocolId] - Optional protocol identifier for multiplexing.
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  });

  /// Sends a request and waits for a response.
  ///
  /// [peerId] - The target peer's ID.
  /// [protocolId] - The protocol identifier.
  /// [request] - The raw request bytes.
  ///
  /// Returns the response bytes, or null on timeout/failure.
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  );

  /// Receives messages from a specific peer.
  ///
  /// [peerId] - The peer ID to receive messages from.
  ///
  /// Returns a stream of message bytes from the specified peer.
  Stream<Uint8List> receiveMessages(String peerId);

  /// Registers a handler for a specific protocol.
  ///
  /// [protocolId] - The protocol identifier.
  /// [handler] - The callback function to handle incoming packets.
  ///
  /// When a message with [protocolId] is received, [handler] is called.
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  );

  /// Removes the handler for a specific protocol.
  ///
  /// [protocolId] - The protocol identifier to remove the handler for.
  void removeMessageHandler(String protocolId);

  /// Registers a protocol without a handler.
  ///
  /// [protocolId] - The protocol identifier to register.
  ///
  /// Used to advertise protocol support to peers.
  void registerProtocol(String protocolId);

  /// Broadcasts a message to all connected peers.
  ///
  /// [protocolId] - The protocol identifier.
  /// [message] - The raw message bytes to broadcast.
  Future<void> broadcastMessage(String protocolId, Uint8List message);

  /// Emits a network event.
  ///
  /// [topic] - The event topic.
  /// [data] - The event payload.
  void emitEvent(String topic, Uint8List data);

  /// Registers a handler for network events.
  ///
  /// [topic] - The event topic.
  /// [handler] - The callback function to handle the event.
  void onEvent(String topic, void Function(dynamic) handler);

  /// Removes a handler for network events.
  ///
  /// [topic] - The event topic.
  /// [handler] - The callback function to remove.
  void offEvent(String topic, void Function(dynamic) handler);

  /// Parses a multiaddress string into address components.
  ///
  /// [multiaddr] - The multiaddress string to parse.
  ///
  /// Returns the parsed multiaddress object, or null if parsing fails.
  Object? parseMultiaddr(String multiaddr);

  /// Resolves a peer ID to available addresses.
  ///
  /// [peerIdStr] - The peer ID to resolve.
  ///
  /// Returns a list of multiaddresses for the peer.
  List<String> resolvePeerId(String peerIdStr);
}
