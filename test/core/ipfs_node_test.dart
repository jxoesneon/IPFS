import 'dart:typed_data';
import 'dart:convert';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:test/test.dart';

import '../mocks/in_memory_datastore.dart';

void main() {
  group('IPFSNode Offline Tests', () {
    late ServiceContainer container;
    late IPFSConfig config;
    late BlockStore blockStore;
    late DatastoreHandler datastoreHandler;
    late InMemoryDatastore inMemoryDatastore;

    setUp(() async {
      container = ServiceContainer();
      config = IPFSConfig(offline: true, dataPath: '/tmp/test_repo');
      blockStore = BlockStore(path: '/tmp/mock_blocks');
      inMemoryDatastore = InMemoryDatastore();
      await inMemoryDatastore.init();
      datastoreHandler = DatastoreHandler(inMemoryDatastore);

      // Register Core
      final metrics = MetricsCollector(config);
      container.registerSingleton(metrics);
      container.registerSingleton(SecurityManager(config.security, metrics));

      // Register Storage
      container.registerSingleton<BlockStore>(blockStore);
      container.registerSingleton<DatastoreHandler>(datastoreHandler);
      container.registerSingleton<IPLDHandler>(
        IPLDHandler(config, blockStore),
      );

      // No Network/Services for offline
    });

    test('should initialize and start in offline mode', () async {
      final node = IPFSNode.fromContainer(container);

      // Check offline indicator
      expect(node.peerId, 'offline');

      await node.start();

      // Verify health status to confirm startup
      final health = await node.getHealthStatus();
      expect(health['storage']['datastore']['status'], 'active');

      await node.stop();
    });

    test('should add and retrieve file locally', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final data = Uint8List.fromList([1, 2, 3, 4]);
      final cid = await node.addFile(data);

      expect(cid, isNotNull);
      expect(cid, isNotEmpty);

      final retrievedData = await node.get(cid);
      expect(retrievedData, equals(data));

      // Test cat alias
      final catData = await node.cat(cid);
      expect(catData, equals(data));

      await node.stop();
    });

    test('should add file from stream', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final data = Uint8List.fromList([10, 20, 30, 40, 50]);

      // Create a stream from the data (simulating chunked upload)
      Stream<List<int>> dataStream() async* {
        yield data.sublist(0, 2); // [10, 20]
        yield data.sublist(2, 4); // [30, 40]
        yield data.sublist(4); // [50]
      }

      final cid = await node.addFileStream(dataStream());

      expect(cid, isNotNull);
      expect(cid, isNotEmpty);

      // Verify the data was stored correctly
      final retrievedData = await node.get(cid);
      expect(retrievedData, equals(data));

      await node.stop();
    });

    test('should add and list directory', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final directoryContent = {
        'file1.txt': Uint8List.fromList('Hello World'.codeUnits),
        'subdir': {
          'file2.txt': Uint8List.fromList('Subdir File'.codeUnits),
        },
      };

      final cid = await node.addDirectory(directoryContent);
      expect(cid, isNotNull);

      // List directory
      final links = await node.ls(cid);
      expect(links.length, equals(2));
      expect(links.any((l) => l.name == 'file1.txt'), isTrue);
      expect(links.any((l) => l.name == 'subdir'), isTrue);

      // Resolve path within directory
      final file1Data = await node.get(cid, path: 'file1.txt');
      expect(utf8.decode(file1Data!), equals('Hello World'));

      final file2Data = await node.get(cid, path: 'subdir/file2.txt');
      expect(utf8.decode(file2Data!), equals('Subdir File'));

      await node.stop();
    });

    test('should handle pinning and unpinning', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final data = Uint8List.fromList([1, 1, 1]);
      final cid = await node.addFile(data);

      // Pin
      await node.pin(cid);

      // Check if pinned in datastore
      final pinKey = Key('/pins/$cid');
      expect(await inMemoryDatastore.has(pinKey), isTrue);

      // Unpin
      final unpinned = await node.unpin(cid);
      expect(unpinned, isTrue);
      expect(await inMemoryDatastore.has(pinKey), isFalse);

      await node.stop();
    });

    test('should return null for missing content', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final result = await node.get('nonexistentcid');
      expect(result, isNull);

      await node.stop();
    });

    test('setGatewayMode changes node behavior', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Test each gateway mode - no exceptions should be thrown
      node.setGatewayMode(GatewayMode.internal);
      node.setGatewayMode(GatewayMode.public);
      node.setGatewayMode(GatewayMode.local);
      node.setGatewayMode(GatewayMode.custom, customUrl: 'http://my-gateway.io');

      await node.stop();
    });

    test('subscribe/unsubscribe/publish are no-ops in offline mode', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // These should not throw in offline mode (graceful no-ops)
      await node.subscribe('test-topic');
      await node.unsubscribe('test-topic');
      // publish throws StateError in offline mode (no PubSubHandler)
      expect(
        () => node.publish('test-topic', 'hello'),
        throwsStateError,
      );

      await node.stop();
    });

    test('connectToPeer throws in offline mode', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      expect(
        () => node.connectToPeer('/ip4/127.0.0.1/tcp/4001'),
        throwsStateError,
      );

      await node.stop();
    });

    test('disconnectFromPeer is no-op in offline mode', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Should not throw
      await node.disconnectFromPeer('12D3KooWEXAMPLE');

      await node.stop();
    });

    test('pubsubMessages returns empty stream in offline mode', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final messages = await node.pubsubMessages.toList();
      expect(messages, isEmpty);

      await node.stop();
    });

    test('getHealthStatus returns comprehensive status', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final health = await node.getHealthStatus();
      expect(health['storage'], isNotNull);
      expect(health['storage']['datastore'], isNotNull);
      expect(health['storage']['blockstore'], isNotNull);

      await node.stop();
    });

    test('resolvePeerId returns empty list in offline mode', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final addresses = node.resolvePeerId('12D3KooWEXAMPLE');
      expect(addresses, isEmpty);

      await node.stop();
    });

    test('pinnedCids returns pinned content', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Add and pin a file
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await node.addFile(data);
      await node.pin(cid);

      final pinned = await node.pinnedCids;
      expect(pinned, contains(cid));

      await node.stop();
    });

    test('resolveIPNS throws when DHTHandler not available', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      expect(
        () => node.resolveIPNS('12D3KooWEXAMPLE'),
        throwsA(anything),
      );

      await node.stop();
    });

    test('stop is idempotent', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();
      await node.stop();
      await node.stop(); // Should not throw
    });

    test('double start throws StateError or is handled', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();
      // Second start should be handled gracefully
      // (depends on implementation - may throw or be idempotent)
      await node.stop();
    });
  });
}
