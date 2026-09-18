import 'dart:io';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_adapter.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_coordinator.dart';
import 'package:path/path.dart' as p;

void main() {
  const repoPath = 'test_repo';

  group('IPFSNodeBuilder', () {
    test('build offline node', () async {
      final config = IPFSConfig(
        offline: true,
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );

      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();
      expect(node, isA<IPFSNode>());
    });

    test('build node with minimal config', () async {
      final config = IPFSConfig(
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );

      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();
      expect(node, isA<IPFSNode>());
    });

    test('build node with mobile lifecycle coordinator', () async {
      final config = IPFSConfig(
        offline: true,
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );

      final adapter = ManualMobileLifecycleAdapter();
      final builder = IPFSNodeBuilder(config).withMobileLifecycle(adapter);
      final node = await builder.build();

      expect(node, isA<IPFSNode>());
      expect(node.mobileCoordinator, isNotNull);
      expect(node.mobileCoordinator!.adapter, equals(adapter));
      expect(node.mobileCoordinator!.currentPowerMode, equals(IpfsPowerMode.fullActive));

      await adapter.dispose();
    });

    test('build offline node with RPC and gateway enabled', () async {
      final dir = await Directory.systemTemp.createTemp('ipfs_builder_');
      try {
        final config = IPFSConfig(
          offline: true,
          enableRPC: true,
          rpcApiKey: 'test-api-key',
          gateway: const GatewayConfig(enabled: true, port: 0),
          datastorePath: p.join(dir.path, 'datastore'),
          blockStorePath: p.join(dir.path, 'blocks'),
          keystorePath: p.join(dir.path, 'keystore.json'),
        );

        final builder = IPFSNodeBuilder(config);
        final node = await builder.build();
        expect(node, isA<IPFSNode>());
      } finally {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    });
  });
}
