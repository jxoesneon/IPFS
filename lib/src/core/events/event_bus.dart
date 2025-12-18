import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';

/// A type-safe publish-subscribe event bus for IPFS network events.
///
/// EventBus enables decoupled communication between components by allowing
/// publishers to emit events without knowing their subscribers. Each event
/// type has its own broadcast stream, enabling multiple listeners.
///
/// Example:
/// ```dart
/// final bus = EventBus();
///
/// // Subscribe to peer connections
/// bus.subscribe<PeerConnectedEvent>().listen((event) {
///   // print('Peer connected: ${event.peerId}');
/// });
///
/// // Publish an event
/// bus.publish(PeerConnectedEvent(peerId: 'Qm...', address: '/ip4/...'));
/// ```
///
/// See also:
/// - [NetworkEvent] for the base event class
/// - [PeerConnectedEvent], [BlockTransferEvent] for specific event types
class EventBus {
  final _logger = Logger('EventBus');
  final _controllers = <Type, StreamController<dynamic>>{};

  /// Publishes an event to all subscribers
  void publish<T>(T event) {
    final controller = _controllers[T] as StreamController<T>?;
    if (controller != null) {
      controller.add(event);
      _logger.debug('Published ${T.toString()} event');
    }
  }

  /// Subscribes to events of type T
  Stream<T> subscribe<T>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    return (_controllers[T] as StreamController<T>).stream;
  }

  /// Disposes all event streams
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

/// Base class for all network events
abstract class NetworkEvent {
  final DateTime timestamp = DateTime.now();
}

/// Event for peer connections
class PeerConnectedEvent extends NetworkEvent {

  PeerConnectedEvent({required this.peerId, required this.address});
  final String peerId;
  final String address;
}

/// Event for block transfers
class BlockTransferEvent extends NetworkEvent {

  BlockTransferEvent({
    required this.cid,
    required this.peerId,
    required this.type,
    required this.size,
  });
  final String cid;
  final String peerId;
  final TransferType type;
  final int size;
}

enum TransferType { received, sent }
