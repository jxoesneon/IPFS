import 'dart:convert';
import 'dart:typed_data';

/// Represents a message published on a PubSub topic.
class PubSubMessage {
  /// Creates a PubSub message.
  ///
  /// [content] is the lossy UTF-8 view of the payload; [data] carries the
  /// raw wire bytes. When [data] is omitted it defaults to the UTF-8
  /// encoding of [content] — supply both when the payload is not valid
  /// UTF-8 so binary payloads survive intact.
  PubSubMessage({
    required this.topic,
    required this.content,
    required this.sender,
    Uint8List? data,
  }) : data = data ?? Uint8List.fromList(utf8.encode(content));

  /// The topic this message was published to.
  final String topic;

  /// The message content, decoded as UTF-8 with malformed bytes replaced.
  ///
  /// Use [data] for the exact payload bytes.
  final String content;

  /// The raw payload bytes as carried on the wire.
  final Uint8List data;

  /// The sender's peer ID.
  final String sender;

  @override
  String toString() =>
      'PubSubMessage(topic: $topic, sender: $sender, content: $content)';
}
