import 'dart:io';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_adapter.dart';
import 'package:get_it/get_it.dart';
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
      expect(
        node.mobileCoordinator!.currentPowerMode,
        equals(IpfsPowerMode.fullActive),
      );

      await adapter.dispose();
    });

    test('wires the IPLD ipnsResolver to the IPNS handler', () async {
      final dir = await Directory.systemTemp.createTemp('ipfs_builder_');
      try {
        // IPNS wiring only happens when the DHT handler is registered,
        // which requires a non-offline (network-enabled) config.
        final config = IPFSConfig(
          datastorePath: p.join(dir.path, 'datastore'),
          blockStorePath: p.join(dir.path, 'blocks'),
        );

        final builder = IPFSNodeBuilder(config);
        await builder.build();

        final ipld = GetIt.instance.get<IPLDHandler>();
        expect(ipld.ipnsResolver, isNotNull);
        // The resolver delegates to IPNSHandler.resolve — an unresolvable
        // name fails inside the handler (or times out), proving the wired
        // closure executes.
        await ipld.ipnsResolver!('k51_unresolvable_name')
            .timeout(const Duration(seconds: 5), onTimeout: () => 'unresolved')
            .catchError((_) => 'unresolved');
      } finally {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
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
