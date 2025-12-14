import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:test/test.dart';

// Mocks
class MockConfig extends IPFSConfig {
  MockConfig() : super();
}

class MockNetworkHandler extends NetworkHandler {
  MockNetworkHandler() : super(MockConfig());
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockContentRouting implements ContentRouting {
  final List<String> providers;
  final String? dnsResult;

  MockContentRouting({this.providers = const [], this.dnsResult});

  @override
  Future<List<String>> findProviders(String cid) async {
    return providers;
  }

  @override
  Future<String?> resolveDNSLink(String domain) async {
    return dnsResult;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDelegatedRouting extends DelegatedRoutingHandler {
  final List<String> providers;
  final bool success;

  MockDelegatedRouting({this.providers = const [], this.success = true})
      : super(delegateEndpoint: 'http://mock');

  @override
  Future<RoutingResponse> findProviders(CID cid) async {
    return RoutingResponse(
      providers: providers,
      error: success ? null : 'Mock Error',
    );
  }
}

void main() {
  group('ContentRoutingHandler', () {
    late MockConfig config;
    late MockNetworkHandler networkHandler;
    late ContentRoutingHandler handler;

    setUp(() {
      config = MockConfig();
      networkHandler = MockNetworkHandler();
    });

    test('findProviders returns DHT providers if found', () async {
      final mockContent = MockContentRouting(providers: ['PeerA', 'PeerB']);
      final mockDelegated = MockDelegatedRouting(providers: []);

      handler = ContentRoutingHandler(
        config,
        networkHandler,
        contentRouting: mockContent,
        delegatedRouting: mockDelegated,
      );

      final providers = await handler.findProviders('QmCID');
      expect(providers, hasLength(2));
      expect(providers, contains('PeerA'));
    });

    test('findProviders falls back to Delegated Routing if DHT fails',
        () async {
      final mockContent = MockContentRouting(providers: []); // Empty DHT
      final mockDelegated =
          MockDelegatedRouting(providers: ['PeerC']); // Delegated has it

      handler = ContentRoutingHandler(
        config,
        networkHandler,
        contentRouting: mockContent,
        delegatedRouting: mockDelegated,
      );

      final validCid = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';

      final result = await handler.findProviders(validCid);
      expect(result, hasLength(1));
      expect(result.first, 'PeerC');
    });

    test('resolveDNSLink falls back to DHT if DNS fails', () async {
      // Assuming DNSLinkResolver.resolve returns null for this domain
      final domain = 'example.com';
      final mockContent = MockContentRouting(dnsResult: 'QmResolved');

      handler = ContentRoutingHandler(
        config,
        networkHandler,
        contentRouting: mockContent,
      );

      final result = await handler.resolveDNSLink(domain);
      expect(result, 'QmResolved');
    });
  });
}
