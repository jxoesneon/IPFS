import 'dart:convert';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DNSLinkHandler', () {
    final config = IPFSConfig();

    test('resolve returns CID from public resolver', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('dnslink.io')) {
          return http.Response(jsonEncode({'Path': '/ipfs/QmHash'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('example.com');

      expect(result, '/ipfs/QmHash');
    });

    test('resolve caches result', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(jsonEncode({'Path': '/ipfs/QmCache'}), 200);
      });

      final handler = DNSLinkHandler(config, client: mockClient);

      // First call
      final result1 = await handler.resolve('cached.com');
      expect(result1, '/ipfs/QmCache');
      expect(callCount, 1);

      // Second call (should be cached)
      final result2 = await handler.resolve('cached.com');
      expect(result2, '/ipfs/QmCache');
      expect(callCount, 1);
    });

    test('resolve tries fallback resolvers on failure', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // First resolver fails
        if (request.url.toString().contains('dnslink.io')) {
          return http.Response('Error', 500);
        }
        // Second resolver succeeds (based on the list order in handler)
        // Order: dnslink.io -> example.com -> ipfs.io
        if (request.url.toString().contains('example.com')) {
          return http.Response(jsonEncode({'cid': 'QmFallback'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('fallback.com');

      expect(result, 'QmFallback');
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('resolve returns null when all fail', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Failed', 500);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('failed.com');

      expect(result, isNull);
    });

    test('start and stop clear cache', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'Path': '/ipfs/QmHash'}), 200);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      await handler.start();

      // Populate cache
      await handler.resolve('test.com');
      var status = await handler.getStatus();
      expect(status['cache_size'], 1);

      await handler.stop();
      status = await handler.getStatus();
      expect(status['cache_size'], 0);
    });
  });
}
