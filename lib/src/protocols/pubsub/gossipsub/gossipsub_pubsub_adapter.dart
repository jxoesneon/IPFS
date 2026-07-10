// lib/src/protocols/pubsub/gossipsub/gossipsub_pubsub_adapter.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../pubsub_interface.dart';
import 'gossipsub_handler.dart';

/// [IPubSub] adapter backed by the spec-compliant [GossipsubHandler].
///
/// This is a wiring stub that lets the rest of the node use the Gossipsub v1.1
/// implementation through the legacy [IPubSub] interface. String messages are
/// encoded as UTF-8 bytes for the wire and decoded back on delivery.
class GossipsubPubSubAdapter implements IPubSub {
  /// Creates an adapter around [handler].
  ///
  /// The adapter does not own the handler's lifecycle unless [manageLifecycle]
  /// is true, in which case [start] and [stop] are propagated.
  GossipsubPubSubAdapter(this._handler, {this.manageLifecycle = true});

  final GossipsubHandler _handler;

  /// Whether this adapter should [start] and [stop] the underlying handler.
  ///
  /// When false, the caller is responsible for the handler's lifecycle.
  final bool manageLifecycle;

  bool _started = false;

  final Map<String, StreamSubscription<GossipsubMessage>> _subscriptions = {};

  /// Starts the underlying Gossipsub handler if [manageLifecycle] is true.
  Future<void> start() async {
    if (manageLifecycle && !_started) {
      await _handler.start();
      _started = true;
    }
  }

  /// Stops the underlying Gossipsub handler if [manageLifecycle] is true.
  Future<void> stop() async {
    if (manageLifecycle && _started) {
      await _handler.stop();
      _started = false;
    }
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Future<void> subscribe(String topic) async {
    await _ensureStarted();
    return _handler.subscribe(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    final subscription = _subscriptions.remove(topic);
    await subscription?.cancel();
    return _handler.unsubscribe(topic);
  }

  @override
  Future<void> publish(String topic, String message) async {
    await _ensureStarted();
    return _handler.publish(topic, Uint8List.fromList(utf8.encode(message)));
  }

  @override
  void onMessage(String topic, void Function(String) handler) {
    if (_subscriptions.containsKey(topic)) {
      // A single topic stream is already being listened to; additional
      // listeners are multiplexed by the broadcast stream underlying
      // GossipsubHandler.onMessage, so we can rely on that.
    }
    final subscription = _handler.onMessage(topic).listen((message) {
      handler(utf8.decode(message.data));
    });
    _subscriptions[topic] = subscription;
  }

  Future<void> _ensureStarted() async {
    if (!manageLifecycle) return;
    if (!_started) {
      await _handler.start();
      _started = true;
    }
  }
}
