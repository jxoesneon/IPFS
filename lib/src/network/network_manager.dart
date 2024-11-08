import 'dart:async';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/events/network_events.dart';
import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:dart_ipfs/src/core/protocol_handlers/protocol_handler.dart';

class NetworkManager {
  final P2plibRouter _router;
  final Map<String, ProtocolHandler> _protocolHandlers = {};
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  NetworkManager(this._router) {
    _setupMessageHandling();
  }

  void _setupMessageHandling() {
    _router.onMessage((BaseMessage message) {
      final handler = _protocolHandlers[message.protocol];
      if (handler != null) {
        handler.handleMessage(message);
      }
    });
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
