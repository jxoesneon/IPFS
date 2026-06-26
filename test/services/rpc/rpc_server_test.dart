@TestOn('vm')
library;

import 'dart:convert';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockBlockStore implements BlockStore {
  @override
  Future<AddBlockResponse> putBlock(Block block) async => AddBlockResponse();
  @override
  Future<GetBlockResponse> getBlock(String cid) async => GetBlockResponse();
  @override
  Future<bool> hasBlock(String cid) async => false;
  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async =>
      RemoveBlockResponse();
  Stream<CID> get storedBlocks => const Stream.empty();
  Future<void> clear() async {}
  Future<void> close() async {}
  @override
  Future<List<Block>> getAllBlocks() async => [];
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {};

  @override
  PinManager get pinManager => throw UnimplementedError('Mock');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatastoreHandler implements DatastoreHandler {
  final MemoryDatastore _memDatastore = MemoryDatastore();

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Datastore get datastore => _memDatastore;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPLDHandler implements IPLDHandler {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ServiceContainer _createContainer() {
  final container = ServiceContainer();
  final config = IPFSConfig(offline: true); // Minimal config
  final metrics = MetricsCollector(config);
  container.registerSingleton(metrics);
  container.registerSingleton(SecurityManager(config.security, metrics));
  container.registerSingleton<BlockStore>(MockBlockStore());
  container.registerSingleton<DatastoreHandler>(MockDatastoreHandler());
  container.registerSingleton<IPLDHandler>(MockIPLDHandler());
  return container;
}

class MockIPFSNode extends IPFSNode {
  MockIPFSNode() : super.fromContainer(_createContainer());

  @override
  String get peerId => 'QmTestPeerId';

  @override
  List<String> get addresses => ['/ip4/127.0.0.1/tcp/4001'];

  @override
  // ignore: overridden_fields
  final Future<String> publicKey = Future.value('TestPublicKey');

  @override
  Future<List<String>> get connectedPeers async => ['QmPeer1', 'QmPeer2'];
}

void main() {
  group('RPCServer', () {
    late RPCServer server;
    late MockIPFSNode mockNode;
    late MetricsCollector metricsCollector;
    final int port = 8081; // Use a different port to avoid conflicts

    setUp(() async {
      mockNode = MockIPFSNode();
      metricsCollector = MetricsCollector(
        IPFSConfig(
          metrics: const MetricsConfig(
            enabled: true,
            enablePrometheusExport: true,
            collectionIntervalSeconds: 60,
          ),
        ),
      );
      server = RPCServer(
        node: mockNode,
        port: port,
        apiKey: 'secret-key',
        metricsCollector: metricsCollector,
        metricsConfig: const MetricsConfig(
          enabled: true,
          enablePrometheusExport: true,
        ),
      );
      await server.start();
    });

    tearDown(() async {
      if (server.isRunning) {
        await server.stop();
      }
      await metricsCollector.stop();
    });

    test('should return version details', () async {
      final response = await http.post(
        Uri.parse('http://localhost:$port/api/v0/version'),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body['Version'], isNotNull);
      expect(body['Commit'], isNotNull);
    });

    test('should return node ID', () async {
      final response = await http.post(
        Uri.parse('http://localhost:$port/api/v0/id'),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body['ID'], 'QmTestPeerId');
      expect(body['Addresses'], contains('/ip4/127.0.0.1/tcp/4001'));
    });

    test('should require API key for protected endpoints', () async {
      // Swarm peers is protected
      final response = await http.post(
        Uri.parse('http://localhost:$port/api/v0/swarm/peers'),
      );
      expect(response.statusCode, 403);
    });

    test('should allow protected endpoints with valid API key', () async {
      final response = await http.post(
        Uri.parse('http://localhost:$port/api/v0/swarm/peers'),
        headers: {'X-API-Key': 'secret-key'},
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body['Peers'], hasLength(2));
    });

    test('should reject invalid API key', () async {
      final response = await http.post(
        Uri.parse('http://localhost:$port/api/v0/swarm/peers'),
        headers: {'X-API-Key': 'wrong-key'},
      );
      expect(response.statusCode, 403);
    });

    test('should expose /metrics as Prometheus text', () async {
      // Make a request so the metrics middleware records something.
      await http.post(Uri.parse('http://localhost:$port/api/v0/version'));

      final response = await http.get(
        Uri.parse('http://localhost:$port/metrics'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/plain'));
      expect(response.body, contains('ipfs_rpc_requests_total'));
      expect(response.body, contains('ipfs_rpc_request_duration_seconds'));
      expect(response.body, contains('endpoint="/api/v0/version"'));
    });
  });
}
