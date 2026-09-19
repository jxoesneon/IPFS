import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';

import 'pubsub_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<RouterInterface>(), MockSpec<PubSubClient>()])
void main() {
  late PubSubHandler handler;
  late MockRouterInterface mockRouter;
  late MockPubSubClient mockPubSubClient;
  final peerId = 'QmID';

  setUp(() {
    mockRouter = MockRouterInterface();
    mockPubSubClient = MockPubSubClient();

    handler = PubSubHandler(mockRouter, peerId, pubSubClient: mockPubSubClient);
  });

  group('PubSubHandler', () {
    test('start and stop', () async {
      await handler.start();
      verify(mockPubSubClient.start()).called(1);

      await handler.stop();
      verify(mockPubSubClient.stop()).called(1);
    });

    test('bridges client messagesStream into messages', () async {
      final bridge = StreamController<PubSubMessage>();
      when(mockPubSubClient.messagesStream).thenAnswer((_) => bridge.stream);

      await handler.start();

      final receivedFuture = handler.messages.first;
      bridge.add(
        PubSubMessage(topic: 'topic1', content: 'hello', sender: 'peer1'),
      );

      final received = await receivedFuture;
      expect(received.content, equals('hello'));
      expect(received.topic, equals('topic1'));

      await bridge.close();
      await handler.stop();
    });

    test('subscribe and unsubscribe', () async {
      await handler.subscribe('topic1');
      verify(mockPubSubClient.subscribe('topic1')).called(1);

      await handler.unsubscribe('topic1');
      verify(mockPubSubClient.unsubscribe('topic1')).called(1);
    });

    test('publish success', () async {
      await handler.publish('topic1', 'msg');
      verify(mockPubSubClient.publish('topic1', 'msg')).called(1);

      final status = await handler.getStatus();
      expect(status['messages_published'], equals(1));
    });

    test('onMessage delegating', () {
      handler.onMessage('topic1', (msg) {});
      verify(mockPubSubClient.onMessage(any, any)).called(1);
    });

    test('resolveDNSLink fail', () async {
      final result = await handler.resolveDNSLink('missing.com');
      expect(result, isNull);
    });

    test('stats success', () async {
      when(mockPubSubClient.getNodeStats()).thenAnswer(
        (_) async => NodeStats(
          numBlocks: 0,
          datastoreSize: 0,
          numConnectedPeers: 0,
          bandwidthSent: 0,
          bandwidthReceived: 0,
        ),
      );
      final stats = await handler.stats();
      expect(stats, isNotNull);
    });

    test('getStatus with subscriptions', () async {
      await handler.subscribe('topic1');
      await handler.publish('topic1', 'msg');

      final status = await handler.getStatus();
      expect(status['subscribed_topics'], contains('topic1'));
      expect(status['messages_published'], equals(1));
    });

    test('start error propagates', () async {
      when(mockPubSubClient.start()).thenThrow(Exception('Start failed'));
      await expectLater(handler.start(), throwsException);
      verify(mockPubSubClient.start()).called(1);
    });

    test('stop error propagates', () async {
      when(mockPubSubClient.stop()).thenThrow(Exception('Stop failed'));
      await expectLater(handler.stop(), throwsException);
      verify(mockPubSubClient.stop()).called(1);
    });

    test('subscribe error propagates', () async {
      when(mockPubSubClient.subscribe(any)).thenThrow(Exception('Sub failed'));
      await expectLater(handler.subscribe('topic1'), throwsException);
      verify(mockPubSubClient.subscribe('topic1')).called(1);
    });

    test('unsubscribe error propagates', () async {
      when(
        mockPubSubClient.unsubscribe(any),
      ).thenThrow(Exception('Unsub failed'));
      await expectLater(handler.unsubscribe('topic1'), throwsException);
      verify(mockPubSubClient.unsubscribe('topic1')).called(1);
    });

    test('publish error propagates', () async {
      when(
        mockPubSubClient.publish(any, any),
      ).thenThrow(Exception('Pub failed'));
      await expectLater(handler.publish('topic1', 'msg'), throwsException);
      verify(mockPubSubClient.publish('topic1', 'msg')).called(1);
    });

    test('onMessage error propagates', () {
      when(
        mockPubSubClient.onMessage(any, any),
      ).thenThrow(Exception('onMessage failed'));
      expect(() => handler.onMessage('topic1', (msg) {}), throwsException);
      verify(mockPubSubClient.onMessage(any, any)).called(1);
    });

    test('stats error handling', () async {
      when(
        mockPubSubClient.getNodeStats(),
      ).thenThrow(Exception('Stats failed'));
      expect(() => handler.stats(), throwsException);
    });
  });
}
