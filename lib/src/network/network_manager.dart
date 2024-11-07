import '../core/types/p2p_types.dart';
import '../core/events/network_events.dart';
import '../core/messages/network_messages.dart';

class NetworkManager {
  final P2plibRouter _router;
  final Map<String, ProtocolHandler> _protocolHandlers = {};
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  NetworkManager(this._router) {
    _setupMessageHandling();
  }

  void _setupMessageHandling() {
    _router.onMessage((message) {
      final handler = _protocolHandlers[message.protocol];
      if (handler != null) {
        handler.handleMessage(message);
      }
    });
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
