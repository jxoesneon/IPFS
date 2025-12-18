class PubSubMessage {

  PubSubMessage({
    required this.topic,
    required this.content,
    required this.sender,
  });
  final String topic;
  final String content;
  final String sender;

  @override
  String toString() =>
      'PubSubMessage(topic: $topic, sender: $sender, content: $content)';
}
