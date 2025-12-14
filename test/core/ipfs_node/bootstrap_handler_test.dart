import 'dart:async';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:test/test.dart';

// Mocks
class MockConfig extends IPFSConfig {
  MockConfig({List<String> peers = const []})
      : super(
          offline: false,
          network: NetworkConfig(bootstrapPeers: peers),
        );
}

class MockNetworkHandler extends NetworkHandler {
  final List<String> connectedPeers = [];

  MockNetworkHandler() : super(MockConfig());

  @override
  Future<void> connectToPeer(String multiaddress) async {
    connectedPeers.add(multiaddress);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BootstrapHandler', () {
    late MockConfig config;
    late MockNetworkHandler networkHandler;
    late BootstrapHandler handler;

    test('start and stop lifecycle works correctly', () async {
      // Use empty peers to avoid multiaddr parsing issues
      config = MockConfig(peers: []);
      networkHandler = MockNetworkHandler();
      handler = BootstrapHandler(config, networkHandler);

      // Start handler
      await handler.start();

      // Verify status
      final status = await handler.getStatus();
      expect(status['running'], true);
      expect(status['total_bootstrap_peers'], 0);

      // Stop handler
      await handler.stop();
      final stoppedStatus = await handler.getStatus();
      expect(stoppedStatus['running'], false);
    });
  });
}
