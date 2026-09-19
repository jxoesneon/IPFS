import 'dart:convert';
import 'dart:mirrors' as mirrors;

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

    test('resolve falls back to DNS TXT lookup on failure', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // The JSON resolver fails
        if (request.url.toString().contains('dnslink.io')) {
          return http.Response('Error', 500);
        }
        // The DNS-over-HTTPS TXT lookup answers with a dnslink record
        if (request.url.toString().contains('dns.google')) {
          return http.Response(
            jsonEncode({
              'Answer': [
                {'type': 16, 'data': '"dnslink=/ipfs/QmFallback"'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('fallback.com');

      expect(result, '/ipfs/QmFallback');
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

    test('resolve evicts an expired cache entry', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'Path': '/ipfs/QmFresh'}), 200);
      });

      final handler = DNSLinkHandler(config, client: mockClient);

      // Seed the private cache with an entry whose timestamp is already
      // beyond the TTL; there is no public seam for pre-aging entries, so
      // mirrors place a stale _CachedDNSLink directly.
      final handlerLibrary = mirrors
          .currentMirrorSystem()
          .libraries
          .values
          .firstWhere(
            (lib) => lib.uri.path.endsWith('ipfs_node/dns_link_handler.dart'),
          );
      final cache =
          mirrors
                  .reflect(handler)
                  .getField(
                    mirrors.MirrorSystem.getSymbol('_cache', handlerLibrary),
                  )
                  .reflectee
              as Map<dynamic, dynamic>;
      final entryType =
          handlerLibrary.declarations[mirrors.MirrorSystem.getSymbol(
                '_CachedDNSLink',
                handlerLibrary,
              )]!
              as mirrors.ClassMirror;
      final stale = entryType.newInstance(const Symbol(''), [], {
        #cid: '/ipfs/QmStale',
        #timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      }).reflectee;
      cache['expired.com'] = stale;

      // The stale entry is evicted and the domain resolves fresh.
      final result = await handler.resolve('expired.com');
      expect(result, '/ipfs/QmFresh');
    });

    test('resolve ignores a malformed JSON resolver body', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('dnslink.io')) {
          return http.Response('this is not json', 200);
        }
        return http.Response('Failed', 500);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('badjson.com');
      expect(result, isNull);
    });

    test('resolve ignores a malformed DoH response body', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('dns.google')) {
          return http.Response('<html>not json</html>', 200);
        }
        return http.Response('Failed', 500);
      });

      final handler = DNSLinkHandler(config, client: mockClient);
      final result = await handler.resolve('baddoh.com');
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
