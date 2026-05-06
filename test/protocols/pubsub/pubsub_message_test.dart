import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:test/test.dart';

void main() {
  group('PubSubMessage', () {
    test('constructs with provided fields', () {
      final msg = PubSubMessage(
        topic: 't',
        content: 'hello',
        sender: 'p1',
      );
      expect(msg.topic, 't');
      expect(msg.content, 'hello');
      expect(msg.sender, 'p1');
    });

    test('toString includes all fields', () {
      final msg = PubSubMessage(topic: 't', content: 'c', sender: 's');
      final str = msg.toString();
      expect(str, contains('t'));
      expect(str, contains('c'));
      expect(str, contains('s'));
    });
  });
}
