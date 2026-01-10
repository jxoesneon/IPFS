import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:http/http.dart' as http;

import 'content_routing_handler_test.mocks.dart';

@GenerateMocks([
  NetworkHandler,
  ContentRouting,
  DelegatedRoutingHandler,
  http.Client,
])
void main() {
  group('ContentRoutingHandler', () {
    late IPFSConfig config;
    late MockNetworkHandler networkHandler;
    late MockClient dnsClient;
    late ContentRoutingHandler handler;

    setUp(() {
      config = IPFSConfig();
      networkHandler = MockNetworkHandler();
      dnsClient = MockClient();
    });

    test('findProviders returns DHT providers if found', () async {
      final mockContent = MockContentRouting();
      final mockDelegated = MockDelegatedRoutingHandler();

      when(
        mockContent.findProviders(any),
      ).thenAnswer((_) async => ['PeerA', 'PeerB']);

      handler = ContentRoutingHandler(
        config,
        networkHandler,
        contentRouting: mockContent,
        delegatedRouting: mockDelegated,
        dnsClient: dnsClient,
      );

      final providers = await handler.findProviders('QmCID');
      expect(providers, hasLength(2));
      expect(providers, contains('PeerA'));
      verifyNever(mockDelegated.findProviders(any));
    });

    test(
      'findProviders falls back to Delegated Routing if DHT fails',
      () async {
        final mockContent = MockContentRouting();
        final mockDelegated = MockDelegatedRoutingHandler();

        when(mockContent.findProviders(any)).thenAnswer((_) async => []);
        when(
          mockDelegated.findProviders(any),
        ).thenAnswer((_) async => RoutingResponse(providers: ['PeerC']));

        handler = ContentRoutingHandler(
          config,
          networkHandler,
          contentRouting: mockContent,
          delegatedRouting: mockDelegated,
          dnsClient: dnsClient,
        );

        final validCid = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';

        final result = await handler.findProviders(validCid);
        expect(result, hasLength(1));
        expect(result.first, 'PeerC');
      },
    );

    test('resolveDNSLink falls back to DHT if DNS fails', () async {
      final domain = 'example.com';
      final mockContent = MockContentRouting();

      // Mock DNSLink failure (404)
      when(
        dnsClient.get(any),
      ).thenAnswer((_) async => http.Response('Not Found', 404));
      when(
        mockContent.resolveDNSLink(any),
      ).thenAnswer((_) async => 'QmResolved');

      handler = ContentRoutingHandler(
        config,
        networkHandler,
        contentRouting: mockContent,
        dnsClient: dnsClient,
      );

      final result = await handler.resolveDNSLink(domain);
      expect(result, 'QmResolved');
      verify(dnsClient.get(any)).called(1);
    });
  });
}
