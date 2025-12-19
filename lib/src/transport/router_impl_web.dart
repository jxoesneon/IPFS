import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';

import 'router_events.dart';
import 'peer_connection.dart';
import 'peer_connection_web.dart';

/// Web stub implementation for P2plibRouter.
///
/// Provides WebSocket-based connectivity for web platforms where
/// native UDP/TCP is not available.
class P2plibRouter with MultiAddressHandler {
  /// Private constructor for singleton pattern.
  P2plibRouter._();

  /// Factory constructor to create or return existing instance.
  factory P2plibRouter(IPFSConfig config) {
    _instance ??= P2plibRouter._();
    return _instance!;
  }

  static P2plibRouter? _instance;

  final PeerConnectionWeb _connection = PeerConnectionWeb();
  final Map<String, void Function(NetworkPacket)> _protocolHandlers = {};

  // Stream controllers
  final _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();
  final _messageEventsController = StreamController<MessageEvent>.broadcast();
  final _dhtEventsController = StreamController<DHTEvent>.broadcast();
  final _pubSubEventsController = StreamController<PubSubEvent>.broadcast();
  final _errorEventsController = StreamController<ErrorEvent>.broadcast();
  final _streamEventsController = StreamController<StreamEvent>.broadcast();

  /// Returns the peer ID as a string.
  String get peerID => _connection.localPeerId;

  /// Returns the peer ID object.
  PeerId get peerId =>
      PeerId(value: Uint8List.fromList(_connection.localPeerId.codeUnits));

  /// Returns list of connected peers.
  List<String> get connectedPeers => _connection.connectedPeers;

  /// Returns listening addresses.
  List<String> get listeningAddresses => [];

  /// Initializes the router.
  Future<void> initialize() async {
    _connection.messages.listen(_handleIncomingMessage);
  }

  /// Starts the router.
  Future<void> start() async {
    // Already active
  }

  /// Stops the router.
  Future<void> stop() async {
    _connection.dispose();
  }

  /// Connects to a peer via WebSocket.
  Future<void> connect(String multiaddress) async {
    await _connection.connect(multiaddress);
    // PeerConnection doesn't emit connection events directly, we infer them or add them there?
    // For now we assume success if await finishes.
    _connectionEventsController.add(
      ConnectionEvent(
        type: ConnectionEventType.connected,
        peerId: multiaddress, // Using generic peerId for now
      ),
    );
  }

  /// Disconnects from a peer.
  Future<void> disconnect(String multiaddress) async {
    await _connection.disconnect(multiaddress);
  }

  /// Lists connected peers.
  List<String> listConnectedPeers() => _connection.connectedPeers;

  /// Sends a message to a peer.
  Future<void> sendMessage(String peerId, Uint8List message) async {
    await _connection.send(peerId, message);
  }

  /// Receives messages from a peer.
  Stream<String> receiveMessages(String peerId) async* {
    // Not implemented in abstract router usually?
    yield* const Stream.empty();
  }

  /// Registers a protocol handler.
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _protocolHandlers[protocolId] = handler;
  }

  /// Registers a protocol.
  void registerProtocol(String protocolId) {
    // No-op on web for now (no negotiation)
  }

  void _handleIncomingMessage(PeerMessage message) {
    final packet = NetworkPacket(
      srcPeerId: message.peerId,
      datagram: message.data,
    );

    // Naive routing: Send to ALL handlers (Promiscuous mode)
    // Since we don't have protocol negotiation on WebSockets yet.
    // Handlers should robustly fail if message is not for them.
    for (final handler in _protocolHandlers.values) {
      try {
        handler(packet);
      } catch (e) {
        // Prepare to ignore parsing errors from wrong protocols
      }
    }

    // Also emit legacy message event
    _messageEventsController.add(
      MessageEvent(peerId: message.peerId, message: message.data),
    );
  }

  /// Resolves a peer to addresses.
  List<String> resolvePeer(String peerIdStr) => [];

  /// Resolves a peer ID to addresses.
  List<String> resolvePeerId(String peerIdStr) => [];

  /// Broadcasts a message to all connected peers.
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {
    await _connection.broadcast(message);
  }

  /// Removes a message handler.
  void removeMessageHandler(String protocolId) {
    _protocolHandlers.remove(protocolId);
  }

  /// Stream of connection events.
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  /// Stream of message events.
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;

  /// Stream of DHT events.
  Stream<DHTEvent> get dhtEvents => _dhtEventsController.stream;

  /// Stream of PubSub events.
  Stream<PubSubEvent> get pubSubEvents => _pubSubEventsController.stream;

  /// Stream of stream events.
  Stream<StreamEvent> get streamEvents => _streamEventsController.stream;

  /// Stream of error events.
  Stream<ErrorEvent> get errorEvents => _errorEventsController.stream;

  /// Returns whether the router is initialized.
  bool get isInitialized => true;

  /// Sends a request to a peer.
  Future<Uint8List> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    // TODO: Implement correlation
    throw UnimplementedError('sendRequest not implemented/correlated on web');
  }

  /// Emits an event.
  Future<void> emitEvent(String topic, Uint8List data) async {}

  /// Registers an event handler.
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  /// Removes an event handler.
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  /// Checks if a peer is connected.
  bool isConnectedPeer(String peerId) => _connection.isConnected(peerId);

  /// Returns the routing table.
  dynamic getRoutingTable() => throw UnimplementedError();

  @override
  String get multiaddr => _connection.localPeerId; // Stub

  @override
  void setMultiaddr(String addr) {}
}
