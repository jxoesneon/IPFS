class PubSubMessage {
  final String topic;
  final String content;
  final String sender;

  PubSubMessage({
    required this.topic,
    required this.content,
    required this.sender,
  });

  @override
  String toString() =>
      'PubSubMessage(topic: $topic, sender: $sender, content: $content)';
}
