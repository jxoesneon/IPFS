import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';

import 'network_events_test.mocks.dart';

import 'package:dart_ipfs/src/transport/router_events.dart';

@GenerateMocks([CircuitRelayClient, P2plibRouter])
void main() {
  group('IpfsNodeNetworkEvents', () {
    late IpfsNodeNetworkEvents networkEvents;
    late MockCircuitRelayClient mockRelayClient;
    late MockP2plibRouter mockRouter;

    // Controllers to emit events from mocks
    late StreamController<ConnectionEvent> routerConnectionController;
    late StreamController<MessageEvent> routerMessageController;
    late StreamController<DHTEvent> routerDhtController;
    late StreamController<PubSubEvent> routerPubSubController;
    late StreamController<StreamEvent> routerStreamController;
    late StreamController<ErrorEvent> routerErrorController;
    late StreamController<CircuitRelayConnectionEvent> relayEventController;

    setUp(() {
      mockRelayClient = MockCircuitRelayClient();
      mockRouter = MockP2plibRouter();

      routerConnectionController =
          StreamController<ConnectionEvent>.broadcast();
      routerMessageController = StreamController<MessageEvent>.broadcast();
      routerDhtController = StreamController<DHTEvent>.broadcast();
      routerPubSubController = StreamController<PubSubEvent>.broadcast();
      routerStreamController = StreamController<StreamEvent>.broadcast();
      routerErrorController = StreamController<ErrorEvent>.broadcast();
      relayEventController =
          StreamController<CircuitRelayConnectionEvent>.broadcast();

      when(
        mockRouter.connectionEvents,
      ).thenAnswer((_) => routerConnectionController.stream);
      when(
        mockRouter.messageEvents,
      ).thenAnswer((_) => routerMessageController.stream);
      when(mockRouter.dhtEvents).thenAnswer((_) => routerDhtController.stream);
      when(
        mockRouter.pubSubEvents,
      ).thenAnswer((_) => routerPubSubController.stream);
      when(
        mockRouter.streamEvents,
      ).thenAnswer((_) => routerStreamController.stream);
      when(
        mockRouter.errorEvents,
      ).thenAnswer((_) => routerErrorController.stream);
      when(
        mockRelayClient.connectionEvents,
      ).thenAnswer((_) => relayEventController.stream);

      networkEvents = IpfsNodeNetworkEvents(mockRelayClient, mockRouter);
      networkEvents.start();
    });

    tearDown(() {
      networkEvents.dispose();
      routerConnectionController.close();
      routerMessageController.close();
      routerDhtController.close();
      routerPubSubController.close();
      routerStreamController.close();
      routerErrorController.close();
      relayEventController.close();
    });

    test('re-emits connection events', () async {
      final expectation = networkEvents.networkEvents.first;

      final routerEvent = ConnectionEvent(
        type: ConnectionEventType.connected,
        peerId: 'peer1',
      );
      routerConnectionController.add(routerEvent);

      final result = await expectation;
      expect(result.hasPeerConnected(), isTrue);
      expect(result.peerConnected.peerId, 'peer1');
    });

    test('re-emits message events', () async {
      final expectation = networkEvents.networkEvents.first;

      final routerEvent = MessageEvent(
        peerId: 'peer1',
        message: Uint8List.fromList([1, 2, 3]),
      );
      routerMessageController.add(routerEvent);

      final result = await expectation;
      expect(result.hasMessageReceived(), isTrue);
      expect(result.messageReceived.messageContent, [1, 2, 3]);
    });

    test('re-emits pubsub events', () async {
      final expectation = networkEvents.networkEvents.first;

      final routerEvent = PubSubEvent(
        eventType: 'pubsub_message_received',
        topic: 'news',
        message: Uint8List.fromList([4, 5]),
        publisher: 'alice',
      );
      routerPubSubController.add(routerEvent);

      final result = await expectation;
      expect(result.hasPubsubMessageReceived(), isTrue);
      expect(result.pubsubMessageReceived.topic, 'news');
    });

    test('re-emits error events', () async {
      final expectation = networkEvents.networkEvents.first;

      final routerEvent = ErrorEvent(
        type: ErrorEventType.connectionError,
        message: 'failed',
      );
      routerErrorController.add(routerEvent);

      final result = await expectation;
      expect(result.hasError(), isTrue);
      // Logic in IpfsNodeNetworkEvents maps any error to UNKNOWN currently except for hardcoded strings
      // Wait, let's check mapping logic.
      expect(result.error.message, 'failed');
    });
  });
}
