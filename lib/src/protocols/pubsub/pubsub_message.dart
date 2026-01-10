/// Represents a message published on a PubSub topic.
class PubSubMessage {
  /// Creates a PubSub message.
  PubSubMessage({required this.topic, required this.content, required this.sender});

  /// The topic this message was published to.
  final String topic;

  /// The message content.
  final String content;

  /// The sender's peer ID.
  final String sender;

  @override
  String toString() => 'PubSubMessage(topic: $topic, sender: $sender, content: $content)';
}
