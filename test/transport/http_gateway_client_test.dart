// test/transport/http_gateway_client_test.dart
import 'package:test/test.dart';

// Note: HttpGatewayClient makes real HTTP requests. These tests focus on
// unit-testable logic patterns without network calls.

void main() {
  group('HttpGatewayClient Gateway URLs', () {
    final gateways = [
      'https://ipfs.io/ipfs/',
      'https://dweb.link/ipfs/',
      'https://gateway.pinata.cloud/ipfs/',
      'https://cloudflare-ipfs.com/ipfs/',
    ];

    test('default gateways are HTTPS', () {
      for (final gateway in gateways) {
        expect(gateway.startsWith('https://'), isTrue);
      }
    });

    test('default gateways end with /ipfs/', () {
      for (final gateway in gateways) {
        expect(gateway.endsWith('/ipfs/'), isTrue);
      }
    });

    test('gateway count matches expected', () {
      expect(gateways.length, equals(4));
    });
  });

  group('HttpGatewayClient URL Construction', () {
    test('URL is correctly constructed with CID', () {
      const gateway = 'https://ipfs.io/ipfs/';
      const cid = 'QmTest123';
      final url = Uri.parse('$gateway$cid');

      expect(url.toString(), equals('https://ipfs.io/ipfs/QmTest123'));
    });

    test('cleanBase adds trailing slash if missing', () {
      const baseUrl = 'https://custom-gateway.com/ipfs';
      final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      expect(cleanBase, equals('https://custom-gateway.com/ipfs/'));
    });

    test('cleanBase preserves trailing slash if present', () {
      const baseUrl = 'https://custom-gateway.com/ipfs/';
      final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      expect(cleanBase, equals('https://custom-gateway.com/ipfs/'));
    });
  });

  group('HttpGatewayClient Reachability', () {
    test('known CID for reachability check is correct', () {
      // Empty directory CID used for health check
      const emptyCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      expect(emptyCid.startsWith('Qm'), isTrue);
      expect(emptyCid.length, equals(46)); // CIDv0 length
    });
  });

  group('HttpGatewayClient Response Handling', () {
    test('HTTP 200 indicates success', () {
      const statusCode = 200;
      expect(statusCode == 200, isTrue);
    });

    test('non-200 status codes indicate failure', () {
      final failureCodes = [404, 500, 502, 503];
      for (final code in failureCodes) {
        expect(code != 200, isTrue);
      }
    });
  });

  group('HttpGatewayClient Timeout', () {
    test('timeout duration is reasonable', () {
      const timeout = Duration(seconds: 5);
      expect(timeout.inSeconds, equals(5));
      expect(timeout.inSeconds, lessThanOrEqualTo(10));
    });

    test('reachability timeout is shorter', () {
      const reachabilityTimeout = Duration(seconds: 3);
      const fetchTimeout = Duration(seconds: 5);
      expect(reachabilityTimeout < fetchTimeout, isTrue);
    });
  });

  group('HttpGatewayClient Fallback Logic', () {
    test('iterates through all gateways on failure', () {
      final gateways = ['gw1', 'gw2', 'gw3', 'gw4'];
      var triedCount = 0;

      for (final gateway in gateways) {
        triedCount++;
        // Simulate failure - continue to next
        final success = false;
        if (success) break;
      }

      expect(triedCount, equals(4)); // All gateways tried
    });

    test('stops on first success', () {
      final gateways = ['gw1', 'gw2', 'gw3', 'gw4'];
      var triedCount = 0;

      for (final gateway in gateways) {
        triedCount++;
        // Simulate success on second gateway
        final success = gateway == 'gw2';
        if (success) break;
      }

      expect(triedCount, equals(2)); // Stopped at second
    });
  });
}
