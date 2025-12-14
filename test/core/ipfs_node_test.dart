import 'dart:typed_data';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:test/test.dart';

// Manual Mocks
class MockBlockStore extends BlockStore {
  MockBlockStore() : super(path: '/tmp/mock');

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

class MockDatastoreHandler extends DatastoreHandler {
  final Map<String, Block> blocks = {};

  MockDatastoreHandler(IPFSConfig config) : super(config);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};

  @override
  Future<void> putBlock(Block block) async {
    blocks[block.cid.toString()] = block;
  }

  @override
  Future<Block?> getBlock(String cid) async {
    return blocks[cid];
  }
}

class MockIPLDHandler extends IPLDHandler {
  MockIPLDHandler(IPFSConfig config, BlockStore store) : super(config, store);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

void main() {
  group('IPFSNode Offline Tests', () {
    late ServiceContainer container;
    late IPFSConfig config;
    late MockBlockStore mockBlockStore;
    late MockDatastoreHandler mockDatastore;

    setUp(() {
      container = ServiceContainer();
      config = IPFSConfig(offline: true, dataPath: '/tmp/test_repo');
      mockBlockStore = MockBlockStore();
      mockDatastore = MockDatastoreHandler(config);

      // Register Core
      final metrics = MetricsCollector(config);
      container.registerSingleton(metrics);
      container.registerSingleton(SecurityManager(config.security, metrics));

      // Register Storage
      container.registerSingleton<BlockStore>(mockBlockStore);
      container.registerSingleton<DatastoreHandler>(mockDatastore);
      container.registerSingleton<IPLDHandler>(
          MockIPLDHandler(config, mockBlockStore));

      // No Network/Services for offline
    });

    test('should initialize and start in offline mode', () async {
      final node = IPFSNode.fromContainer(container);

      // Check offline indicator
      expect(node.peerId, 'offline');

      await node.start();

      // Verify health status to confirm startup
      final health = await node.getHealthStatus();
      expect(health['storage']['blockstore']['status'], 'mock_ok');

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
  });
}
