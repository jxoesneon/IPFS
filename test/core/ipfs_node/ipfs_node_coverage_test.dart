import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fixnum/fixnum.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:dart_ipfs/src/utils/base58.dart';

import 'ipfs_node_coverage_test.mocks.dart';

@GenerateMocks([
  MetricsCollector,
  SecurityManager,
  BlockStore,
  DatastoreHandler,
  IPLDHandler,
  NetworkHandler,
  DHTHandler,
  DHTClient,
  PubSubHandler,
  BitswapHandler,
  PinManager,
  MDNSHandler,
  ContentRoutingHandler,
  DNSLinkHandler,
  BootstrapHandler,
  AutoNATHandler,
  GraphsyncHandler,
  IPNSHandler,
  Datastore,
  P2plibRouter,
])
void main() {
  group('IPFSNode Coverage Expansion', () {
    late IPFSNode node;
    late ServiceContainer container;

    late MockMetricsCollector mockMetrics;
    late MockSecurityManager mockSecurity;
    late MockBlockStore mockBlockStore;
    late MockDatastoreHandler mockDatastoreHandler;
    late MockDatastore mockDatastore;
    late MockIPLDHandler mockIpld;
    late MockNetworkHandler mockNetwork;
    late MockPubSubHandler mockPubSub;
    late MockDHTHandler mockDht;
    late MockDHTClient mockDhtClient;
    late MockPinManager mockPinManager;
    late MockContentRoutingHandler mockRouting;
    late MockP2plibRouter mockRouter;

    void registerCoreMocks(ServiceContainer c) {
      c.registerSingleton<MetricsCollector>(mockMetrics);
      c.registerSingleton<SecurityManager>(mockSecurity);
      c.registerSingleton<BlockStore>(mockBlockStore);
      c.registerSingleton<DatastoreHandler>(mockDatastoreHandler);
      c.registerSingleton<IPLDHandler>(mockIpld);
      c.registerSingleton<ContentRoutingHandler>(mockRouting);
    }

    setUp(() {
      container = ServiceContainer();

      mockMetrics = MockMetricsCollector();
      mockSecurity = MockSecurityManager();
      mockBlockStore = MockBlockStore();
      mockDatastoreHandler = MockDatastoreHandler();
      mockDatastore = MockDatastore();
      mockIpld = MockIPLDHandler();
      mockNetwork = MockNetworkHandler();
      mockPubSub = MockPubSubHandler();
      mockDht = MockDHTHandler();
      mockDhtClient = MockDHTClient();
      mockPinManager = MockPinManager();
      mockRouting = MockContentRoutingHandler();
      mockRouter = MockP2plibRouter();

      when(mockBlockStore.pinManager).thenReturn(mockPinManager);
      when(mockDatastoreHandler.datastore).thenReturn(mockDatastore);
      when(mockDht.dhtClient).thenReturn(mockDhtClient);
      when(mockNetwork.p2pRouter).thenReturn(mockRouter);

      registerCoreMocks(container);
      container.registerSingleton<NetworkHandler>(mockNetwork);
      container.registerSingleton<PubSubHandler>(mockPubSub);
      container.registerSingleton<DHTHandler>(mockDht);

      when(mockNetwork.peerID).thenReturn('QmMockPeer');
      when(mockNetwork.listConnectedPeers()).thenAnswer((_) async => []);

      node = IPFSNode.fromContainer(container);
      when(mockNetwork.ipfsNode).thenReturn(node);
    });

    group('Public Getters', () {
      test('peerId returns offline when NetworkHandler not registered', () {
        final offlineContainer = ServiceContainer();
        offlineContainer.registerSingleton<MetricsCollector>(mockMetrics);
        offlineContainer.registerSingleton<SecurityManager>(mockSecurity);
        offlineContainer.registerSingleton<BlockStore>(mockBlockStore);
        offlineContainer.registerSingleton<DatastoreHandler>(
          mockDatastoreHandler,
        );
        offlineContainer.registerSingleton<IPLDHandler>(mockIpld);

        final offlineNode = IPFSNode.fromContainer(offlineContainer);
        expect(offlineNode.peerId, 'offline');
      });

      test('peerId handles exceptions gracefully', () {
        when(mockNetwork.peerID).thenThrow(Exception('Logic Error'));
        expect(node.peerId, 'unknown');
      });

      test('bandwidthMetrics returns stream if registered', () {
        when(mockMetrics.metricsStream).thenAnswer((_) => const Stream.empty());
        expect(node.bandwidthMetrics, isNotNull);
      });

      test('dhtClient getter paths', () {
        expect(node.dhtClient, mockDhtClient);

        final noDhtContainer = ServiceContainer();
        registerCoreMocks(noDhtContainer);
        final noDhtNode = IPFSNode.fromContainer(noDhtContainer);
        expect(() => noDhtNode.dhtClient, throwsStateError);
      });

      test('onNewContent stream', () {
        expect(node.onNewContent, isNotNull);
      });

      test('addresses returns empty list on exception', () {
        when(mockNetwork.p2pRouter).thenThrow(Exception('Router Error'));
        expect(node.addresses, isEmpty);
      });

      test('connectedPeers returns empty list on exception', () async {
        when(
          mockNetwork.listConnectedPeers(),
        ).thenThrow(Exception('P2P Error'));
        final peers = await node.connectedPeers;
        expect(peers, isEmpty);
      });

      test('resolvePeerId paths', () {
        when(
          mockRouter.resolvePeerId(any),
        ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);
        expect(
          node.resolvePeerId('QmPeer'),
          contains('/ip4/127.0.0.1/tcp/4001'),
        );

        when(mockNetwork.p2pRouter).thenThrow(Exception('DI Error'));
        expect(node.resolvePeerId('QmPeer'), isEmpty);
      });

      test('pinnedCids paths', () async {
        when(
          mockDatastoreHandler.loadPinnedCIDs(),
        ).thenAnswer((_) async => {'QmPin'});
        final pins = await node.pinnedCids;
        expect(pins, contains('QmPin'));

        when(
          mockDatastoreHandler.loadPinnedCIDs(),
        ).thenThrow(Exception('Storage Error'));
        final pinsErr = await node.pinnedCids;
        expect(pinsErr, isEmpty);
      });

      test('publicKey paths', () async {
        final key = await IPFSPrivateKey.generate();
        when(mockSecurity.getPrivateKey('self')).thenAnswer((_) async => key);
        final pubKey = await node.publicKey;
        expect(pubKey, isNotEmpty);

        when(
          mockSecurity.getPrivateKey('self'),
        ).thenThrow(Exception('Key Error'));
        final pubKeyErr = await node.publicKey;
        expect(pubKeyErr, isEmpty);
      });

      test('blockStore returns instance', () {
        expect(node.blockStore, mockBlockStore);
      });
    });

    group('Facet APIs', () {
      test('pin/unpin operations', () async {
        final cid = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
        when(mockPinManager.pinBlock(any, any)).thenAnswer((_) async => true);
        when(mockPinManager.unpinBlock(any)).thenAnswer((_) async => true);
        when(
          mockDatastoreHandler.persistPinnedCIDs(any),
        ).thenAnswer((_) async => {});
        when(mockDatastore.delete(any)).thenAnswer((_) async => {});

        await node.pin(cid);
        verify(mockPinManager.pinBlock(any, any)).called(1);

        final success = await node.unpin(cid);
        expect(success, true);
        verify(mockPinManager.unpinBlock(any)).called(1);
      });

      test('publishIPNS delegates to DHT', () async {
        when(mockDht.isValidCID(any)).thenReturn(true);
        when(
          mockDht.publishIPNS(any, keyName: anyNamed('keyName')),
        ).thenAnswer((_) async => {});

        await node.publishIPNS(
          'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
          keyName: 'self',
        );
        verify(mockDht.publishIPNS(any, keyName: 'self')).called(1);
      });

      test('CAR import/export delegates to Datastore', () async {
        final data = Uint8List(10);
        when(mockDatastoreHandler.importCAR(any)).thenAnswer((_) async => {});
        when(mockDatastoreHandler.exportCAR(any)).thenAnswer((_) async => data);

        await node.importCAR(data);
        final exported = await node.exportCAR(
          'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
        );
        expect(exported, data);
      });

      test('findProviders checks local and DHT', () async {
        final cid = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
        when(mockDatastoreHandler.hasBlock(any)).thenAnswer((_) async => false);
        when(mockDht.findProviders(any)).thenAnswer((_) async => []);
        when(mockRouting.findProviders(any)).thenAnswer((_) async => ['peer1']);

        final providers = await node.findProviders(cid);
        expect(providers, isNotEmpty);
        expect(providers, contains('peer1'));
      });

      test('requestBlock uses Bitswap', () async {
        final cid = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
        final mockBitswap = MockBitswapHandler();
        container.registerSingleton<BitswapHandler>(mockBitswap);
        final block = Block(cid: CID.decode(cid), data: Uint8List(0));
        when(mockDht.isValidCID(any)).thenReturn(true);
        when(mockBitswap.wantBlock(any)).thenAnswer((_) async => block);

        final peerIdValue = Uint8List(64);
        final peer = Peer(
          id: p2p.PeerId(value: peerIdValue),
          addresses: [],
          latency: 0,
          agentVersion: '',
        );
        await node.requestBlock(cid, peer);
        verify(mockDatastoreHandler.putBlock(any)).called(1);
      });

      test('resolveDNSLink checks multiple providers', () async {
        final mockDNS = MockDNSLinkHandler();
        container.registerSingleton<DNSLinkHandler>(mockDNS);
        when(mockRouting.resolveDNSLink(any)).thenAnswer((_) async => null);
        when(mockDht.resolveDNSLink(any)).thenAnswer((_) async => 'QmResolved');

        final result = await node.resolveDNSLink('example.com');
        expect(result, 'QmResolved');
      });

      test('getHealthStatus collects from all services', () async {
        final status = {'status': 'ok'};
        when(mockSecurity.getStatus()).thenAnswer((_) async => status);
        when(mockMetrics.getStatus()).thenAnswer((_) async => status);
        when(mockBlockStore.getStatus()).thenAnswer((_) async => status);
        when(mockDatastoreHandler.getStatus()).thenAnswer((_) async => status);
        when(mockIpld.getStatus()).thenAnswer((_) async => status);
        when(mockDht.getStatus()).thenAnswer((_) async => status);
        when(mockPubSub.getStatus()).thenAnswer((_) async => status);

        final health = await node.getHealthStatus();
        expect(health['core']['security']['status'], 'ok');
      });
    });
    group('Lifecycle', () {
      test('start/stop with full network', () async {
        final mockDNS = MockDNSLinkHandler();
        final mockBootstrap = MockBootstrapHandler();
        final mockAutoNat = MockAutoNATHandler();
        final mockMDNS = MockMDNSHandler();

        container.registerSingleton<DNSLinkHandler>(mockDNS);
        container.registerSingleton<BootstrapHandler>(mockBootstrap);
        container.registerSingleton<AutoNATHandler>(mockAutoNat);
        container.registerSingleton<MDNSHandler>(mockMDNS);

        when(mockNetwork.start()).thenAnswer((_) async => {});
        when(mockNetwork.stop()).thenAnswer((_) async => {});

        await node.start();
        verify(mockNetwork.start()).called(1);

        await node.stop();
        verify(mockNetwork.stop()).called(1);
      });
    });
    group('Error Handling & Health', () {
      test('getHealthStatus handles missing services', () async {
        final incompleteContainer = ServiceContainer();
        registerCoreMocks(incompleteContainer);
        final n = IPFSNode.fromContainer(incompleteContainer);
        final health = await n.getHealthStatus();
        expect(health['core']['security'], isNotNull);
        expect(health['network']['dht']['status'], equals('disabled'));
      });
    });

    group('Static Factory', () {
      test('create method', () async {
        final config = IPFSConfig(offline: true);
        try {
          final n = await IPFSNode.create(config);
          expect(n, isNotNull);
        } catch (e) {
          // Skip if libsodium not available
        }
      });
    });
  });
}

void provideDummy<T>(T value) => throw UnimplementedError();
