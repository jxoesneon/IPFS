import 'dart:convert';

import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'dnslink_resolver_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  group('DNSLinkResolver', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('resolve success', () async {
      final responseBody = json.encode({'cid': 'QmTest'});
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await DNSLinkResolver.resolve(
        'example.com',
        client: mockClient,
      );
      expect(result, equals('QmTest'));
    });

    test('resolve failure status code', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await DNSLinkResolver.resolve(
        'example.com',
        client: mockClient,
      );
      expect(result, isNull);
    });

    test('resolve exception', () async {
      when(mockClient.get(any)).thenThrow(Exception('Network error'));

      final result = await DNSLinkResolver.resolve(
        'example.com',
        client: mockClient,
      );
      expect(result, isNull);
    });

    test('resolve uses the configured endpoint', () async {
      Uri? captured;
      when(mockClient.get(any)).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as Uri;
        return http.Response(json.encode({'cid': 'QmCustom'}), 200);
      });

      final result = await DNSLinkResolver.resolve(
        'example.com',
        client: mockClient,
        endpoint: 'https://resolver.internal/dnslink',
      );

      expect(result, equals('QmCustom'));
      expect(
        captured.toString(),
        equals('https://resolver.internal/dnslink/example.com'),
      );
    });

    test('an injected client is not closed by resolve', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await DNSLinkResolver.resolve('example.com', client: mockClient);

      verifyNever(mockClient.close());
    });

    test('an internally created client is closed after the lookup', () async {
      // No client is injected, so resolve creates an http.Client and must
      // close it in the finally block even when the request fails. An
      // unroutable endpoint fails fast without relying on external network
      // access.
      final result = await DNSLinkResolver.resolve(
        'example.com',
        endpoint: 'http://127.0.0.1:1',
      );
      expect(result, isNull);
    });
  });
}
