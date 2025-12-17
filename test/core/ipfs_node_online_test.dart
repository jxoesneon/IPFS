import 'dart:async';
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
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/utils/base58.dart'; // Added import
import 'package:test/test.dart';

// Helper to generate valid 64-byte peer ID string
String get validMockPeerId =>
    Base58().encode(Uint8List.fromList(List.filled(64, 1)));

// Mocks
class MockBlockStore extends BlockStore {
  MockBlockStore() : super(path: '/tmp/mock');
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

// Mock Datastore for MockDatastoreHandler - uses noSuchMethod for all interface methods
class _MockDatastore implements Datastore {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatastoreHandler extends DatastoreHandler {
  MockDatastoreHandler() : super(_MockDatastore());

  @override
  Future<bool> hasBlock(String cid) async => false;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
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

class MockP2plibRouter extends P2plibRouter {
  MockP2plibRouter(IPFSConfig config) : super.internal(config);
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  String get peerID => validMockPeerId;
}

class MockCircuitRelayClient extends CircuitRelayClient {
  MockCircuitRelayClient(P2plibRouter router) : super(router);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class MockNetworkHandler extends NetworkHandler {
  final IPFSNode _nodeReceiver;
  final P2plibRouter _mockRouter;

  MockNetworkHandler(IPFSConfig config, this._nodeReceiver, this._mockRouter)
    : super(config);

  @override
  IPFSNode get ipfsNode => _nodeReceiver;

  @override
  String get peerID => validMockPeerId;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void setIpfsNode(IPFSNode node) {}

  @override
  P2plibRouter get p2pRouter => _mockRouter;

  @override
  Router get router => Router(config);
}

class MockDHTHandler extends DHTHandler {
  MockDHTHandler(IPFSConfig config, NetworkHandler networkHandler)
    : super(config, networkHandler.p2pRouter, networkHandler);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    return [
      V_PeerInfo()..peerId = Uint8List.fromList([1, 2, 3]),
    ];
  }

  @override
  Future<String> resolveIPNS(String ipnsName) async {
    return 'QmResolvedCID';
  }

  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

class MockBitswapHandler extends BitswapHandler {
  MockBitswapHandler(
    IPFSConfig config,
    BlockStore store,
    NetworkHandler networkHandler,
  ) : super(config, store, networkHandler.p2pRouter);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};

  @override
  Future<Block?> wantBlock(String cid) async {
    return Block(
      cid: CID.decode(cid),
      data: Uint8List.fromList([10, 20, 30]),
      format: 'raw',
    );
  }
}

class MockIpfsNodeNetworkEvents extends IpfsNodeNetworkEvents {
  MockIpfsNodeNetworkEvents(CircuitRelayClient relay, P2plibRouter router)
    : super(relay, router);

  final StreamController<NetworkEvent> _controller =
      StreamController.broadcast();
  @override
  Stream<NetworkEvent> get networkEvents => _controller.stream;
}

class MockPubSubHandler extends PubSubHandler {
  MockPubSubHandler(
    P2plibRouter router,
    String peerId,
    IpfsNodeNetworkEvents events,
  ) : super(router, peerId, events);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> publish(String topic, String message) async {}

  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

void main() {
  group('IPFSNode Online Tests', () {
    late ServiceContainer container;
    late IPFSConfig config;
    late MockBlockStore mockBlockStore;
    late MockDatastoreHandler mockDatastore;

    setUp(() {
      container = ServiceContainer();
      config = IPFSConfig(offline: false);
      mockBlockStore = MockBlockStore();
      mockDatastore = MockDatastoreHandler();

      // Register Core
      final metrics = MetricsCollector(config);
      container.registerSingleton(metrics);
      container.registerSingleton(SecurityManager(config.security, metrics));

      // Register Storage
      container.registerSingleton<BlockStore>(mockBlockStore);
      container.registerSingleton<DatastoreHandler>(mockDatastore);
      container.registerSingleton<IPLDHandler>(
        MockIPLDHandler(config, mockBlockStore),
      );

      // Mocks for Network
      final mockRouter = MockP2plibRouter(config);
      final mockRelay = MockCircuitRelayClient(mockRouter);
      final mockEvents = MockIpfsNodeNetworkEvents(mockRelay, mockRouter);

      final ipfsNodeForMocks = IPFSNode.fromContainer(container);

      final mockNetworkHandler = MockNetworkHandler(
        config,
        ipfsNodeForMocks,
        mockRouter,
      );
      container.registerSingleton<NetworkHandler>(mockNetworkHandler);

      container.registerSingleton<DHTHandler>(
        MockDHTHandler(config, mockNetworkHandler),
      );

      container.registerSingleton<BitswapHandler>(
        MockBitswapHandler(config, mockBlockStore, mockNetworkHandler),
      );

      container.registerSingleton<PubSubHandler>(
        MockPubSubHandler(mockRouter, validMockPeerId, mockEvents),
      );
    });

    test('should initialize and start in online mode', () async {
      final node = IPFSNode.fromContainer(container);

      // Online mode check
      expect(node.peerId, validMockPeerId);

      await node.start();

      // Verify health check (deep check for handlers)
      final status = await node.getHealthStatus();
      expect(status['network']['dht']['status'], 'mock_ok');
      expect(status['network']['pubsub']['status'], 'mock_ok');

      await node.stop();
    });

    test('should find providers via DHT', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Valid CID (empty directory hash)
      final cid = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';

      final providers = await node.findProviders(cid);
      expect(providers, isNotEmpty);
      expect(providers.first, isNotEmpty);
    });

    test('should resolve IPNS names', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      final res = await node.resolveIPNS('QmSomeNodeId');
      expect(res, 'QmResolvedCID');
    });

    test('should handle pubsub subscribe and publish', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Should not throw
      await node.subscribe('test-topic');
      await node.publish('test-topic', 'hello');
    });
  });
}
