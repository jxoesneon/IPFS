// test/routing/reframe_routing_test.dart
import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/routing/reframe_routing.dart';
import 'package:dart_ipfs/dart_ipfs.dart' hide CID;
import 'package:dart_ipfs/src/core/cid.dart';

import 'reframe_routing_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  late ReframeRoutingClient client;
  late MockClient mockClient;
  final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

  setUp(() {
    mockClient = MockClient();
    client = ReframeRoutingClient(
      endpoints: ['https://reframe.example.com'],
      httpClient: mockClient,
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('ReframeRoutingClient', () {
    test('findProviders success with providers', () async {
      final responseBody = jsonEncode({
        'FindProviders': {
          'Providers': [
            {
              'ID': '12D3KooWExample1',
              'Addrs': ['/ip4/1.2.3.4/tcp/4001'],
              'Protocols': ['transport-bitswap'],
            },
            {
              'ID': '12D3KooWExample2',
              'Addrs': ['/ip4/5.6.7.8/tcp/4001'],
            },
          ],
        },
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(2));
      expect(result.providers[0].peerId, equals('12D3KooWExample1'));
      expect(result.providers[0].multiaddrs, contains('/ip4/1.2.3.4/tcp/4001'));
      expect(result.providers[0].protocols, contains('transport-bitswap'));
      expect(result.providers[1].peerId, equals('12D3KooWExample2'));
    });

    test('findProviders with top-level Providers key', () async {
      final responseBody = jsonEncode({
        'Providers': [
          {
            'ID': 'peerA',
            'Addrs': ['/ip4/10.0.0.1/tcp/4001'],
          },
        ],
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(1));
      expect(result.providers[0].peerId, equals('peerA'));
    });

    test('findProviders 404 returns empty success', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders error status code', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Server Error', 500));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('HTTP 500'));
    });

    test('findProviders invalid JSON response', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('not json', 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Invalid JSON'));
    });

    test('findProviders with no Providers key returns empty', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders exception returns error', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(Exception('Network error'));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isFalse);
    });

    test('findProviders merges results from multiple endpoints', () async {
      final client2 = ReframeRoutingClient(
        endpoints: ['https://ep1.example.com', 'https://ep2.example.com'],
        httpClient: mockClient,
      );

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments[0] as Uri;
        if (url.toString().contains('ep1')) {
          return http.Response(
            jsonEncode({
              'Providers': [
                {
                  'ID': 'peer1',
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
                'ID': 'peer2',
                'Addrs': ['/ip4/2.2.2.2/tcp/4001'],
              },
            ],
          }),
          200,
        );
      });

      final result = await client2.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(2));
      client2.dispose();
    });

    test('addEndpoint and removeEndpoint', () {
      final c = ReframeRoutingClient(
        endpoints: ['https://a.example.com'],
        httpClient: mockClient,
      );
      expect(c.endpoints, hasLength(1));
      c.addEndpoint('https://b.example.com');
      expect(c.endpoints, hasLength(2));
      // Adding duplicate should not add again
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
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, hasLength(1));
      expect(result.providers[0].peerId, equals('validPeer'));
    });

    test('ReframeProvider toJson', () {
      final provider = ReframeProvider(
        peerId: 'peer1',
        multiaddrs: ['/ip4/1.2.3.4/tcp/4001'],
        protocols: ['transport-bitswap'],
      );
      final json = provider.toJson();
      expect(json['ID'], equals('peer1'));
      expect(json['Addrs'], contains('/ip4/1.2.3.4/tcp/4001'));
      expect(json['Protocols'], contains('transport-bitswap'));
    });

    test('ReframeResponse helpers', () {
      final success = ReframeResponse.success([]);
      expect(success.isSuccess, isTrue);

      final error = ReframeResponse.error('test error');
      expect(error.isSuccess, isFalse);
      expect(error.error, equals('test error'));
    });

    test('dispose closes client', () {
      client.dispose();
      verify(mockClient.close()).called(1);
    });
  });
}
