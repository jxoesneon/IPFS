import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'network_handler_io_test.mocks.dart';

@GenerateMocks([RouterInterface, IPFSNode])
void main() {
  group('NetworkHandler', () {
    late NetworkHandler handler;
    late MockRouterInterface mockRouter;
    late MockIPFSNode mockIPFSNode;
    late IPFSConfig config;
    late StreamController<ConnectionEvent> connectionEventsController;
    late StreamController<MessageEvent> messageEventsController;

    setUp(() async {
      mockRouter = MockRouterInterface();
      mockIPFSNode = MockIPFSNode();
      config = IPFSConfig(network: NetworkConfig(bootstrapPeers: []));

      connectionEventsController =
          StreamController<ConnectionEvent>.broadcast();
      messageEventsController = StreamController<MessageEvent>.broadcast();

      when(
        mockRouter.connectionEvents,
      ).thenAnswer((_) => connectionEventsController.stream);
      when(
        mockRouter.messageEvents,
      ).thenAnswer((_) => messageEventsController.stream);
      when(mockRouter.peerID).thenReturn('local-peer-id');
      when(mockRouter.hasStarted).thenReturn(true);
      when(mockRouter.listeningAddresses).thenReturn([]);
      when(mockRouter.initialize()).thenAnswer((_) async {});

      handler = NetworkHandler(config, router: mockRouter);
      handler.setIpfsNode(mockIPFSNode);
      await handler.initialize();
    });

    tearDown(() {
      connectionEventsController.close();
      messageEventsController.close();
    });

    test('start and stop', () async {
      when(mockRouter.start()).thenAnswer((_) async {});
      when(mockRouter.stop()).thenAnswer((_) async {});

      await handler.start();
      // Called once by handler, once by circuitRelayClient (HOP + STOP), and once by AutoNAT dialback.
      verify(mockRouter.start()).called(1);
      verify(mockRouter.registerProtocolHandler(any, any)).called(3);

      await handler.stop();
      verify(mockRouter.stop()).called(1);
    });

    test('connectToPeer and disconnectFromPeer', () async {
      await handler.connectToPeer('addr');
      verify(mockRouter.connect('addr')).called(1);

      await handler.disconnectFromPeer('addr');
      verify(mockRouter.disconnect('addr')).called(1);
    });

    test('listConnectedPeers', () async {
      when(mockRouter.listConnectedPeers()).thenReturn(['peer1', 'peer2']);
      final peers = await handler.listConnectedPeers();
      expect(peers, equals(['peer1', 'peer2']));
    });

    test('sendMessage', () async {
      await handler.sendMessage('peer1', 'hello');
      verify(mockRouter.sendMessage('peer1', any)).called(1);
    });

    test('receiveMessages', () {
      final messageStream = StreamController<Uint8List>();
      when(
        mockRouter.receiveMessages('peer1'),
      ).thenAnswer((_) => messageStream.stream);

      final stream = handler.receiveMessages('peer1');
      expectLater(stream, emitsInOrder(['hello', 'world']));

      messageStream.add(Uint8List.fromList('hello'.codeUnits));
      messageStream.add(Uint8List.fromList('world'.codeUnits));
      messageStream.close();
    });

    test('handle connection event: connected', () async {
      final event = ConnectionEvent(
        type: ConnectionEventType.connected,
        peerId: 'peer1',
      );

      // Trigger the internal listener by adding to the controller
      connectionEventsController.add(event);

      // Verify networkEvents stream
      final networkEvent = await handler.networkEvents.first;
      expect(networkEvent.hasPeerConnected(), isTrue);
      expect(networkEvent.peerConnected.peerId, equals('peer1'));
    });

    test('handle connection event: disconnected', () async {
      final event = ConnectionEvent(
        type: ConnectionEventType.disconnected,
        peerId: 'peer1',
      );

      connectionEventsController.add(event);

      final networkEvent = await handler.networkEvents.first;
      expect(networkEvent.hasPeerDisconnected(), isTrue);
      expect(networkEvent.peerDisconnected.peerId, equals('peer1'));
    });

    test('handle message event', () async {
      final event = MessageEvent(
        peerId: 'peer1',
        message: Uint8List.fromList('hello'.codeUnits),
      );

      messageEventsController.add(event);

      final networkEvent = await handler.networkEvents.first;
      expect(networkEvent.hasMessageReceived(), isTrue);
      expect(networkEvent.messageReceived.peerId, equals('peer1'));
      expect(
        Uint8List.fromList(networkEvent.messageReceived.messageContent),
        equals(Uint8List.fromList('hello'.codeUnits)),
      );
    });

    test('sendRequest', () async {
      when(
        mockRouter.sendRequest(any, any, any),
      ).thenAnswer((_) async => Uint8List.fromList('response'.codeUnits));

      final response = await handler.sendRequest(
        'peer1',
        '/proto',
        Uint8List(0),
      );
      expect(response, equals(Uint8List.fromList('response'.codeUnits)));
      verify(mockRouter.sendRequest('peer1', '/proto', any)).called(1);
    });

    test('canConnectDirectly', () async {
      when(mockRouter.connect(any)).thenAnswer((_) async {});
      when(mockRouter.disconnect(any)).thenAnswer((_) async {});

      final can = await handler.canConnectDirectly('addr');
      expect(can, isTrue);
      verify(mockRouter.connect('addr')).called(1);
      verify(mockRouter.disconnect('addr')).called(1);
    });

    test('testDialback returns false when no bootstrap peers', () async {
      config.network.bootstrapPeers.clear();
      final result = await handler.testDialback();
      expect(result, isFalse);
    });
  });
}
