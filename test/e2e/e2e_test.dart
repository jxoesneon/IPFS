import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('E2E IPFSNode Lifecycle', () {
    late Directory tempDir;
    late IPFSNode node;

    setUp(() async {
      // Create a temporary directory for the IPFS repo
      tempDir = await Directory.systemTemp.createTemp('ipfs_e2e_test_');

      final config = IPFSConfig(
        datastorePath: path.join(tempDir.path, 'datastore'),
        keystorePath: path.join(tempDir.path, 'keystore'),
        blockStorePath: path.join(tempDir.path, 'blocks'),
        offline: false, // Enable networking components to verify startup
        debug: true,
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'], // Use random port
          enableNatTraversal:
              false, // Disable NAT for local test to avoid delays
          enableMDNS: false, // Disable mDNS to avoid port conflicts
          bootstrapPeers: [], // No metadata noise
        ),
      );

      node = await IPFSNode.create(config);
    });

    tearDown(() async {
      try {
        await node.stop();
      } catch (_) {
        // Ignore if already stopped or not started
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Node starts, initializes components, and stops cleanly', () async {
      // 1. Start the node
      await node.start();

      // Verification: Check if PeerID is available (indicates network layer up)
      expect(node.peerID, isNotEmpty);
      expect(node.peerID, isNot(equals('offline')));

      // 2. Verify Key Components are Accessible
      expect(node.dhtClient, isNotNull);
      expect(node.datastore, isNotNull);
      expect(node.blockStore, isNotNull);

      // 3. Perform a basic operation (Add content locally)
      final content = 'Hello E2E World';
      final contentBytes = Uint8List.fromList(content.codeUnits);
      final cid = await node.addFile(contentBytes);

      expect(cid, isNotNull);
      expect(cid.toString(), isNotEmpty);

      // 4. Retrieve content
      final retrievedBytes = await node.cat(cid.toString());
      expect(retrievedBytes, isNotNull);
      final retrievedString = String.fromCharCodes(retrievedBytes!);
      expect(retrievedString, equals(content));

      // 5. Verify Network State (should be empty but initialized)
      // Note: `connectedPeers` is a Future property in IPFSNode
      final peers = await node.connectedPeers;
      expect(peers, isEmpty); // No bootstrap peers

      // 6. Stop the node
      await node.stop();
      // Note: IPFSNode doesn't expose `isStarted` publicly directly, but we can infer it
      // or check health status. For this test, we assume stop completes without error.
      // Alternatively, we can check health status which should show disabled services.
      final health = await node.getHealthStatus();
      expect(
        health['network']['dht']['status'],
        anyOf(equals('disabled'), contains('error')),
      );
    });
  });
}
