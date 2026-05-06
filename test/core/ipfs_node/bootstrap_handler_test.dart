import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';

import 'bootstrap_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<NetworkHandler>()])
void main() {
  late BootstrapHandler handler;
  late MockNetworkHandler mockNetworkHandler;
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    config = IPFSConfig(network: NetworkConfig(bootstrapPeers: <String>[]));
    handler = BootstrapHandler(config, mockNetworkHandler);
  });

  group('BootstrapHandler', () {
    test('start and stop lifecycle', () async {
      config.network.bootstrapPeers.add(
        '/ip4/127.0.0.1/tcp/4001/p2p/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );

      await handler.start();
      verify(mockNetworkHandler.connectToPeer(any)).called(1);

      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      expect(status['connected_peers'], equals(1));

      await handler.stop();
      expect((await handler.getStatus())['running'], isFalse);
    });

    test('start when already running', () async {
      await handler.start();
      await handler.start();
    });

    test('stop when already stopped', () async {
      await handler.stop();
    });

    test('connection failure handles error', () async {
      config.network.bootstrapPeers.add(
        '/ip4/127.0.0.1/tcp/4001/p2p/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      when(
        mockNetworkHandler.connectToPeer(any),
      ).thenThrow(Exception('Conn error'));

      await handler.start();
      final status = await handler.getStatus();
      expect(status['connected_peers'], equals(0));
    });

    test('start handles invalid multiaddr', () async {
      config.network.bootstrapPeers.add('/invalid/peer/address');

      // The start method catches and logs errors for individual peers inside _connectToBootstrapPeers.
      await handler.start();
      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      expect(status['connected_peers'], equals(0));
    });
  });
}
