// test/protocols/pubsub/pubsub_interface_test.dart
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_interface.dart';
import 'package:test/test.dart';

/// Minimal [IPubSub] subclass that implements only the abstract members and
/// inherits the default introspection member bodies.
class _Stub extends IPubSub {
  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> unsubscribe(String topic) async {}

  @override
  Future<void> publish(String topic, String message) async {}

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
  });
}
