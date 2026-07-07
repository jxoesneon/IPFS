import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:dart_ipfs/src/core/cid.dart';

import 'delegated_routing_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  late DelegatedRoutingHandler handler;
  late MockClient mockClient;
  final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

  setUp(() {
    mockClient = MockClient();
    handler = DelegatedRoutingHandler(httpClient: mockClient);
  });

  group('DelegatedRoutingHandler', () {
    test('findProviders success 200 with providers', () async {
      final responseBody = jsonEncode({
        'Providers': [
          {'ID': 'peer1'},
          {'ID': 'peer2'},
        ],
      });

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await handler.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, containsAll(['peer1', 'peer2']));
    });

    test('findProviders 200 with no providers key', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('{}', 200));

      final result = await handler.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders 404 returns success empty', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await handler.findProviders(cid);
      expect(result.isSuccess, isTrue);
      expect(result.providers, isEmpty);
    });

    test('findProviders error status code', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final result = await handler.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('HTTP 500'));
    });

    test('findProviders exception', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenThrow(Exception('Network error'));

      final result = await handler.findProviders(cid);
      expect(result.isSuccess, isFalse);
      expect(result.error, isNot(contains('Network error')));
    });

    test('dispose closes client', () {
      handler.dispose();
      verify(mockClient.close()).called(1);
    });

    test('RoutingResponse helpers', () {
      final success = RoutingResponse.success(['p1']);
      expect(success.isSuccess, isTrue);

      final error = RoutingResponse.error('msg');
      expect(error.isSuccess, isFalse);
      expect(error.error, equals('msg'));
    });
  });
}
