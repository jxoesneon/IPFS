import 'dart:io';

import 'package:dart_ipfs/src/transport/dns_multiaddr_resolver_io.dart';
import 'package:test/test.dart';

void main() {
  group('resolveDnsMultiAddr', () {
    test('resolves /dns4/ to an /ip4/ address', () async {
      final result = await resolveDnsMultiAddr('/dns4/localhost/tcp/4001');
      expect(result, matches(r'^/ip4/\d+\.\d+\.\d+\.\d+/tcp/4001$'));
    });

    test('resolves /dns6/ to an /ip6/ address', () async {
      final result = await resolveDnsMultiAddr('/dns6/localhost/tcp/4001');
      expect(result, startsWith('/ip6/'));
      expect(result, endsWith('/tcp/4001'));
    });

    test('degrades /dnsaddr/ to a plain A/AAAA lookup', () async {
      final result = await resolveDnsMultiAddr('/dnsaddr/localhost/tcp/4001');
      expect(result, matches(r'^/ip[46]/.+/tcp/4001$'));
    });

    test('returns non-DNS addresses unchanged', () async {
      const addr = '/ip4/1.2.3.4/tcp/4001';
      expect(await resolveDnsMultiAddr(addr), addr);
    });

    test('preserves trailing protocol segments', () async {
      final result = await resolveDnsMultiAddr('/dns4/localhost/tcp/4001/ws');
      expect(result, matches(r'^/ip4/\d+\.\d+\.\d+\.\d+/tcp/4001/ws$'));
    });

    test('throws ArgumentError when the host cannot be resolved', () async {
      expect(
        () => resolveDnsMultiAddr('/dns4/nonexistent.invalid./tcp/4001'),
        throwsArgumentError,
      );
    });

    test('dns6 throws when the host has no IPv6 address', () async {
      dnsLookupOverride = (host) async => [InternetAddress('127.0.0.1')];
      clearDnsLookupCache();
      addTearDown(() {
        dnsLookupOverride = null;
        clearDnsLookupCache();
      });

      expect(
        () => resolveDnsMultiAddr('/dns6/v4only.test/tcp/4001'),
        throwsArgumentError,
      );
    });

    test('the lookup cache evicts the oldest entry at capacity', () async {
      var lookups = 0;
      dnsLookupOverride = (host) async {
        lookups++;
        return [InternetAddress('10.0.0.1')];
      };
      clearDnsLookupCache();
      final priorMax = dnsLookupCacheMaxEntries;
      dnsLookupCacheMaxEntries = 1;
      addTearDown(() {
        dnsLookupOverride = null;
        dnsLookupCacheMaxEntries = priorMax;
        clearDnsLookupCache();
      });

      await resolveDnsMultiAddr('/dns4/a.test/tcp/1');
      await resolveDnsMultiAddr('/dns4/b.test/tcp/1');
      // With the cap at 1, caching b.test evicted a.test — resolving it
      // again is a third lookup rather than a cache hit.
      await resolveDnsMultiAddr('/dns4/a.test/tcp/1');
      expect(lookups, equals(3));
    });
  });
}
