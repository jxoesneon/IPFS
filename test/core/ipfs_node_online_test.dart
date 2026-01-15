import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart'; // Added import
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  MockIPLDHandler(super.config, super.store);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {'status': 'mock_ok'};
}

class MockRouter implements RouterInterface {
  MockRouter(IPFSConfig config);

  @override
  String get peerID => validMockPeerId;
  @override
  bool get hasStarted => true;
  @override
  bool get isInitialized => true;
  @override
  Set<String> get connectedPeers => {};
  @override
  List<String> get listeningAddresses => ['/ip4/127.0.0.1/tcp/4001'];
  @override
  Stream<ConnectionEvent> get connectionEvents => const Stream.empty();
  @override
  Stream<MessageEvent> get messageEvents => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> connect(String multiaddress) async {}
  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}
  @override
  List<String> listConnectedPeers() => [];
  @override
  bool isConnectedPeer(String peerIdStr) => false;
  @override
  Future<void> sendMessage(
    String peerId,
    Uint8List message, {
    String? protocolId,
  }) async {}
  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;
  @override
  Stream<Uint8List> receiveMessages(String peerId) => const Stream.empty();
  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {}
  @override
  void removeMessageHandler(String protocolId) {}
  @override
  void registerProtocol(String protocolId) {}
  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}
  @override
  void emitEvent(String topic, Uint8List data) {}
  @override
  void onEvent(String topic, void Function(dynamic) handler) {}
  @override
  void offEvent(String topic, void Function(dynamic) handler) {}
  @override
  dynamic parseMultiaddr(String multiaddr) => null;
  @override
  List<String> resolvePeerId(String peerIdStr) => [];
}

class MockCircuitRelayClient extends CircuitRelayClient {
  MockCircuitRelayClient(super.router);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class MockNetworkHandler implements NetworkHandler {
  MockNetworkHandler(this._mockRouter);
  final RouterInterface _mockRouter;

  @override
  late IPFSNode ipfsNode;

  @override
  CircuitRelayClient get circuitRelayClient =>
      MockCircuitRelayClient(_mockRouter);

  @override
  RouterInterface get router => _mockRouter;

  @override
  Router get dhtRouter => Router(IPFSConfig());

  @override
  IPFSConfig get config => IPFSConfig(); // stub config

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<NetworkEvent> get networkEvents => const Stream.empty();

  @override
  String get peerID => _mockRouter.peerID;

  @override
  Future<void> connectToPeer(String multiaddress) async {}

  @override
  Future<void> disconnectFromPeer(String multiaddress) async {}

  @override
  Future<List<String>> listConnectedPeers() async => [];

  @override
  Future<void> sendMessage(String peerId, String message) async {}

  @override
  Stream<String> receiveMessages(String peerId) => const Stream.empty();

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  @override
  Future<bool> canConnectDirectly(String peerAddress) async => true;

  @override
  Future<bool> testDialback() async => true;
}

class MockDHTHandler extends DHTHandler {
  MockDHTHandler(IPFSConfig config, NetworkHandler networkHandler)
    : super(config, networkHandler.router, networkHandler);

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
  ) : super(config, store, networkHandler.router);

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
  MockIpfsNodeNetworkEvents(super.router);

  final StreamController<NetworkEvent> _controller =
      StreamController.broadcast();
  @override
  Stream<NetworkEvent> get networkEvents => _controller.stream;
}

class MockPubSubHandler extends PubSubHandler {
  MockPubSubHandler(super.router, super.peerId, super.events);

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
      // Mocks for Network
      final mockRouter = MockRouter(config);
      final mockRelay = MockCircuitRelayClient(mockRouter);
      final mockEvents = MockIpfsNodeNetworkEvents(mockRouter);

      // final ipfsNodeForMocks = IPFSNode.fromContainer(container); // Unused in new mock

      final mockNetworkHandler = MockNetworkHandler(mockRouter);
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
    test('should connect and disconnect peer', () async {
      final node = IPFSNode.fromContainer(container);
      await node.start();

      // Should not throw
      await node.connectToPeer('/ip4/127.0.0.1/tcp/4001/p2p/$validMockPeerId');
      await node.disconnectFromPeer(validMockPeerId);
    });

    test('should expose network addresses', () async {
      final node = IPFSNode.fromContainer(container);
      expect(node.addresses, isNotEmpty);
    });
  });
}
