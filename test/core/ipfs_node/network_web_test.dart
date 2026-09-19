import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler_web.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'network_web_test.mocks.dart';

@GenerateMocks([RouterInterface, IPFSNode])
void main() {
  group('NetworkHandler Web Implementation', () {
    late NetworkHandler handler;
    late MockRouterInterface mockRouter;
    late MockIPFSNode mockIPFSNode;
    late IPFSConfig config;

    setUp(() {
      mockRouter = MockRouterInterface();
      when(mockRouter.peerID).thenReturn('web_node');
      when(mockRouter.start()).thenAnswer((_) async {});
      when(mockRouter.stop()).thenAnswer((_) async {});
      when(mockRouter.initialize()).thenAnswer((_) async {});
      when(mockRouter.connect(any)).thenAnswer((_) async {});
      when(mockRouter.disconnect(any)).thenAnswer((_) async {});
      when(mockRouter.listConnectedPeers()).thenReturn(<String>[]);
      when(mockRouter.sendMessage(any, any)).thenAnswer((_) async {});
      when(
        mockRouter.receiveMessages(any),
      ).thenAnswer((_) => const Stream<Uint8List>.empty());
      mockIPFSNode = MockIPFSNode();
      config = IPFSConfig();
      handler = NetworkHandler(config, router: mockRouter);
      handler.setIpfsNode(mockIPFSNode);
    });

    test('delegates lifecycle and messaging to the router', () async {
      await handler.start();
      verify(mockRouter.start()).called(1);

      await handler.stop();
      verify(mockRouter.stop()).called(1);

      await handler.initialize();
      verify(mockRouter.initialize()).called(1);

      expect(handler.networkEvents, isA<Stream>());

      await handler.connectToPeer('addr');
      verify(mockRouter.connect('addr')).called(1);

      await handler.disconnectFromPeer('addr');
      verify(mockRouter.disconnect('addr')).called(1);

      when(mockRouter.listConnectedPeers()).thenReturn(<String>['peer1']);
      final peers = await handler.listConnectedPeers();
      expect(peers, equals(<String>['peer1']));

      await handler.sendMessage('peer', 'msg');
      verify(mockRouter.sendMessage('peer', any)).called(1);

      when(
        mockRouter.receiveMessages('peer'),
      ).thenAnswer((_) => Stream.value(utf8.encode('hello')));
      final messages = handler.receiveMessages('peer');
      expect(await messages.first, equals('hello'));

      expect(handler.router, equals(mockRouter));
      expect(handler.circuitRelayClient, isNull);
      expect(handler.config, equals(config));
      expect(handler.peerID, equals('web_node'));
      expect(handler.ipfsNode, equals(mockIPFSNode));
    });

    test('reports honest negatives for browser-impossible features', () async {
      // Browsers cannot accept inbound connections or run AutoNAT dialback.
      expect(await handler.canConnectDirectly('addr'), isFalse);
      expect(await handler.testConnection(sourcePort: 4001), isEmpty);
      expect(await handler.testDialback(), isFalse);
      expect(handler.circuitRelayClient, isNull);
    });

    test('sendRequest delegates to the router', () async {
      when(
        mockRouter.sendRequest('peer', '/proto', any),
      ).thenAnswer((_) async => Uint8List.fromList(<int>[1, 2, 3]));

      final response = await handler.sendRequest(
        'peer',
        '/proto',
        Uint8List(0),
      );

      expect(response, equals(Uint8List.fromList(<int>[1, 2, 3])));
      verify(mockRouter.sendRequest('peer', '/proto', any)).called(1);
    });

    test('sendRequest returns null when the router reports failure', () async {
      when(mockRouter.sendRequest(any, any, any)).thenAnswer((_) async => null);

      expect(await handler.sendRequest('peer', '/proto', Uint8List(0)), isNull);
    });

    test('defaults to Libp2pRouter with configured seed', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i + 3));
      final seeded = NetworkHandler(
        IPFSConfig(
          libp2pIdentitySeed: seed,
          network: NetworkConfig(bootstrapPeers: []),
        ),
      );
      expect(seeded.router, isA<RouterInterface>());
    });
  });
}
