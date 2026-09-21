import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Interface for PubSub operations to allow platform-agnostic implementations.
abstract class IPubSub {
  /// Subscribes to a topic.
  Future<void> subscribe(String topic);

  /// Unsubscribes from a topic.
  Future<void> unsubscribe(String topic);

  /// Publishes a message to a topic.
  Future<void> publish(String topic, String message);

  /// Publishes a binary payload to a topic.
  ///
  /// Implementations that carry raw bytes on the wire (e.g. gossipsub)
  /// should override this. The default lossy-decodes [data] and delegates
  /// to [publish], matching historical String-only behavior.
  Future<void> publishData(String topic, Uint8List data) =>
      publish(topic, utf8.decode(data, allowMalformed: true));

  /// Listens for messages on a specific topic.
  void onMessage(String topic, void Function(String) handler);

  /// Returns the topics this node is currently subscribed to.
  ///
  /// Implementations that track subscriptions should override this getter;
  /// the default implementation returns an empty list.
  List<String> get subscribedTopics => const [];

  /// Returns the peers known to be subscribed to [topic].
  ///
  /// Implementations that track per-topic peers should override this
  /// method; the default implementation returns an empty set.
  Set<String> peersForTopic(String topic) => const {};
}
