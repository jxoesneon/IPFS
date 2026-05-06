import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';

import 'ipfs_node_network_events_test.mocks.dart';

@GenerateNiceMocks([MockSpec<RouterInterface>()])
void main() {
  late IpfsNodeNetworkEvents events;
  late MockRouterInterface mockRouter;

  setUp(() {
    mockRouter = MockRouterInterface();
    when(mockRouter.connectionEvents).thenAnswer((_) => Stream.empty());
    events = IpfsNodeNetworkEvents(mockRouter);
  });

  group('IpfsNodeNetworkEvents', () {
    test('start and connection events', () async {
      final connController = StreamController<ConnectionEvent>();
      when(
        mockRouter.connectionEvents,
      ).thenAnswer((_) => connController.stream);

      events.start();

      final receivedFuture = events.networkEvents.first;
      connController.add(
        ConnectionEvent(peerId: 'p1', type: ConnectionEventType.connected),
      );

      final received = await receivedFuture;
      expect(received.hasPeerConnected(), isTrue);
      expect(received.peerConnected.peerId, equals('p1'));

      await connController.close();
    });

    test('disconnected event', () async {
      final connController = StreamController<ConnectionEvent>();
      when(
        mockRouter.connectionEvents,
      ).thenAnswer((_) => connController.stream);

      events.start();

      final receivedFuture = events.networkEvents.first;
      connController.add(
        ConnectionEvent(peerId: 'p1', type: ConnectionEventType.disconnected),
      );

      final received = await receivedFuture;
      expect(received.hasPeerDisconnected(), isTrue);

      await connController.close();
    });

    test('dispose', () {
      events.dispose();
      // Should not throw
    });
  });
}
