import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Type-safe event bus for IPFS network events
class EventBus {
  final _logger = Logger('EventBus');
  final _controllers = <Type, StreamController>{};

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
  final String peerId;
  final String address;

  PeerConnectedEvent({
    required this.peerId,
    required this.address,
  });
}

/// Event for block transfers
class BlockTransferEvent extends NetworkEvent {
  final String cid;
  final String peerId;
  final TransferType type;
  final int size;

  BlockTransferEvent({
    required this.cid,
    required this.peerId,
    required this.type,
    required this.size,
  });
}

enum TransferType { received, sent }
