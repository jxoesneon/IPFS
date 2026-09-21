import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:test/test.dart';

void main() {
  group('PubSubMessage', () {
    test('constructs with provided fields', () {
      final msg = PubSubMessage(topic: 't', content: 'hello', sender: 'p1');
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

    test('data defaults to the UTF-8 encoding of content', () {
      final msg = PubSubMessage(topic: 't', content: 'hello', sender: 'p1');
      expect(msg.data, equals(utf8.encode('hello')));
    });

    test('binary data is preserved while content decodes lossily', () {
      final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final msg = PubSubMessage(
        topic: 't',
        content: utf8.decode(payload, allowMalformed: true),
        sender: 'p1',
        data: payload,
      );
      expect(msg.data, equals(payload));
      // The String view replaces malformed sequences with U+FFFD, so it
      // must never be used as the source of truth for binary payloads.
      expect(utf8.encode(msg.content), isNot(equals(payload)));
    });
  });
}
