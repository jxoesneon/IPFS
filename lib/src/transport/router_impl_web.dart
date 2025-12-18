import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:web/web.dart' as web;

import 'router_events.dart';

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

  final Map<String, web.WebSocket> _sockets = {};

  // Stream controllers
  final _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();
  final _messageEventsController = StreamController<MessageEvent>.broadcast();
  final _dhtEventsController = StreamController<DHTEvent>.broadcast();
  final _pubSubEventsController = StreamController<PubSubEvent>.broadcast();
  final _errorEventsController = StreamController<ErrorEvent>.broadcast();
  final _streamEventsController = StreamController<StreamEvent>.broadcast();

  /// Returns the peer ID as a string (stub).
  String get peerID => 'web_peer_id_stub';

  /// Returns the peer ID object (stub).
  PeerId get peerId => PeerId(value: Uint8List.fromList(List.filled(64, 1)));

  /// Returns list of connected peers.
  List<String> get connectedPeers => [];

  /// Returns listening addresses.
  List<String> get listeningAddresses => [];

  /// Initializes the router.
  Future<void> initialize() async {}

  /// Starts the router.
  Future<void> start() async {}

  /// Stops the router.
  Future<void> stop() async {}

  /// Connects to a peer via WebSocket.
  Future<void> connect(String multiaddress) async {
    try {
      String url = multiaddress;
      if (multiaddress.contains('/ws') || multiaddress.contains('/wss')) {
        // WebSocket multiaddr detected
      }

      if (!url.startsWith('ws')) return;

      final socket = web.WebSocket(url);
      socket.binaryType = 'arraybuffer';

      final completer = Completer<void>();

      socket.onopen = ((web.Event event) {
        _sockets[multiaddress] = socket;
        _connectionEventsController.add(
          ConnectionEvent(
            type: ConnectionEventType.connected,
            peerId: multiaddress,
          ),
        );
        if (!completer.isCompleted) completer.complete();
      }).toJS;

      socket.onerror = ((web.Event event) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('WebSocket error'));
        }
      }).toJS;

      socket.onmessage = ((web.MessageEvent event) {
        // Handle binary packet if needed
      }).toJS;

      await completer.future;
    } catch (e) {
      // ignore
    }
  }

  /// Disconnects from a peer.
  Future<void> disconnect(String multiaddress) async {}

  /// Lists connected peers.
  List<String> listConnectedPeers() => [];

  /// Sends a message to a peer.
  Future<void> sendMessage(String peerId, Uint8List message) async {
    final socket = _sockets[peerId];
    if (socket != null && socket.readyState == web.WebSocket.OPEN) {
      socket.send(message.buffer.toJS);
    }
  }

  /// Receives messages from a peer.
  Stream<String> receiveMessages(String peerId) async* {
    yield* const Stream.empty();
  }

  /// Registers a protocol handler.
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {}

  /// Registers a protocol.
  void registerProtocol(String protocolId) {}

  /// Resolves a peer to addresses.
  List<String> resolvePeer(String peerIdStr) => [];

  /// Resolves a peer ID to addresses.
  List<String> resolvePeerId(String peerIdStr) => [];

  /// Broadcasts a message to all connected peers.
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {
    for (final socket in _sockets.values) {
      if (socket.readyState == web.WebSocket.OPEN) {
        socket.send(message.buffer.toJS);
      }
    }
  }

  /// Removes a message handler.
  void removeMessageHandler(String protocolId) {}

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
    throw UnimplementedError('sendRequest not implemented on web');
  }

  /// Emits an event.
  Future<void> emitEvent(String topic, Uint8List data) async {}

  /// Registers an event handler.
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  /// Removes an event handler.
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  /// Checks if a peer is connected.
  bool isConnectedPeer(String peerId) => false;

  /// Returns the routing table.
  dynamic getRoutingTable() => throw UnimplementedError();

  @override
  String get multiaddr => '';

  @override
  void setMultiaddr(String addr) {}
}
