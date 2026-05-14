import 'dart:async';
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
      mockIPFSNode = MockIPFSNode();
      config = IPFSConfig();
      handler = NetworkHandler(config, router: mockRouter);
      handler.setIpfsNode(mockIPFSNode);
    });

    test('All stubs should be callable', () async {
      await handler.start();
      await handler.stop();
      await handler.initialize();

      expect(handler.networkEvents, isA<Stream>());

      await handler.connectToPeer('addr');
      await handler.disconnectFromPeer('addr');

      final peers = await handler.listConnectedPeers();
      expect(peers, isEmpty);

      await handler.sendMessage('peer', 'msg');

      final messages = handler.receiveMessages('peer');
      expect(await messages.isEmpty, isTrue);

      expect(handler.router, equals(mockRouter));
      expect(handler.circuitRelayClient, isNull);
      expect(handler.config, equals(config));
      expect(handler.peerID, equals('web_node'));

      expect(await handler.canConnectDirectly('addr'), isFalse);
      expect(await handler.testConnection(sourcePort: 4001), isEmpty);
      expect(await handler.testDialback(), isFalse);
    });

    test('sendRequest throws UnimplementedError', () async {
      expect(
        () => handler.sendRequest('peer', '/proto', Uint8List(0)),
        throwsUnimplementedError,
      );
    });
  });
}
