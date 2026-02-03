import 'dart:async';

/// Interface for PubSub operations to allow platform-agnostic implementations.
abstract class IPubSub {
  /// Subscribes to a topic.
  Future<void> subscribe(String topic);

  /// Unsubscribes from a topic.
  Future<void> unsubscribe(String topic);

  /// Publishes a message to a topic.
  Future<void> publish(String topic, String message);

  /// Listens for messages on a specific topic.
  void onMessage(String topic, void Function(String) handler);
}

