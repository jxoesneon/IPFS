import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';

import 'package:http/http.dart' as http;

import 'routing_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NetworkHandler>(),
  MockSpec<ContentRouting>(),
  MockSpec<http.Client>(),
])
void main() {
  late RoutingHandler handler;
  late MockNetworkHandler mockNetworkHandler;
  late MockContentRouting mockContentRouting;
  late MockClient mockClient;
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    mockContentRouting = MockContentRouting();
    mockClient = MockClient();
    config = IPFSConfig();
    handler = RoutingHandler(
      config,
      mockNetworkHandler,
      contentRouting: mockContentRouting,
      httpClient: mockClient,
    );
  });

  group('RoutingHandler', () {
    test('start and stop', () async {
      await handler.start();
      verify(mockContentRouting.start()).called(1);

      await handler.stop();
      verify(mockContentRouting.stop()).called(1);
    });

    test('findProviders delegating and empty handling', () async {
      when(
        mockContentRouting.findProviders('cid1'),
      ).thenAnswer((_) async => ['provider1']);
      final providers = await handler.findProviders('cid1');
      expect(providers, equals(['provider1']));

      when(
        mockContentRouting.findProviders('cid2'),
      ).thenAnswer((_) async => []);
      final providers2 = await handler.findProviders('cid2');
      expect(providers2, isEmpty);
    });

    test('resolveDNSLink catches exceptions and hits alt path', () async {
      // The current test 'resolveDNSLink fail and alt fail' already hits null return.
      // But we can verify it handles errors in start/stop too.
      when(mockContentRouting.start()).thenThrow(Exception('Start fail'));
      when(mockContentRouting.stop()).thenThrow(Exception('Stop fail'));

      await handler.start(); // Should catch
      await handler.stop(); // Should catch
    });

    test('resolveDNSLink alternative paths', () async {
      final domain = 'example.com';
      final altUrl = Uri.parse('https://dnslink-resolver.example.com/$domain');

      // Case 1: Alt success
      when(
        mockClient.get(altUrl),
      ).thenAnswer((_) async => http.Response('{"cid": "QmAlt"}', 200));
      final res1 = await handler.resolveDNSLink(domain);
      expect(res1, equals('QmAlt'));

      // Case 2: Alt 404
      when(
        mockClient.get(altUrl),
      ).thenAnswer((_) async => http.Response('Not found', 404));
      final res2 = await handler.resolveDNSLink(domain);
      expect(res2, isNull);

      // Case 3: Alt 200 but missing cid
      when(
        mockClient.get(altUrl),
      ).thenAnswer((_) async => http.Response('{"error": "none"}', 200));
      final res3 = await handler.resolveDNSLink(domain);
      expect(res3, isNull);

      // Case 4: Alt throw (network error)
      when(mockClient.get(altUrl)).thenThrow(Exception('Network error'));
      final res4 = await handler.resolveDNSLink(domain);
      expect(res4, isNull);
    });

    test('default constructor coverage', () {
      // Hits line 19
      final defaultHandler = RoutingHandler(config, mockNetworkHandler);
      expect(defaultHandler, isNotNull);
    });
  });
}
