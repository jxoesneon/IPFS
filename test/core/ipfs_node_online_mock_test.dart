import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler_io.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/network/router.dart' as ipfs_router;
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

import '../mocks/in_memory_datastore.dart';

class MockNetworkHandler implements NetworkHandler {
  @override
  late final IPFSNode ipfsNode;

  @override
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  @override
  String get peerID => 'MockPeerID123';

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connectToPeer(String multiaddress) async {}

  @override
  Future<void> disconnectFromPeer(String multiaddress) async {}

  @override
  Future<List<String>> listConnectedPeers() async => ['Peer1', 'Peer2'];

  @override
  P2plibRouter get p2pRouter => MockP2plibRouter();

  @override
  ipfs_router.Router get router => MockIPFSRouter();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockP2plibRouter implements P2plibRouter {
  @override
  List<String> get listeningAddresses => ['/ip4/127.0.0.1/udp/4001/p2p/MockPeerID123'];

  @override
  List<String> resolvePeerId(String peerId) => ['127.0.0.1:4002'];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSRouter implements ipfs_router.Router {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDHTHandler implements DHTHandler {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<String> resolveIPNS(String ipnsName) async => 'QmResolvedCID';

  @override
  Future<String?> resolveDNSLink(String domain) async => 'QmDNSLinkCID';

  @override
  bool isValidCID(String cid) => true;

  @override
  Future<void> publishIPNS(String cid, {required String keyName}) async {}

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPubSubHandler implements PubSubHandler {
  List<String> subscribedTopics = [];
  List<String> publishedMessages = [];

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> subscribe(String topic) async {
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    subscribedTopics.remove(topic);
  }

  @override
  Future<void> publish(String topic, String message) async {
    publishedMessages.add('$topic:$message');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDNSLinkHandler implements DNSLinkHandler {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String?> resolve(String domainName) async => 'QmDNSLinkCID';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockContentRoutingHandler implements ContentRoutingHandler {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String?> resolveDNSLink(String domainName) async => 'QmDNSLinkCID';
  @override
  Future<List<String>> findProviders(String cid) async => ['PeerX'];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSecurityManager implements SecurityManager {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<IPFSPrivateKey?> getPrivateKey(String name) async {
    if (name == 'self') return MockPrivateKey();
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPrivateKey implements IPFSPrivateKey {
  @override
  Uint8List get publicKeyBytes => Uint8List.fromList(List.filled(33, 1));
  @override
  Uint8List sign(Uint8List data) => Uint8List(0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockBitswapHandler implements BitswapHandler {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IPFSNode Online Mock Tests', () {
    late ServiceContainer container;
    late IPFSConfig config;
    late IPFSNode node;
    late MockNetworkHandler mockNetwork;
    late MockDHTHandler mockDHT;
    late MockPubSubHandler mockPubSub;
    late MockDNSLinkHandler mockDNS;
    late MockContentRoutingHandler mockRouting;
    late MockSecurityManager mockSecurity;
    late MockBitswapHandler mockBitswap;

    final validCid = 'QmPZ9gcCEpqKTo6aq61g2nd7Kxcyge7B1SAb6No7u6971h';

    setUp(() async {
      container = ServiceContainer();
      config = IPFSConfig(offline: false);

      final metrics = MetricsCollector(config);
      container.registerSingleton(metrics);

      mockSecurity = MockSecurityManager();
      container.registerSingleton<SecurityManager>(mockSecurity);

      final blockStore = BlockStore(path: '/tmp/test_bs_online');
      container.registerSingleton(blockStore);

      final inMemoryDatastore = InMemoryDatastore();
      await inMemoryDatastore.init();
      container.registerSingleton(DatastoreHandler(inMemoryDatastore));

      container.registerSingleton(IPLDHandler(config, blockStore));

      node = IPFSNode.fromContainer(container);

      mockNetwork = MockNetworkHandler();
      mockNetwork.setIpfsNode(node);
      mockDHT = MockDHTHandler();
      mockPubSub = MockPubSubHandler();
      mockDNS = MockDNSLinkHandler();
      mockRouting = MockContentRoutingHandler();
      mockBitswap = MockBitswapHandler();

      container.registerSingleton<NetworkHandler>(mockNetwork);
      container.registerSingleton<DHTHandler>(mockDHT);
      container.registerSingleton<PubSubHandler>(mockPubSub);
      container.registerSingleton<DNSLinkHandler>(mockDNS);
      container.registerSingleton<ContentRoutingHandler>(mockRouting);
      container.registerSingleton<BitswapHandler>(mockBitswap);
    });

    test('peerId returns mock peer ID', () {
      expect(node.peerId, equals('MockPeerID123'));
    });

    test('publicKey returns base64 encoded proto', () async {
      final key = await node.publicKey;
      expect(key, isNotEmpty);
    });

    test('addresses returns mock listening addresses', () {
      expect(node.addresses, contains('/ip4/127.0.0.1/udp/4001/p2p/MockPeerID123'));
    });

    test('resolvePeerId returns mock addresses', () {
      expect(node.resolvePeerId('SomePeerID'), contains('127.0.0.1:4002'));
    });

    test('resolveIPNS delegates to DHTHandler', () async {
      final result = await node.resolveIPNS('test.ipns');
      expect(result, equals('QmResolvedCID'));
    });

    test('resolveDNSLink delegates to DHTHandler/DNSLinkHandler', () async {
      final result = await node.resolveDNSLink('example.com');
      expect(result, equals('QmDNSLinkCID'));
    });

    test('connectToPeer delegates to NetworkHandler', () async {
      await node.connectToPeer('/ip4/1.2.3.4/tcp/4001');
    });

    test('connectedPeers returns mock peer list', () async {
      final peers = await node.connectedPeers;
      expect(peers, containsAll(['Peer1', 'Peer2']));
    });

    test('PubSub operations delegate to PubSubHandler', () async {
      await node.subscribe('test-topic');
      expect(mockPubSub.subscribedTopics, contains('test-topic'));
      await node.publish('test-topic', 'hello');
      expect(mockPubSub.publishedMessages, contains('test-topic:hello'));
      await node.unsubscribe('test-topic');
      expect(mockPubSub.subscribedTopics, isEmpty);
    });

    test('bandwidthMetrics returns stream', () {
      expect(node.bandwidthMetrics, isA<Stream>());
    });

    test('publishIPNS delegates to DHTHandler', () async {
      await node.publishIPNS(validCid, keyName: 'self');
    });

    test('CAR import and export', () async {
      final carData = Uint8List.fromList([1, 2, 3]);
      try {
        await node.importCAR(carData);
      } catch (e) {
        // expected if format is wrong
      }
      try {
        await node.exportCAR(validCid);
      } catch (e) {
        // expected if not found
      }
    });

    test('findProviders returns providers from routing', () async {
      final providers = await node.findProviders(validCid);
      expect(providers, contains('PeerX'));
    });

    test('Getters for core services', () {
      expect(node.datastore, isNotNull);
      expect(node.router, isNotNull);
      expect(node.bitswap, isNotNull);
      expect(node.dhtHandler, isNotNull);
      expect(node.onNewContent, isA<Stream>());
    });

    test('stop clears core systems', () async {
      await node.stop();
      // Re-verify it doesn't crash on multiple stops
      await node.stop();
    });
  });
}
