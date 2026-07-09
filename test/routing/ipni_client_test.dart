// test/routing/ipni_client_test.dart
import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/routing/ipni_client.dart';
import 'package:dart_ipfs/dart_ipfs.dart' hide CID;
import 'package:dart_ipfs/src/core/cid.dart';

import 'ipni_client_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  late IPNIClient client;
  late MockClient mockClient;
  final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

  setUp(() {
    mockClient = MockClient();
    client = IPNIClient(
      endpoints: ['https://cid.contact'],
      httpClient: mockClient,
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('IPNIClient', () {
    test('findProviders success with providers', () async {
      final responseBody = jsonEncode({
        'Providers': [
          {
            'ID': '12D3KooWExample1',
            'Addrs': ['/ip4/1.2.3.4/tcp/4001'],
            'Metadata': [
              {'Protocol': 'transport-bitswap'},
            ],
          },
          {
            'ID': '12D3KooWExample2',
            'Addrs': ['/ip4/5.6.7.8/tcp/4001'],
          },
        ],
      });

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(2));
      expect(result.providers[0].peerId, equals('12D3KooWExample1'));
      expect(result.providers[0].multiaddrs, contains('/ip4/1.2.3.4/tcp/4001'));
      expect(result.providers[0].metadata, hasLength(1));
      expect(
        result.providers[0].metadata[0].protocol,
        equals('transport-bitswap'),
      );
      expect(result.providers[1].peerId, equals('12D3KooWExample2'));
    });

    test('findProviders 404 returns empty success', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders error status code', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Server Error', 500));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('HTTP 500'));
    });

    test('findProviders invalid JSON response', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('not json', 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Invalid JSON'));
    });

    test('findProviders with no Providers key returns empty', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('{}', 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders exception returns error', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenThrow(Exception('Network error'));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
    });

    test('findProviders merges and deduplicates by peer ID', () async {
      final client2 = IPNIClient(
        endpoints: ['https://ep1.example.com', 'https://ep2.example.com'],
        httpClient: mockClient,
      );

      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer((
        invocation,
      ) async {
        final url = invocation.positionalArguments[0] as Uri;
        if (url.toString().contains('ep1')) {
          return http.Response(
            jsonEncode({
              'Providers': [
                {
                  'ID': 'samePeer',
                  'Addrs': ['/ip4/1.1.1.1/tcp/4001'],
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'Providers': [
              {
                'ID': 'samePeer',
                'Addrs': ['/ip4/2.2.2.2/tcp/4001'],
              },
            ],
          }),
          200,
        );
      });

      final result = await client2.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(1));
      expect(result.providers[0].multiaddrs, hasLength(2));
      expect(result.providers[0].multiaddrs, contains('/ip4/1.1.1.1/tcp/4001'));
      expect(result.providers[0].multiaddrs, contains('/ip4/2.2.2.2/tcp/4001'));
      client2.dispose();
    });

    test('addEndpoint and removeEndpoint', () {
      final c = IPNIClient(
        endpoints: ['https://a.example.com'],
        httpClient: mockClient,
      );
      expect(c.endpoints, hasLength(1));
      c.addEndpoint('https://b.example.com');
      expect(c.endpoints, hasLength(2));
      c.addEndpoint('https://b.example.com');
      expect(c.endpoints, hasLength(2));
      c.removeEndpoint('https://a.example.com');
      expect(c.endpoints, hasLength(1));
      c.dispose();
    });

    test('provider with empty ID is skipped', () async {
      final responseBody = jsonEncode({
        'Providers': [
          {
            'ID': '',
            'Addrs': ['/ip4/1.2.3.4/tcp/4001'],
          },
          {'ID': 'validPeer', 'Addrs': []},
        ],
      });

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(1));
      expect(result.providers[0].peerId, equals('validPeer'));
    });

    test('IPNIProvider toJson', () {
      final provider = IPNIProvider(
        peerId: 'peer1',
        multiaddrs: ['/ip4/1.2.3.4/tcp/4001'],
        metadata: [IPNIProviderMetadata(protocol: 'transport-bitswap')],
      );
      final json = provider.toJson();
      expect(json['ID'], equals('peer1'));
      expect(json['Addrs'], contains('/ip4/1.2.3.4/tcp/4001'));
      expect(json['Metadata'], hasLength(1));
    });

    test('IPNIProviderMetadata toJson', () {
      final md = IPNIProviderMetadata(
        protocol: 'transport-bitswap',
        manifest: 'abc123',
      );
      final json = md.toJson();
      expect(json['Protocol'], equals('transport-bitswap'));
      expect(json['Manifest'], equals('abc123'));
    });

    test('IPNIResponse helpers', () {
      final success = IPNIResponse.success([]);
      expect(success.isSuccess, isTrue);

      final error = IPNIResponse.error('test error');
      expect(error.isSuccess, isFalse);
      expect(error.error, equals('test error'));
    });

    test('dispose closes client', () {
      client.dispose();
      verify(mockClient.close()).called(1);
    });

    test('default endpoint is cid.contact', () {
      final c = IPNIClient(httpClient: mockClient);
      expect(c.endpoints, contains('https://cid.contact'));
      c.dispose();
    });
  });
}
