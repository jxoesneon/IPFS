import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'peer_connection.dart';

/// Web implementation of [PeerConnection] using WebSocket.
///
/// This implementation uses WebSocket connections for P2P communication
/// in browser environments. Direct peer connections are not possible
/// in browsers, so this connects to relay servers or uses WebRTC.
class PeerConnectionWeb implements PeerConnection {
  /// Creates a web peer connection.
  PeerConnectionWeb() {
    _localPeerId = 'web_peer_${DateTime.now().millisecondsSinceEpoch}';
  }

  final Map<String, web.WebSocket> _sockets = {};
  final _messagesController = StreamController<PeerMessage>.broadcast();
  late final String _localPeerId;
  bool _disposed = false;

  @override
  Future<void> connect(String multiaddr) async {
    // Parse multiaddr to extract WebSocket URL
    // For now, only support ws:// or wss:// URLs directly
    if (!multiaddr.startsWith('ws://') && !multiaddr.startsWith('wss://')) {
      throw ArgumentError('Web platform only supports WebSocket multiaddrs');
    }

    final socket = web.WebSocket(multiaddr);
    socket.binaryType = 'arraybuffer';

    final completer = Completer<void>();

    socket.onopen = ((web.Event event) {
      _sockets[multiaddr] = socket;
      if (!completer.isCompleted) completer.complete();
    }).toJS;

    socket.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('WebSocket connection failed'));
      }
    }).toJS;

    socket.onmessage = ((web.MessageEvent event) {
      _handleMessage(multiaddr, event);
    }).toJS;

    socket.onclose = ((web.CloseEvent event) {
      _sockets.remove(multiaddr);
    }).toJS;

    await completer.future;
  }

  void _handleMessage(String peerId, web.MessageEvent event) {
    if (_disposed) return;

    try {
      final data = event.data;
      Uint8List bytes;

      if (data is JSArrayBuffer) {
        bytes = Uint8List.view(data.toDart);
      } else {
        // Handle string data
        bytes = Uint8List.fromList((data as JSString).toDart.codeUnits);
      }

      _messagesController.add(PeerMessage(peerId: peerId, data: bytes));
    } catch (e) {
      // Log error but don't crash
    }
  }

  @override
  Future<void> disconnect(String peerId) async {
    final socket = _sockets.remove(peerId);
    socket?.close();
  }

  @override
  Future<void> send(String peerId, Uint8List message) async {
    final socket = _sockets[peerId];
    if (socket != null && socket.readyState == web.WebSocket.OPEN) {
      socket.send(message.buffer.toJS);
    } else {
      throw StateError('Not connected to peer: $peerId');
    }
  }

  @override
  Future<void> broadcast(Uint8List message) async {
    for (final socket in _sockets.values) {
      if (socket.readyState == web.WebSocket.OPEN) {
        socket.send(message.buffer.toJS);
      }
    }
  }

  @override
  Stream<PeerMessage> get messages => _messagesController.stream;

  @override
  List<String> get connectedPeers => _sockets.keys.toList();

  @override
  bool isConnected(String peerId) => _sockets.containsKey(peerId);

  @override
  String get localPeerId => _localPeerId;

  @override
  void dispose() {
    if (!_disposed) {
      for (final socket in _sockets.values) {
        socket.close();
      }
      _sockets.clear();
      _messagesController.close();
      _disposed = true;
    }
  }
}

/// Factory function for web platform.
PeerConnection createPeerConnection(dynamic router) => PeerConnectionWeb();
