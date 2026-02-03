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

/// Base class for all network events.
abstract class NetworkEvent {
  /// The timestamp when the event occurred.
  final DateTime timestamp = DateTime.now();
}

/// Event emitted when a peer connects.
class PeerConnectedEvent extends NetworkEvent {
  /// Creates a peer connected event.
  PeerConnectedEvent({required this.peerId, required this.address});

  /// The newly connected peer's ID.
  final String peerId;

  /// The multiaddr of the peer.
  final String address;
}

/// Event emitted when a block is transferred.
class BlockTransferEvent extends NetworkEvent {
  /// Creates a block transfer event.
  BlockTransferEvent({
    required this.cid,
    required this.peerId,
    required this.type,
    required this.size,
  });

  /// The CID of the transferred block.
  final String cid;

  /// The peer involved in the transfer.
  final String peerId;

  /// Whether this was a send or receive.
  final TransferType type;

  /// The size of the block in bytes.
  final int size;
}

/// Direction of a block transfer.
enum TransferType {
  /// Block was received from a peer.
  received,

  /// Block was sent to a peer.
  sent,
}
