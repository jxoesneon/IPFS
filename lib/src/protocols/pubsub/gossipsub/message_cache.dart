import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gossipsub.pb.dart';

/// Cache of recently seen Gossipsub messages per topic.
///
/// Implements the message-history cache required by Gossipsub v1.1 for
/// duplicate suppression and serving [IWANT] requests. Message IDs are
/// computed as SHA-256 of `from || seqno || topic || data` per the project
/// spec.
class MessageCache {
  /// Creates a cache with a per-topic [capacity].
  MessageCache({this.capacity = 128});

  /// Maximum number of messages retained per topic.
  final int capacity;

  final Map<String, List<_CachedMessage>> _cache = {};
  final Set<String> _seenIds = {};

  /// Records a message in the cache, evicting the oldest messages for the
  /// topic if [capacity] is exceeded.
  void add(Message message) {
    final topic = message.topic;
    if (topic.isEmpty) return;

    final id = messageId(message);
    if (_seenIds.contains(id)) return;

    _seenIds.add(id);
    final list = _cache.putIfAbsent(topic, () => <_CachedMessage>[]);
    list.add(_CachedMessage(id, message));

    while (list.length > capacity) {
      final removed = list.removeAt(0);
      _seenIds.remove(removed.id);
    }
  }

  /// Returns `true` if [message] has been seen before.
  bool contains(Message message) {
    return _seenIds.contains(messageId(message));
  }

  /// Returns `true` if the message ID [id] has been seen before.
  bool containsId(String id) {
    return _seenIds.contains(id);
  }

  /// Returns the message IDs known for [topic], ordered from oldest to newest.
  List<String> messageIdsForTopic(String topic) {
    return _cache[topic]?.map((e) => e.id).toList() ?? [];
  }

  /// Returns the most recent [count] message IDs for [topic], newest first.
  List<String> recentMessageIds(String topic, int count) {
    final list = _cache[topic];
    if (list == null || list.isEmpty) return [];
    final result = list.reversed.map((e) => e.id).take(count).toList();
    return result;
  }

  /// Returns the messages matching any of the requested [ids] for [topic].
  List<Message> getForIWant(String topic, List<String> ids) {
    final list = _cache[topic];
    if (list == null) return [];

    final result = <Message>[];
    final idSet = ids.toSet();
    for (final entry in list) {
      if (idSet.contains(entry.id)) {
        result.add(entry.message);
        idSet.remove(entry.id);
        if (idSet.isEmpty) break;
      }
    }
    return result;
  }

  /// Clears all cached messages.
  void clear() {
    _cache.clear();
    _seenIds.clear();
  }

  /// Computes the canonical message ID for a [message].
  static String messageId(Message message) {
    final digest = sha256.convert([
      ...message.from,
      ...message.seqno,
      ...utf8.encode(message.topic),
      ...message.data,
    ]);
    return digest.toString();
  }
}

class _CachedMessage {
  _CachedMessage(this.id, this.message);

  final String id;
  final Message message;
}
