import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:dart_ipfs/src/core/cid.dart';

import 'content_routing_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NetworkHandler>(),
  MockSpec<ContentRouting>(),
  MockSpec<DelegatedRoutingHandler>(),
])
void main() {
  late ContentRoutingHandler handler;
  late MockNetworkHandler mockNetworkHandler;
  late MockContentRouting mockContentRouting;
  late MockDelegatedRoutingHandler mockDelegatedRouting;
  // ContentRoutingHandler seems to use ContentRouting, not DHTHandler directly
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    mockContentRouting = MockContentRouting();
    mockDelegatedRouting = MockDelegatedRoutingHandler();
    config = IPFSConfig();
    handler = ContentRoutingHandler(
      config,
      mockNetworkHandler,
      contentRouting: mockContentRouting,
      delegatedRouting: mockDelegatedRouting,
    );
  });

  group('ContentRoutingHandler', () {
    test('start and stop', () async {
      await handler.start();
      verify(mockContentRouting.start()).called(1);

      await handler.stop();
      verify(mockContentRouting.stop()).called(1);
    });

    test('findProviders DHT success', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockContentRouting.findProviders(cid),
      ).thenAnswer((_) async => ['peer1']);

      final providers = await handler.findProviders(cid);
      expect(providers, equals(['peer1']));
      verifyNever(mockDelegatedRouting.findProviders(any));
    });

    test('findProviders DHT fail fallback to delegated', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockContentRouting.findProviders(cid)).thenAnswer((_) async => []);
      when(
        mockDelegatedRouting.findProviders(any),
      ).thenAnswer((_) async => RoutingResponse.success(['peer2']));

      final providers = await handler.findProviders(cid);
      expect(providers, equals(['peer2']));
    });

    test('findProviders all fail', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockContentRouting.findProviders(cid)).thenAnswer((_) async => []);
      when(
        mockDelegatedRouting.findProviders(any),
      ).thenAnswer((_) async => RoutingResponse.success([]));

      final providers = await handler.findProviders(cid);
      expect(providers, isEmpty);
    });

    test('resolveDNSLink DHT fallback', () async {
      final domain = 'example.com';
      // Assume DNSLinkResolver.resolve fails (returns null) in test environment
      when(
        mockContentRouting.resolveDNSLink(domain),
      ).thenAnswer((_) async => 'QmResolved');

      final result = await handler.resolveDNSLink(domain);
      expect(result, equals('QmResolved'));
    });

    test('findProviders catches exceptions', () async {
      when(mockContentRouting.findProviders(any)).thenThrow(Exception('Fail'));
      final providers = await handler.findProviders('cid');
      expect(providers, isEmpty);
    });

    test('getStatus', () async {
      final status = await handler.getStatus();
      expect(status, isA<Map<String, dynamic>>());
      expect(status['dht_routing_enabled'], isTrue);
    });
  });
}
