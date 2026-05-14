import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/lifecycle_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:test/test.dart';

/// Mock classes for testing lifecycle
class MockNetworkHandler extends NetworkHandler {
  MockNetworkHandler(super.config);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  group('LifecycleManager Integration', () {
    test('Should successfully start and stop registered services', () async {
      final config = IPFSConfig(
        network: NetworkConfig(enableMDNS: false),
      );
      final lifecycleManager = LifecycleManager();

      final mdns = MDNSHandler(config);
      final network = MockNetworkHandler(config);
      final routing = RoutingHandler(config, network);

      lifecycleManager.register(mdns);
      lifecycleManager.register(routing);

      await expectLater(lifecycleManager.startAll(), completes);
      expect(lifecycleManager.isRunning, isTrue);

      await expectLater(lifecycleManager.stopAll(), completes);
      expect(lifecycleManager.isRunning, isFalse);
    });
  });
}
