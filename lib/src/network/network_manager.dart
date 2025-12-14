import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/events/network_events.dart';
import 'package:dart_ipfs/src/core/messages/network_messages.dart';
import 'package:dart_ipfs/src/core/protocol_handlers/protocol_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' show Message;

/// Manages network message routing and protocol handler dispatch.
///
/// NetworkManager sits between the P2P transport layer and protocol
/// handlers, routing incoming messages to the appropriate handler
/// based on protocol type and emitting network events.
///
/// Example:
/// ```dart
/// final manager = NetworkManager(router);
/// manager.events.listen((event) {
///   print('Network event: $event');
/// });
/// ```
///
/// See also:
/// - [P2plibRouter] for the underlying transport
/// - [ProtocolHandler] for message handling interface
class NetworkManager {
  final P2plibRouter _router;
  final Map<String, ProtocolHandler> _protocolHandlers = {};
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  /// Creates a network manager with the given [_router].
  NetworkManager(this._router) {
    _setupMessageHandling();
  }

  void _setupMessageHandling() {
    _router.onMessage((Message message) async {
      try {
        final blocks = message.getBlocks();
        final baseMessage = BitSwapMessage(
            blocks.isNotEmpty ? blocks.first.data : Uint8List(0), 'receive');

        final handler = _protocolHandlers[baseMessage.protocol];
        if (handler != null) {
          await handler.handleMessage(baseMessage);
        }
      } catch (e) {
        print('Error handling message: $e');
      }
    });
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
