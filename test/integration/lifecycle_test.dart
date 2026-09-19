import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/lifecycle_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:test/test.dart';

void main() {
  group('LifecycleManager Integration', () {
    test('Should successfully start and stop registered services', () async {
      final config = IPFSConfig(network: NetworkConfig(enableMDNS: false));
      final lifecycleManager = LifecycleManager();

      final mdns = MDNSHandler(config);
      final dnslink = DNSLinkHandler(config);

      lifecycleManager.register(mdns);
      lifecycleManager.register(dnslink);

      await expectLater(lifecycleManager.startAll(), completes);
      expect(lifecycleManager.isRunning, isTrue);

      await expectLater(lifecycleManager.stopAll(), completes);
      expect(lifecycleManager.isRunning, isFalse);
    });
  });
}
