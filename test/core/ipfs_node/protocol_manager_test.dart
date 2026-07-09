import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/protocol_manager.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';

import 'protocol_manager_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ServiceContainer>(),
  MockSpec<PubSubHandler>(),
  MockSpec<DHTHandler>(),
  MockSpec<ContentRoutingHandler>(),
])
void main() {
  late ProtocolManager manager;
  late MockServiceContainer mockContainer;
  late MockPubSubHandler mockPubSubHandler;
  late MockDHTHandler mockDHTHandler;
  late MockContentRoutingHandler mockContentRoutingHandler;

  setUp(() {
    mockContainer = MockServiceContainer();
    mockPubSubHandler = MockPubSubHandler();
    mockDHTHandler = MockDHTHandler();
    mockContentRoutingHandler = MockContentRoutingHandler();
  });

  group('ProtocolManager', () {
    test('subscribe/unsubscribe delegating', () async {
      manager = ProtocolManager(pubSubHandler: mockPubSubHandler);
      await manager.subscribe('topic1');
      verify(mockPubSubHandler.subscribe('topic1')).called(1);

      await manager.unsubscribe('topic1');
      verify(mockPubSubHandler.unsubscribe('topic1')).called(1);
    });

    test('publish delegating', () async {
      manager = ProtocolManager(pubSubHandler: mockPubSubHandler);
      await manager.publish('topic1', 'msg');
      verify(mockPubSubHandler.publish('topic1', 'msg')).called(1);
    });

    test('pubsubMessages stream', () {
      manager = ProtocolManager(pubSubHandler: mockPubSubHandler);
      when(mockPubSubHandler.messages).thenAnswer((_) => Stream.empty());

      expect(manager.pubsubMessages, isA<Stream<PubSubMessage>>());
    });

    test('resolveIPNS and publishIPNS delegating', () async {
      manager = ProtocolManager(dhtHandler: mockDHTHandler);
      when(mockDHTHandler.resolveIPNS('name')).thenAnswer((_) async => 'cid');

      final result = await manager.resolveIPNS('name');
      expect(result, equals('/ipfs/cid'));

      await manager.publishIPNS('cid', keyName: 'self');
      verify(mockDHTHandler.publishIPNS('cid', keyName: 'self')).called(1);
    });

    test('publish throws if PubSubHandler not registered', () async {
      manager = ProtocolManager();
      expect(() => manager.publish('topic', 'msg'), throwsA(isA<StateError>()));
    });

    test('resolveIPNS throws if DHTHandler not registered', () async {
      manager = ProtocolManager();
      expect(() => manager.resolveIPNS('name'), throwsA(isA<StateError>()));
    });

    test('publishIPNS throws if DHTHandler not registered', () async {
      manager = ProtocolManager();
      expect(
        () => manager.publishIPNS('cid', keyName: 'self'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'resolveDNSLink throws if resolution fails in both handlers',
      () async {
        manager = ProtocolManager(
          contentRoutingHandler: mockContentRoutingHandler,
          dhtHandler: mockDHTHandler,
        );
        when(
          mockContentRoutingHandler.resolveDNSLink('domain'),
        ).thenAnswer((_) async => null);
        when(
          mockDHTHandler.resolveDNSLink('domain'),
        ).thenAnswer((_) async => null);

        expect(() => manager.resolveDNSLink('domain'), throwsStateError);
      },
    );
  });
}
