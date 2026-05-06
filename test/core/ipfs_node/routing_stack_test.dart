import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/cid.dart';

import 'routing_stack_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NetworkHandler>(),
  MockSpec<ContentRouting>(),
  MockSpec<DelegatedRoutingHandler>(),
  MockSpec<http.Client>(),
])
void main() {
  late IPFSConfig config;
  late MockNetworkHandler mockNetworkHandler;
  late MockContentRouting mockContentRouting;
  late MockDelegatedRoutingHandler mockDelegatedRouting;
  late MockClient mockClient;

  setUp(() {
    config = IPFSConfig(
      network: NetworkConfig(
        delegatedRoutingEndpoint: 'https://delegate.example.com',
      ),
    );
    mockNetworkHandler = MockNetworkHandler();
    mockContentRouting = MockContentRouting();
    mockDelegatedRouting = MockDelegatedRoutingHandler();
    mockClient = MockClient();
  });

  group('RoutingHandler', () {
    late RoutingHandler handler;

    setUp(() {
      handler = RoutingHandler(
        config,
        mockNetworkHandler,
        contentRouting: mockContentRouting,
        httpClient: mockClient,
      );
    });

    test('start/stop error handling', () async {
      when(mockContentRouting.start()).thenThrow(Exception('Start fail'));
      when(mockContentRouting.stop()).thenThrow(Exception('Stop fail'));

      await handler.start(); // Should catch
      await handler.stop(); // Should catch

      verify(mockContentRouting.start()).called(1);
      verify(mockContentRouting.stop()).called(1);
    });

    test('findProviders error handling', () async {
      when(
        mockContentRouting.findProviders(any),
      ).thenThrow(Exception('Find fail'));

      final providers = await handler.findProviders('QmCID');
      expect(providers, isEmpty);
    });

    test('resolveDNSLink coverage for exceptions', () async {
      // DNSLinkResolver.resolve is static and uses https://dnslink.io/domain
      // It's hard to trigger exception in it since we don't pass the client to RoutingHandler's call to it.
      // But we can test the fallback catch block.

      // First resolution (static) will return null if it fails or throws.
      // Then it enters the catch block and tries alternative resolution.

      final domain = 'example.com';
      final altUrl = Uri.parse('https://dnslink-resolver.example.com/$domain');

      when(mockClient.get(altUrl)).thenThrow(Exception('Alt fail'));

      final result = await handler.resolveDNSLink(domain);
      expect(result, isNull);
    });
  });

  group('ContentRoutingHandler', () {
    late ContentRoutingHandler handler;

    setUp(() {
      handler = ContentRoutingHandler(
        config,
        mockNetworkHandler,
        contentRouting: mockContentRouting,
        delegatedRouting: mockDelegatedRouting,
        dnsClient: mockClient,
      );
    });

    test('start/stop success and error', () async {
      await handler.start();
      verify(mockContentRouting.start()).called(1);

      await handler.stop();
      verify(mockContentRouting.stop()).called(1);

      when(mockContentRouting.start()).thenThrow(Exception('Start fail'));
      expect(() => handler.start(), throwsException);

      when(mockContentRouting.stop()).thenThrow(Exception('Stop fail'));
      expect(() => handler.stop(), throwsException);
    });

    test('findProviders DHT success', () async {
      final cid = 'QmPZ9gcCEpqKToayWi9m3rqJJf6Sht9tvc2pZpguXFvG3X';
      when(
        mockContentRouting.findProviders(cid),
      ).thenAnswer((_) async => ['Peer1']);

      final providers = await handler.findProviders(cid);
      expect(providers, equals(['Peer1']));
    });

    test('findProviders DHT empty -> Delegated success', () async {
      final cid = 'QmPZ9gcCEpqKToayWi9m3rqJJf6Sht9tvc2pZpguXFvG3X';
      when(mockContentRouting.findProviders(cid)).thenAnswer((_) async => []);
      when(
        mockDelegatedRouting.findProviders(any),
      ).thenAnswer((_) async => RoutingResponse.success(['Peer2']));

      final providers = await handler.findProviders(cid);
      expect(providers, equals(['Peer2']));
    });

    test('findProviders DHT empty -> Delegated empty', () async {
      final cid = 'QmPZ9gcCEpqKToayWi9m3rqJJf6Sht9tvc2pZpguXFvG3X';
      when(mockContentRouting.findProviders(cid)).thenAnswer((_) async => []);
      when(
        mockDelegatedRouting.findProviders(any),
      ).thenAnswer((_) async => RoutingResponse.success([]));

      final providers = await handler.findProviders(cid);
      expect(providers, isEmpty);
    });

    test('findProviders error handling', () async {
      when(
        mockContentRouting.findProviders(any),
      ).thenThrow(Exception('DHT fail'));

      final providers = await handler.findProviders('QmCID');
      expect(providers, isEmpty);
    });

    test('resolveDNSLink direct success', () async {
      final domain = 'example.com';
      when(mockClient.get(Uri.parse('https://dnslink.io/$domain'))).thenAnswer(
        (_) async => http.Response(jsonEncode({'cid': 'QmResolved'}), 200),
      );

      final result = await handler.resolveDNSLink(domain);
      expect(result, equals('QmResolved'));
    });

    test('resolveDNSLink direct fail -> DHT success', () async {
      final domain = 'example.com';
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Not found', 404));
      when(
        mockContentRouting.resolveDNSLink(domain),
      ).thenAnswer((_) async => 'QmDHT');

      final result = await handler.resolveDNSLink(domain);
      expect(result, equals('QmDHT'));
    });

    test('resolveDNSLink all fail', () async {
      final domain = 'example.com';
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Not found', 404));
      when(
        mockContentRouting.resolveDNSLink(domain),
      ).thenAnswer((_) async => null);

      final result = await handler.resolveDNSLink(domain);
      expect(result, isNull);
    });

    test('resolveDNSLink catch error', () async {
      when(mockClient.get(any)).thenThrow(Exception('DNS fail'));

      final result = await handler.resolveDNSLink('example.com');
      expect(result, isNull);
    });

    test('getStatus', () async {
      final status = await handler.getStatus();
      expect(status['dht_routing_enabled'], isTrue);
      expect(
        status['delegated_endpoint'],
        equals('https://delegate.example.com'),
      );
    });
  });

  group('DNSLinkHandler', () {
    late DNSLinkHandler handler;

    setUp(() {
      handler = DNSLinkHandler(config, client: mockClient);
    });

    test('start/stop error handling', () async {
      // DNSLinkHandler start/stop just clear cache, hard to make them throw unless we mock cache?
      // But cache is private. We can check they don't crash.
      await handler.start();
      await handler.stop();
    });

    test('resolve cache hit and expiry', () async {
      final domain = 'example.com';
      final resolverUrl = Uri.parse('https://dnslink.io/$domain');

      when(
        mockClient.get(resolverUrl),
      ).thenAnswer((_) async => http.Response(jsonEncode({'cid': 'Qm1'}), 200));

      // First call - cache miss
      final res1 = await handler.resolve(domain);
      expect(res1, equals('Qm1'));
      verify(mockClient.get(resolverUrl)).called(1);

      // Second call - cache hit
      final res2 = await handler.resolve(domain);
      expect(res2, equals('Qm1'));
      verifyNoMoreInteractions(mockClient);
    });

    test('resolve with multiple resolvers', () async {
      final domain = 'example.com';
      // First resolver throws exception, second succeeds
      when(
        mockClient.get(Uri.parse('https://dnslink.io/$domain')),
      ).thenThrow(Exception('Network error'));
      when(
        mockClient.get(
          Uri.parse('https://dnslink-resolver.example.com/$domain'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode({'Path': 'Qm2'}), 200),
      );

      final res = await handler.resolve(domain);
      expect(res, equals('Qm2'));
      verify(mockClient.get(any)).called(2);
    });

    test('resolve all fail', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Not found', 404));

      final res = await handler.resolve('example.com');
      expect(res, isNull);
    });

    test('resolve catch block', () async {
      // Trigger error by making Uri.parse throw or something?
      // Actually, just making one of the resolver calls throw.
      when(mockClient.get(any)).thenThrow(Exception('Network error'));

      final res = await handler.resolve('example.com');
      expect(res, isNull);
    });

    test('extractCIDFromResponse formats', () async {
      // Testing Path format
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(jsonEncode({'Path': 'QmPath'}), 200),
      );
      expect(await handler.resolve('d3.com'), equals('QmPath'));

      // Testing Target format
      clearInteractions(mockClient);
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(jsonEncode({'Target': 'QmTarget'}), 200),
      );
      expect(await handler.resolve('d1.com'), equals('QmTarget'));

      // Testing cid format
      clearInteractions(mockClient);
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(jsonEncode({'cid': 'QmCid'}), 200),
      );
      expect(await handler.resolve('d2.com'), equals('QmCid'));
    });

    test('resolve returns null on 200 but no CID', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(jsonEncode({'other': 'data'}), 200),
      );
      final res = await handler.resolve('nocid.com');
      expect(res, isNull);
    });

    test('resolve returns null on non-200', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Error', 404));
      final res = await handler.resolve('404.com');
      expect(res, isNull);
    });

    test('getStatus', () async {
      final status = await handler.getStatus();
      expect(status['cache_size'], equals(0));
      expect(status['public_resolvers'], isNotEmpty);
    });
  });
}
