import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:test/test.dart';

void main() {
  group('IpfsNodeBuilder', () {
    test('builds offline node correctly', () async {
      final config = IPFSConfig(offline: true);
      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();

      expect(node, isA<IPFSNode>());
      expect(node.peerId, 'offline');
    });

    test('builds online node correctly', () async {
      final config = IPFSConfig(
        offline: false,
        network: NetworkConfig(
          enableMDNS: false,
        ), // Disable mDNS for test environment
      );
      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();

      expect(node, isA<IPFSNode>());
      expect(node.peerId, isNot('offline'));
    });

    test('builds online node with customized services', () async {
      final config = IPFSConfig(
        offline: false,
        enableDHT: false,
        enablePubSub: false,
        network: NetworkConfig(enableMDNS: false),
      );
      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();

      expect(node, isA<IPFSNode>());
      // DHT should be disabled - verify by checking if dhtClient throws or returns stub
      expect(
        () => node.dhtClient,
        throwsStateError,
      ); // Offline checks registration
    });

    test('validates required services', () async {
      // This is implicit in build(), but we can try to break it
      // Creating a builder with null config? Type system prevents this.
    });
  });
}
