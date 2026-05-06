import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';

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
  });
}
