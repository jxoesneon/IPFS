import 'dart:typed_data';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipns.pb.dart';
import 'package:fixnum/fixnum.dart';

import 'dht_handler_coverage_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DHTClient>(),
  MockSpec<RouterInterface>(),
  MockSpec<NetworkHandler>(),
  MockSpec<ds.Datastore>(),
  MockSpec<Keystore>(),
  MockSpec<http.Client>(),
  MockSpec<KademliaRoutingTable>(),
])
void main() {
  late DHTHandler handler;
  late MockDHTClient mockClient;
  late MockRouterInterface mockRouter;
  late MockNetworkHandler mockNetworkHandler;
  late MockDatastore mockStorage;
  late MockKeystore mockKeystore;
  late MockClient mockHttpClient;
  late MockKademliaRoutingTable mockRoutingTable;
  late IPFSConfig config;

  setUp(() {
    mockClient = MockDHTClient();
    mockRouter = MockRouterInterface();
    mockNetworkHandler = MockNetworkHandler();
    mockStorage = MockDatastore();
    mockKeystore = MockKeystore();
    mockHttpClient = MockClient();
    mockRoutingTable = MockKademliaRoutingTable();
    config = IPFSConfig();

    when(mockClient.kademliaRoutingTable).thenReturn(mockRoutingTable);

    handler = DHTHandler(
      config,
      mockRouter,
      mockNetworkHandler,
      client: mockClient,
      storage: mockStorage,
      keystore: mockKeystore,
      httpClient: mockHttpClient,
    );
  });

  group('DHTHandler', () {
    test('start/stop lifecycle', () async {
      await handler.start();
      verify(mockClient.start()).called(1);
      await handler.stop();
      verify(mockClient.stop()).called(1);
    });

    test('findProviders delegates to client', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      when(mockClient.findProviders(any)).thenAnswer(
        (_) async => [
          PeerId(value: Uint8List.fromList([1, 2, 3])),
        ],
      );

      final providers = await handler.findProviders(cid);
      expect(providers, isNotEmpty);
      expect(providers.first.peerId, equals([1, 2, 3]));
    });

    test('putValue/getValue operations', () async {
      final key = Key(Uint8List.fromList([1, 1, 1]));
      final value = Value(Uint8List.fromList([2, 2, 2]));

      await handler.putValue(key, value);
      verify(mockStorage.put(any, any)).called(1);

      when(
        mockStorage.get(any),
      ).thenAnswer((_) async => Uint8List.fromList([2, 2, 2]));
      final result = await handler.getValue(key);
      expect(result.bytes, equals([2, 2, 2]));
    });

    test('resolveIPNS via DHT success', () async {
      final ipnsName = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockStorage.get(any),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('QmTarget')));

      final result = await handler.resolveIPNS(ipnsName);
      expect(result, equals('QmTarget'));
    });

    test('resolveIPNS via HTTP fallback', () async {
      final ipnsName = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockStorage.get(any)).thenAnswer((_) async => null);
      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => http.Response(
          '<html>QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn</html>',
          200,
        ),
      );

      final result = await handler.resolveIPNS(ipnsName);
      expect(result, equals('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'));
    });

    test('resolveIPNS fails all methods', () async {
      final ipnsName = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockStorage.get(any)).thenAnswer((_) async => null);
      when(mockHttpClient.get(any)).thenThrow(Exception('HTTP error'));

      expect(() => handler.resolveIPNS(ipnsName), throwsA(isA<Exception>()));
    });

    test('publishIPNS success', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final keyName = 'self';

      final privKeyBytes = Uint8List(32)..fillRange(0, 32, 1);
      final privKeyStr = base64Url.encode(privKeyBytes);
      final keyPair = KeyPair('QmPub', privKeyStr);

      when(mockKeystore.getKeyPair(keyName)).thenReturn(keyPair);
      when(mockStorage.get(any)).thenAnswer((_) async => null);

      await handler.publishIPNS(cid, keyName: keyName);
      verify(mockStorage.put(any, any)).called(1);
    });

    test('publishIPNS with existing record increments sequence', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final keyName = 'self';

      final privKeyBytes = Uint8List(32)..fillRange(0, 32, 1);
      final privKeyStr = base64Url.encode(privKeyBytes);
      final keyPair = KeyPair('QmPub', privKeyStr);

      when(mockKeystore.getKeyPair(keyName)).thenReturn(keyPair);

      final existingEntry = IpnsEntry()..sequence = Int64(5);
      when(
        mockStorage.get(any),
      ).thenAnswer((_) async => existingEntry.writeToBuffer());

      await handler.publishIPNS(cid, keyName: keyName);

      final captured =
          verify(mockStorage.put(any, captureAny)).captured.single as Uint8List;
      final newEntry = IpnsEntry.fromBuffer(captured);
      expect(newEntry.sequence, equals(Int64(6)));
    });

    test('provide delegates to client', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      when(mockRouter.peerID).thenReturn('localPeer');

      await handler.provide(cid);
      verify(mockClient.addProvider(cid.toString(), 'localPeer')).called(1);
    });

    test('findPeer delegates to client', () async {
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      when(
        mockClient.findPeer(peerId),
      ).thenAnswer((_) async => PeerId(value: Uint8List.fromList([1, 2, 3])));

      final results = await handler.findPeer(peerId);
      expect(results, isNotEmpty);
      expect(results.first.peerId, equals([1, 2, 3]));
    });

    test('handleRoutingTableUpdate delegates to client', () async {
      final peerInfo = V_PeerInfo()..peerId = [1, 2, 3];
      await handler.handleRoutingTableUpdate(peerInfo);
      verify(mockRoutingTable.updatePeer(peerInfo)).called(1);
    });

    test('handleProvideRequest with rate limiting', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final provider = PeerId(value: Uint8List.fromList([1, 2, 3]));

      for (int i = 0; i < 11; i++) {
        await handler.handleProvideRequest(cid, provider);
      }

      verify(mockClient.addProvider(any, any)).called(10);
    });

    test('handleProvideRequest max providers check', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      for (int i = 0; i < 20; i++) {
        final provider = PeerId(value: Uint8List.fromList([i]));
        await handler.handleProvideRequest(cid, provider);
      }

      // 21st provider should be rejected
      final provider21 = PeerId(value: Uint8List.fromList([21]));
      await handler.handleProvideRequest(cid, provider21);

      verify(mockClient.addProvider(any, any)).called(20);
    });

    test('getStatus returns correct info', () async {
      when(mockClient.isInitialized).thenReturn(true);
      when(mockRoutingTable.peerCount).thenReturn(5);

      final status = await handler.getStatus();
      expect(status['status'], equals('active'));
      expect(status['routing_table_size'], equals(5));
    });

    test('resolveDNSLink success', () async {
      final domain = 'ipfs.io';
      final validCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockStorage.get(any),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode(validCid)));

      final result = await handler.resolveDNSLink(domain);
      expect(result, equals(validCid));
    });

    test('resolveDNSLink DHT success but invalid CID format', () async {
      final domain = 'ipfs.io';
      when(
        mockStorage.get(any),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('invalid-cid')));

      final result = await handler.resolveDNSLink(domain);
      expect(result, isNull);
    });
  });
}
