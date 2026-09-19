@TestOn('vm')
import 'dart:convert';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

/// End-to-end journeys through [DNSLinkHandler] — real resolver iteration,
/// response parsing, and caching — with the HTTP transport stubbed by a
/// scripted client (the production resolvers are hardcoded public HTTPS
/// endpoints and cannot be exercised hermetically).
void main() {
  final config = IPFSConfig(offline: true);

  DNSLinkHandler handlerWith(MockHandler fn) =>
      DNSLinkHandler(config, client: http_testing.MockClient(fn));

  group('E2E DNSLink resolution', () {
    test('resolves a CID from a resolver JSON response', () async {
      final handler = handlerWith((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'Path': 'bafkrei_resolved'}),
          200,
        );
      });

      expect(await handler.resolve('example.com'), 'bafkrei_resolved');
      await handler.stop();
    });

    test('accepts cid and Target response shapes', () async {
      var handler = handlerWith(
        (_) async =>
            http.Response(jsonEncode(<String, dynamic>{'cid': 'cid1'}), 200),
      );
      expect(await handler.resolve('a.example'), 'cid1');
      await handler.stop();

      handler = handlerWith(
        (_) async =>
            http.Response(jsonEncode(<String, dynamic>{'Target': 'cid2'}), 200),
      );
      expect(await handler.resolve('b.example'), 'cid2');
      await handler.stop();
    });

    test('falls through to the DNS TXT lookup on failure', () async {
      var calls = 0;
      final handler = handlerWith((request) async {
        calls++;
        if (calls == 1) {
          return http.Response('server error', 500);
        }
        // The DoH fallback answers with a _dnslink TXT record.
        expect(request.url.toString(), contains('dns.google'));
        return http.Response(
          jsonEncode(<String, dynamic>{
            'Answer': [
              {'type': 16, 'data': '"dnslink=/ipfs/bafkrei_fallback"'},
            ],
          }),
          200,
        );
      });

      expect(await handler.resolve('example.com'), '/ipfs/bafkrei_fallback');
      expect(calls, greaterThanOrEqualTo(2));
      await handler.stop();
    });

    test('returns null when every resolver fails', () async {
      final handler = handlerWith((_) async => http.Response('down', 503));
      expect(await handler.resolve('nowhere.example'), isNull);
      await handler.stop();
    });

    test('returns null for malformed resolver payloads', () async {
      final handler = handlerWith(
        (_) async =>
            http.Response(jsonEncode(<String, dynamic>{'nope': 1}), 200),
      );
      expect(await handler.resolve('bad.example'), isNull);
      await handler.stop();
    });

    test('serves repeated resolutions from cache', () async {
      var calls = 0;
      final handler = handlerWith((_) async {
        calls++;
        return http.Response(
          jsonEncode(<String, dynamic>{'Path': 'bafkrei_cached'}),
          200,
        );
      });

      expect(await handler.resolve('cached.example'), 'bafkrei_cached');
      expect(await handler.resolve('cached.example'), 'bafkrei_cached');
      expect(calls, equals(1));
      await handler.stop();
    });
  });
}

typedef MockHandler = Future<http.Response> Function(http.Request request);
