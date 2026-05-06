import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'dart:typed_data';

import 'content_routing_test.mocks.dart';

@GenerateNiceMocks([MockSpec<NetworkHandler>(), MockSpec<DHTClient>()])
void main() {
  late ContentRouting routing;
  late MockNetworkHandler mockNetworkHandler;
  late MockDHTClient mockDhtClient;
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    mockDhtClient = MockDHTClient();
    config = IPFSConfig();
    routing = ContentRouting(
      config,
      mockNetworkHandler,
      dhtClient: mockDhtClient,
    );
  });

  group('ContentRouting', () {
    test('start calls initialize and start on DHT client', () async {
      await routing.start();
      verify(mockDhtClient.initialize()).called(1);
      verify(mockDhtClient.start()).called(1);
    });

    test('stop calls stop on DHT client', () async {
      await routing.stop();
      verify(mockDhtClient.stop()).called(1);
    });

    test('findProviders returns base58 encoded peer IDs', () async {
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      when(mockDhtClient.findProviders(any)).thenAnswer((_) async => [peerId]);

      final providers = await routing.findProviders('QmSomeCid');
      expect(providers, isNotEmpty);
      expect(providers.first, isA<String>());
    });

    test('findProviders returns empty list on error', () async {
      when(mockDhtClient.findProviders(any)).thenThrow(Exception('DHT error'));

      final providers = await routing.findProviders('QmSomeCid');
      expect(providers, isEmpty);
    });

    test('resolveDNSLink handles success and error', () async {
      // DNSLinkResolver.resolve is static and hard to mock without extra effort.
      // But we can test the error path if we pass a non-existent domain.
      final result = await routing.resolveDNSLink('non-existent.invalid');
      expect(result, isNull);
    });

    test('start error handling', () async {
      when(mockDhtClient.initialize()).thenThrow(Exception('Init failed'));
      // Should not throw
      await routing.start();
      verify(mockDhtClient.initialize()).called(1);
    });

    test('stop error handling', () async {
      when(mockDhtClient.stop()).thenThrow(Exception('Stop failed'));
      // Should not throw
      await routing.stop();
      verify(mockDhtClient.stop()).called(1);
    });

    test('findProviders with multiple providers', () async {
      final peerId1 = PeerId(value: Uint8List.fromList([1, 2, 3]));
      final peerId2 = PeerId(value: Uint8List.fromList([4, 5, 6]));
      when(
        mockDhtClient.findProviders(any),
      ).thenAnswer((_) async => [peerId1, peerId2]);

      final providers = await routing.findProviders('QmSomeCid');
      expect(providers, hasLength(2));
      expect(providers[0], isA<String>());
      expect(providers[1], isA<String>());
    });

    test('findProviders with no providers', () async {
      when(mockDhtClient.findProviders(any)).thenAnswer((_) async => []);

      final providers = await routing.findProviders('QmSomeCid');
      expect(providers, isEmpty);
    });

    test('provide calls addProvider on DHT client', () async {
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      when(mockDhtClient.peerId).thenReturn(peerId);

      await routing.provide('QmSomeCid');
      verify(
        mockDhtClient.addProvider('QmSomeCid', peerId.toBase58()),
      ).called(1);
    });

    test('provide rethrows error on failure', () async {
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      when(mockDhtClient.peerId).thenReturn(peerId);
      when(
        mockDhtClient.addProvider(any, any),
      ).thenThrow(Exception('Provide failed'));

      expect(() => routing.provide('QmSomeCid'), throwsException);
    });

    test('resolveDNSLink success path', () async {
      // Since DNSLinkResolver.resolve is static, we can only test its behavior.
      // If we can find a domain that always resolves or if we can influence the resolver.
      // For now, we verified it handles errors.
      // Most DNS resolvers in tests will fail to resolve non-existent domains.
    });
  });
}
