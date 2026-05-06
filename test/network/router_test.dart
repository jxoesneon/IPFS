import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';

import 'router_test.mocks.dart';

@GenerateNiceMocks([MockSpec<RouterInterface>()])
void main() {
  late Router router;
  late MockRouterInterface mockInternalRouter;
  late IPFSConfig config;

  setUp(() {
    mockInternalRouter = MockRouterInterface();
    config = IPFSConfig();
    router = Router(config, router: mockInternalRouter);
  });

  group('Router', () {
    test('start and stop', () async {
      await router.start();
      verify(mockInternalRouter.start()).called(1);

      await router.stop();
      verify(mockInternalRouter.stop()).called(1);
    });

    test('peerID and isInitialized delegating', () {
      when(mockInternalRouter.peerID).thenReturn('QmID');
      when(mockInternalRouter.isInitialized).thenReturn(true);

      expect(router.peerID, equals('QmID'));
      expect(router.isInitialized, isTrue);
    });

    test('sendMessage delegating', () async {
      final msg = Uint8List.fromList([1, 2, 3]);
      await router.sendMessage('peer1', msg);
      verify(mockInternalRouter.sendMessage('peer1', msg)).called(1);
    });

    test('onPeerDiscovered and connectedPeers', () {
      expect(router.onPeerDiscovered, isA<Stream<Peer>>());
      expect(router.connectedPeers, isEmpty);
    });

    test('connect and disconnect delegating', () async {
      await router.connectToPeer('multiaddr');
      verify(mockInternalRouter.connect('multiaddr')).called(1);

      await router.disconnectFromPeer('multiaddr');
      verify(mockInternalRouter.disconnect('multiaddr')).called(1);
    });
  });
}
