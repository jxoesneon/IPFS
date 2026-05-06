import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler_io.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'network_impl_test.mocks.dart';

@GenerateMocks([
  RouterInterface,
  IPFSNode,
  DHTHandler,
  DHTClient,
  KademliaRoutingTable,
])
void main() {
  group('NetworkHandler IO Implementation', () {
    late NetworkHandler handler;
    late MockRouterInterface mockRouter;
    late MockIPFSNode mockIPFSNode;
    late MockDHTHandler mockDHTHandler;
    late MockDHTClient mockDHTClient;
    late MockKademliaRoutingTable mockRoutingTable;
    late IPFSConfig config;
    late StreamController<ConnectionEvent> connectionEventsController;
    late StreamController<MessageEvent> messageEventsController;

    setUp(() async {
      mockRouter = MockRouterInterface();
      mockIPFSNode = MockIPFSNode();
      mockDHTHandler = MockDHTHandler();
      mockDHTClient = MockDHTClient();
      mockRoutingTable = MockKademliaRoutingTable();

      config = IPFSConfig(
        network: NetworkConfig(
          bootstrapPeers: ['/ip4/127.0.0.1/tcp/4001/p2p/QmBootstrap'],
        ),
        debug: true,
      );

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
      when(mockRouter.start()).thenAnswer((_) async {});
      when(mockRouter.stop()).thenAnswer((_) async {});

      when(mockIPFSNode.dhtHandler).thenReturn(mockDHTHandler);
      when(mockDHTHandler.dhtClient).thenReturn(mockDHTClient);
      when(mockDHTClient.kademliaRoutingTable).thenReturn(mockRoutingTable);

      handler = NetworkHandler(config, router: mockRouter);
      handler.setIpfsNode(mockIPFSNode);
      await handler.initialize();
    });

    tearDown(() async {
      await connectionEventsController.close();
      await messageEventsController.close();
    });

    test('Initialization and start', () async {
      await handler.start();
      verify(
        mockRouter.start(),
      ).called(1); // once by handler, once by circuitRelayClient
      verify(mockRouter.registerProtocolHandler(any, any)).called(2);
    });

    test('Stop cancels subscriptions and closes controller', () async {
      await handler.start();
      await handler.stop();
      verify(mockRouter.start()).called(1);
      expect(handler.networkEvents, emitsDone);
    });

    test('peerConnected updates routing table', () async {
      final event = ConnectionEvent(
        type: ConnectionEventType.connected,
        peerId: 'peer1',
      );

      connectionEventsController.add(event);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 50));

      verify(mockRoutingTable.addPeer(any, any)).called(1);
    });

    test('peerDisconnected removes from routing table', () async {
      final event = ConnectionEvent(
        type: ConnectionEventType.disconnected,
        peerId: 'peer1',
      );

      connectionEventsController.add(event);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 50));

      verify(mockRoutingTable.removePeer(any)).called(1);
    });

    test('messageReceived event', () async {
      final event = MessageEvent(
        peerId: 'peer1',
        message: Uint8List.fromList(utf8.encode('hello')),
      );

      messageEventsController.add(event);

      final networkEvent = await handler.networkEvents.first;
      expect(networkEvent.hasMessageReceived(), isTrue);
      expect(networkEvent.messageReceived.peerId, equals('peer1'));
      expect(
        utf8.decode(networkEvent.messageReceived.messageContent),
        equals('hello'),
      );
    });

    test('testDialback success', () async {
      when(mockRouter.connect(any)).thenAnswer((_) async {});
      when(mockRouter.disconnect(any)).thenAnswer((_) async {});
      when(
        mockRouter.sendRequest(any, any, any),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final result = await handler.testDialback();
      expect(result, isTrue);
      verify(mockRouter.connect(any)).called(1);
      verify(
        mockRouter.sendRequest(any, '/ipfs/autonat/1.0.0/dialback', any),
      ).called(1);
    });

    test('testDialback failure on sendRequest', () async {
      when(mockRouter.connect(any)).thenAnswer((_) async {});
      when(mockRouter.disconnect(any)).thenAnswer((_) async {});
      when(mockRouter.sendRequest(any, any, any)).thenAnswer((_) async => null);

      final result = await handler.testDialback();
      expect(result, isFalse);
    });

    test('dialback protocol handler', () async {
      await handler.start();

      // We need to capture the handler registered
      late void Function(NetworkPacket) dialbackHandler;

      verify(
        mockRouter.registerProtocolHandler(
          '/ipfs/autonat/1.0.0/dialback',
          captureAny,
        ),
      ).captured.forEach((h) {
        dialbackHandler = h;
      });

      final requestId = '1234567890123'; // 13 chars
      final packet = NetworkPacket(
        srcPeerId: 'remote-peer',
        datagram: Uint8List.fromList(utf8.encode('some-data' + requestId)),
      );

      dialbackHandler(packet);

      verify(
        mockRouter.sendMessage(
          'remote-peer',
          any,
          protocolId: '/ipfs/autonat/1.0.0/dialback',
        ),
      ).called(1);
    });

    test('canConnectDirectly', () async {
      when(mockRouter.connect(any)).thenAnswer((_) async {});
      when(mockRouter.disconnect(any)).thenAnswer((_) async {});

      final result = await handler.canConnectDirectly('addr');
      expect(result, isTrue);
    });

    test('canConnectDirectly failure', () async {
      when(mockRouter.connect(any)).thenThrow(Exception('Connect failed'));

      final result = await handler.canConnectDirectly('addr');
      expect(result, isFalse);
    });

    test('sendMessage error handling', () async {
      when(
        mockRouter.sendMessage(any, any),
      ).thenThrow(Exception('Send failed'));
      // Should not throw
      await handler.sendMessage('peer1', 'msg');
      verify(mockRouter.sendMessage('peer1', any)).called(1);
    });

    test('receiveMessages error handling', () async {
      when(
        mockRouter.receiveMessages(any),
      ).thenThrow(Exception('Stream failed'));
      final stream = handler.receiveMessages('peer1');
      expect(await stream.isEmpty, isTrue);
    });

    test('dhtRouter getter', () {
      expect(handler.dhtRouter, isNotNull);
    });

    test('circuitRelayClient getter', () {
      expect(handler.circuitRelayClient, isNotNull);
    });

    test('config getter', () {
      expect(handler.config, equals(config));
    });

    test('peerID getter', () {
      expect(handler.peerID, equals('local-peer-id'));
    });

    test('receiveMessages success', () async {
      final controller = StreamController<Uint8List>();
      when(
        mockRouter.receiveMessages('peer1'),
      ).thenAnswer((_) => controller.stream);

      final stream = handler.receiveMessages('peer1');
      controller.add(Uint8List.fromList(utf8.encode('hello')));

      expect(await stream.first, equals('hello'));
      await controller.close();
    });
  });
}
