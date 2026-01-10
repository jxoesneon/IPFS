import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:multibase/multibase.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'dht_handler_coverage_test.mocks.dart';

@GenerateMocks(
  [NetworkHandler, P2plibRouter, DHTClient, Keystore, KademliaRoutingTable],
  customMocks: [MockSpec<ds.Datastore>(as: #MockDatastore)],
)
void main() {
  late DHTHandler dhtHandler;
  late MockNetworkHandler mockNetworkHandler;
  late MockP2plibRouter mockRouter;
  late MockDatastore mockStorage;
  late MockDHTClient mockDhtClient;
  late MockKeystore mockKeystore;
  late MockKademliaRoutingTable mockRoutingTable;
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    mockRouter = MockP2plibRouter();
    mockStorage = MockDatastore();
    mockDhtClient = MockDHTClient();
    mockKeystore = MockKeystore();
    mockRoutingTable = MockKademliaRoutingTable();
    config = IPFSConfig();

    when(mockNetworkHandler.config).thenReturn(config);
    when(mockRouter.peerID).thenReturn('QmTest');
    when(mockDhtClient.kademliaRoutingTable).thenReturn(mockRoutingTable);

    dhtHandler = DHTHandler(
      config,
      mockRouter,
      mockNetworkHandler,
      storage: mockStorage,
      client: mockDhtClient,
      keystore: mockKeystore,
    );
  });

  CID createTestCID() {
    return CID(
      version: 0,
      multihash: Multihash.decode(
        Uint8List.fromList([0x12, 0x20, ...List.filled(32, 0)]),
      ),
      codec: 'dag-pb',
      multibaseType: Multibase.base58btc,
    );
  }

  PeerId createTestPeerId([int seed = 0]) {
    final list = List.filled(64, seed);
    return PeerId(value: Uint8List.fromList(list));
  }

  p2p.PeerId createTestP2PPeerId([int seed = 0]) {
    return p2p.PeerId(value: Uint8List.fromList(List.filled(64, seed)));
  }

  group('DHTHandler Coverage', () {
    test('start and stop delegate to DHTClient', () async {
      await dhtHandler.start();
      verify(mockDhtClient.start()).called(1);

      await dhtHandler.stop();
      verify(mockDhtClient.stop()).called(1);
    });

    test('findProviders delegates to DHTClient', () async {
      final cid = createTestCID();
      when(mockDhtClient.findProviders(any)).thenAnswer((_) async => []);

      await dhtHandler.findProviders(cid);
      verify(mockDhtClient.findProviders(cid.toString())).called(1);
    });

    test('putValue and getValue use storage', () async {
      final key = Key.fromString('test_key');
      final value = Value(Uint8List.fromList([1, 2, 3]));

      await dhtHandler.putValue(key, value);
      verify(mockStorage.put(any, any)).called(1);

      when(mockStorage.get(any)).thenAnswer((_) async => value.bytes);
      final retrieved = await dhtHandler.getValue(key);
      expect(retrieved.bytes, value.bytes);
    });

    test('handleProvideRequest enforces rate limit (SEC-010)', () async {
      final cid = createTestCID();
      final provider = createTestPeerId(1);

      // Exceed rate limit (default is 10)
      for (var i = 0; i < 15; i++) {
        await dhtHandler.handleProvideRequest(cid, provider);
      }

      // Verify addProvider called exactly 10 times
      verify(
        mockDhtClient.addProvider(cid.toString(), provider.toString()),
      ).called(10);
    });

    test(
      'handleProvideRequest enforces max providers per CID (SEC-010)',
      () async {
        final cid = createTestCID();

        // Exceed max providers (default is 20)
        for (var i = 0; i < 25; i++) {
          final provider = createTestPeerId(i);
          await dhtHandler.handleProvideRequest(cid, provider);
        }

        // Verify addProvider called exactly 20 times
        verify(mockDhtClient.addProvider(cid.toString(), any)).called(20);
      },
    );

    test('getStatus returns correct information', () async {
      when(mockDhtClient.isInitialized).thenReturn(true);
      when(mockRoutingTable.peerCount).thenReturn(5);

      final status = await dhtHandler.getStatus();
      expect(status['status'], 'active');
      expect(status['routing_table_size'], 5);

      when(mockDhtClient.isInitialized).thenReturn(false);
      final offlineStatus = await dhtHandler.getStatus();
      expect(offlineStatus['status'], 'disabled');
    });

    test('resolveDNSLink handles DHT path and errors', () async {
      final name = 'example.com';
      final realHash = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
      when(mockStorage.get(any)).thenAnswer((_) async => utf8.encode(realHash));

      final result = await dhtHandler.resolveDNSLink(name);
      expect(result, realHash);

      when(mockStorage.get(any)).thenThrow(Exception('storage error'));
      final errorResult = await dhtHandler.resolveDNSLink(name);
      expect(errorResult, isNull);
    });

    test('resolveIPNS fallback to public resolver and error paths', () async {
      final ipnsName = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
      final resolvedCid = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';

      // 1. Fail through DHT
      when(mockStorage.get(any)).thenAnswer((_) async => null);

      // Setup mock client for success
      final httpClient = MockClient((request) async {
        return http.Response('Found CID: $resolvedCid here', 200);
      });

      final handlerWithMock = DHTHandler(
        config,
        mockRouter,
        mockNetworkHandler,
        storage: mockStorage,
        client: mockDhtClient,
        keystore: mockKeystore,
        httpClient: httpClient,
      );

      final result = await handlerWithMock.resolveIPNS(ipnsName);
      expect(result, resolvedCid);

      // 2. Fail extraction
      final httpClientFailExtraction = MockClient((request) async {
        return http.Response('no cid here', 200);
      });
      final handlerFailExtraction = DHTHandler(
        config,
        mockRouter,
        mockNetworkHandler,
        storage: mockStorage,
        client: mockDhtClient,
        keystore: mockKeystore,
        httpClient: httpClientFailExtraction,
      );
      expect(
        () => handlerFailExtraction.resolveIPNS(ipnsName),
        throwsException,
      );

      // 3. Status 404
      final httpClient404 = MockClient((request) async {
        return http.Response('not found', 404);
      });
      final handler404 = DHTHandler(
        config,
        mockRouter,
        mockNetworkHandler,
        storage: mockStorage,
        client: mockDhtClient,
        keystore: mockKeystore,
        httpClient: httpClient404,
      );
      expect(() => handler404.resolveIPNS(ipnsName), throwsException);
    });

    test('getValue not found throws', () async {
      when(mockStorage.get(any)).thenAnswer((_) async => null);
      expect(
        () => dhtHandler.getValue(Key.fromString('missing')),
        throwsException,
      );
    });

    test('publishIPNS signature and sequence logic', () async {
      final keyName = 'self';
      // Mock a valid keypair
      final privKeyB64 = base64Url.encode(Uint8List(32));
      final pubKeyHex = '00' * 32;
      when(
        mockKeystore.getKeyPair(keyName),
      ).thenReturn(KeyPair(pubKeyHex, privKeyB64));
      when(mockStorage.get(any)).thenThrow(Exception('not found'));

      await dhtHandler.publishIPNS(
        'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
        keyName: keyName,
      );

      verify(mockStorage.put(any, any)).called(1);
    });

    test('provide and findPeer delegate and errors', () async {
      final p2pPeer = createTestP2PPeerId(2);
      final peer = PeerId(value: p2pPeer.value);
      final cid = createTestCID();
      when(mockRouter.peerId).thenReturn(p2pPeer);

      await dhtHandler.provide(cid);
      verify(mockDhtClient.addProvider(cid.toString(), any)).called(1);

      // Error in provide
      when(
        mockDhtClient.addProvider(any, any),
      ).thenThrow(Exception('dht error'));
      await dhtHandler.provide(cid); // should catch and not throw

      when(mockDhtClient.findPeer(peer)).thenAnswer((_) async => peer);
      final result = await dhtHandler.findPeer(peer);
      expect(result, isNotEmpty);

      // Error in findPeer
      when(mockDhtClient.findPeer(any)).thenThrow(Exception('find error'));
      final emptyResult = await dhtHandler.findPeer(peer);
      expect(emptyResult, isEmpty);
    });

    test('handleRoutingTableUpdate delegates', () async {
      final peerInfo = V_PeerInfo()..peerId = [1, 2, 3];
      await dhtHandler.handleRoutingTableUpdate(peerInfo);
      verify(mockRoutingTable.updatePeer(peerInfo)).called(1);
    });

    test('extractCIDFromResponse handles various formats', () {
      final response =
          'Content at QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco here';
      final cid = dhtHandler.extractCIDFromResponse(response);
      expect(cid, 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco');
    });

    test('isValidPeerID validates formats', () {
      expect(
        dhtHandler.isValidPeerID(
          'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
        ),
        isTrue,
      );
      expect(dhtHandler.isValidPeerID(''), isFalse);
    });
  });
}
