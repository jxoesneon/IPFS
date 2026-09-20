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
      final result = await resolveDnsMultiAddr(
        '/dns4/localhost/tcp/4001/ws',
      );
      expect(result, matches(r'^/ip4/\d+\.\d+\.\d+\.\d+/tcp/4001/ws$'));
    });

    test('throws ArgumentError when the host cannot be resolved', () async {
      expect(
        () => resolveDnsMultiAddr(
          '/dns4/nonexistent.invalid./tcp/4001',
        ),
        throwsArgumentError,
      );
    });
  });
}
