import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';

import 'routing_handler_test.mocks.dart';

@GenerateMocks([NetworkHandler, ContentRouting, IPFSConfig])
void main() {
  group('RoutingHandler', () {
    late RoutingHandler routingHandler;
    late MockIPFSConfig mockConfig;
    late MockNetworkHandler mockNetworkHandler;
    late MockContentRouting mockContentRouting;

    setUp(() {
      mockConfig = MockIPFSConfig();
      mockNetworkHandler = MockNetworkHandler();
      mockContentRouting = MockContentRouting();

      routingHandler = RoutingHandler(
        mockConfig,
        mockNetworkHandler,
        contentRouting: mockContentRouting,
      );
    });

    test('start initializes content routing', () async {
      when(mockContentRouting.start()).thenAnswer((_) async {});

      await routingHandler.start();

      verify(mockContentRouting.start()).called(1);
    });

    test('start handles errors gracefully', () async {
      when(mockContentRouting.start()).thenThrow(Exception('Start failed'));

      // Should not throw
      await routingHandler.start();

      verify(mockContentRouting.start()).called(1);
    });

    test('stop terminates content routing', () async {
      when(mockContentRouting.stop()).thenAnswer((_) async {});

      await routingHandler.stop();

      verify(mockContentRouting.stop()).called(1);
    });

    test('stop handles errors gracefully', () async {
      when(mockContentRouting.stop()).thenThrow(Exception('Stop failed'));

      // Should not throw
      await routingHandler.stop();

      verify(mockContentRouting.stop()).called(1);
    });

    test('findProviders delegates to contentRouting', () async {
      const cid = 'QmTest';
      final providers = ['/ip4/127.0.0.1/tcp/4001'];
      when(mockContentRouting.findProviders(cid)).thenAnswer((_) async => providers);

      final result = await routingHandler.findProviders(cid);

      expect(result, equals(providers));
      verify(mockContentRouting.findProviders(cid)).called(1);
    });

    test('findProviders returns empty list on error', () async {
      const cid = 'QmTest';
      when(mockContentRouting.findProviders(cid)).thenThrow(Exception('Lookup failed'));

      final result = await routingHandler.findProviders(cid);

      expect(result, isEmpty);
      verify(mockContentRouting.findProviders(cid)).called(1);
    });
  });
}
