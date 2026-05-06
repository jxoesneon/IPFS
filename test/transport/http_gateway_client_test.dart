import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('HttpGatewayClient', () {
    test('get returns data when gateway succeeds', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('ipfs.io')) {
          return http.Response('content', 200);
        }
        return http.Response('Not Found', 404);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.get('QmHash');

      expect(result, isNotNull);
      expect(utf8.decode(result!), 'content');
    });

    test('get returns null when all gateways fail', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.get('QmHash');

      expect(result, isNull);
    });

    test('get uses specific baseUrl if provided', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('custom.gateway')) {
          return http.Response('custom content', 200);
        }
        return http.Response('Error', 404);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.get(
        'QmHash',
        baseUrl: 'https://custom.gateway/ipfs/',
      );

      expect(result, isNotNull);
      expect(utf8.decode(result!), 'custom content');
    });

    test('get handles fallback correctly', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // First gateway fails, second (dweb.link) succeeds
        if (request.url.toString().contains('dweb.link')) {
          return http.Response('fallback content', 200);
        }
        return http.Response('Timeout', 504);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.get('QmHash');

      expect(result, isNotNull);
      expect(utf8.decode(result!), 'fallback content');
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('isReachable returns true on success', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.isReachable();

      expect(result, isTrue);
    });

    test('isReachable returns false on failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.isReachable();

      expect(result, isFalse);
    });

    test('close closes internal client', () {
      final client = HttpGatewayClient();
      expect(() => client.close(), returnsNormally);
    });

    test('close does not close external client', () {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });
      final client = HttpGatewayClient(client: mockClient);
      expect(() => client.close(), returnsNormally);
    });

    test('get handles 404 from gateway', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final client = HttpGatewayClient(client: mockClient);
      final result = await client.get('QmHash');

      expect(result, isNull);
    });
  });
}
