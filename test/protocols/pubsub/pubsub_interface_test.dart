// test/protocols/pubsub/pubsub_interface_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/pubsub/pubsub_interface.dart';
import 'package:test/test.dart';

/// Minimal [IPubSub] subclass that implements only the abstract members and
/// inherits the default introspection member bodies.
class _Stub extends IPubSub {
  String? lastPublished;

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> unsubscribe(String topic) async {}

  @override
  Future<void> publish(String topic, String message) async {
    lastPublished = message;
  }

  @override
  void onMessage(String topic, void Function(String) handler) {}
}

void main() {
  group('IPubSub defaults', () {
    test('subscribedTopics defaults to an empty list', () {
      final stub = _Stub();
      expect(stub.subscribedTopics, isEmpty);
      expect(stub.subscribedTopics, isA<List<String>>());
    });

    test('peersForTopic defaults to an empty set', () {
      final stub = _Stub();
      expect(stub.peersForTopic('any-topic'), isEmpty);
      expect(stub.peersForTopic('any-topic'), isA<Set<String>>());
    });

    test('publishData defaults to a lossy UTF-8 publish', () async {
      final stub = _Stub();
      final payload = Uint8List.fromList([0x68, 0x69, 0x80, 0xFF]);
      await stub.publishData('topic', payload);
      expect(
        stub.lastPublished,
        equals(utf8.decode(payload, allowMalformed: true)),
      );
    });
  });
}
