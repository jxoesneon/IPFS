import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';

import 'dht_handler_coverage_test.mocks.dart';

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

  group('DHTHandler provider record validation', () {
    test('valid provider record accepted', () {
      final provider = PeerId.fromBase58(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockRouter.resolvePeerId(provider.toBase58()),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      expect(handler.isValidProviderRecord(provider, cid, null), isTrue);
    });

    test('invalid provider record rejected when address is unparseable', () {
      final provider = PeerId.fromBase58(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockRouter.resolvePeerId(provider.toBase58()),
      ).thenReturn(['not-a-valid-multiaddr']);

      expect(handler.isValidProviderRecord(provider, cid, null), isFalse);
    });

    test('provider record with empty peer id rejected', () {
      final provider = PeerId(value: Uint8List(0));
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      expect(handler.isValidProviderRecord(provider, cid, null), isFalse);
    });

    test('provider record with expired ttl rejected', () {
      final provider = PeerId.fromBase58(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockRouter.resolvePeerId(provider.toBase58()),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      final expiredTtl = DateTime.now().subtract(const Duration(hours: 1));
      expect(handler.isValidProviderRecord(provider, cid, expiredTtl), isFalse);
    });

    test('handleProvideRequest rejects invalid provider records', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final provider = PeerId.fromBase58(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      when(mockRouter.resolvePeerId(provider.toBase58())).thenReturn([]);

      await handler.handleProvideRequest(cid, provider);
      verifyNever(mockClient.addProvider(any, any));
    });

    test('handleProvideRequest accepts valid provider records', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final provider = PeerId.fromBase58(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      when(
        mockRouter.resolvePeerId(provider.toBase58()),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);
      when(mockClient.addProvider(any, any)).thenAnswer((_) async {});

      await handler.handleProvideRequest(cid, provider);
      verify(
        mockClient.addProvider(cid.toString(), provider.toBase58()),
      ).called(1);
    });
  });
}
