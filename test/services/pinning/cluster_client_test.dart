// test/services/pinning/cluster_client_test.dart
import 'dart:convert';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;

import 'package:dart_ipfs/src/services/pinning/cluster_client.dart';

import 'cluster_client_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  late IPFSClusterClient client;
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
    client = IPFSClusterClient(
      endpoint: 'https://cluster.example.com:9094',
      token: 'test-token',
      httpClient: mockClient,
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('IPFSClusterClient', () {
    test('pin sends POST and parses response', () async {
      final responseBody = jsonEncode({
        'cid': 'QmExample123',
        'status': 'pinned',
        'name': 'test-pin',
        'allocations': ['peer1', 'peer2'],
        'replication_factor_min': 2,
        'replication_factor_max': 2,
        'peer_map': {
          'peer1': {
            'peer_name': 'node-1',
            'status': 'pinned',
            'error': '',
            'ts': '2025-01-01T00:00:00Z',
          },
          'peer2': {
            'peer_name': 'node-2',
            'status': 'pinned',
            'error': '',
            'ts': '2025-01-01T00:00:00Z',
          },
        },
        'meta': {},
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.pin(
        'QmExample123',
        options: const ClusterPinOptions(
          name: 'test-pin',
          replicationFactor: ReplicationFactor(2),
        ),
      );

      expect(result.cid, equals('QmExample123'));
      expect(result.status, equals(ClusterPinStatus.pinned));
      expect(result.name, equals('test-pin'));
      expect(result.allocations, containsAll(['peer1', 'peer2']));
      expect(result.replicationFactorMin, equals(2));
      expect(result.peerMap, hasLength(2));
      expect(result.peerMap['peer1']?.peerName, equals('node-1'));
      expect(result.peerMap['peer1']?.status, equals(ClusterPinStatus.pinned));
    });

    test('unpin sends DELETE', () async {
      when(
        mockClient.delete(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('', 200));

      await client.unpin('QmTestCid');

      verify(mockClient.delete(any, headers: anyNamed('headers'))).called(1);
    });

    test('unpin throws on error', () async {
      when(
        mockClient.delete(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Not found', 404));

      expect(() => client.unpin('QmNonexistent'), throwsException);
    });

    test('status gets pin info', () async {
      final responseBody = jsonEncode({
        'cid': 'QmStatusTest',
        'status': 'pinning',
        'peer_map': {
          'peer1': {
            'peer_name': 'node-1',
            'status': 'pinning',
            'ts': '2025-01-01T00:00:00Z',
          },
        },
      });

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.status('QmStatusTest');

      expect(result.cid, equals('QmStatusTest'));
      expect(result.status, equals(ClusterPinStatus.pinning));
      expect(result.peerMap['peer1']?.status, equals(ClusterPinStatus.pinning));
    });

    test('listPins returns list of pins', () async {
      final responseBody = jsonEncode([
        {'cid': 'QmPin1', 'status': 'pinned', 'peer_map': {}},
        {'cid': 'QmPin2', 'status': 'queued', 'peer_map': {}},
      ]);

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final results = await client.listPins();

      expect(results, hasLength(2));
      expect(results[0].cid, equals('QmPin1'));
      expect(results[0].status, equals(ClusterPinStatus.pinned));
      expect(results[1].cid, equals('QmPin2'));
      expect(results[1].status, equals(ClusterPinStatus.queued));
    });

    test('listPins handles map response with pins key', () async {
      final responseBody = jsonEncode({
        'pins': [
          {'cid': 'QmPin1', 'status': 'pinned', 'peer_map': {}},
        ],
      });

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final results = await client.listPins();

      expect(results, hasLength(1));
      expect(results[0].cid, equals('QmPin1'));
    });

    test('recover sends POST and returns pin status', () async {
      final responseBody = jsonEncode({
        'cid': 'QmRecoverTest',
        'status': 'pinned',
        'peer_map': {},
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.recover('QmRecoverTest');

      expect(result.cid, equals('QmRecoverTest'));
      expect(result.status, equals(ClusterPinStatus.pinned));
    });

    test('listPeers returns cluster peers', () async {
      final responseBody = jsonEncode([
        {
          'id': '12D3KooWPeer1',
          'addresses': ['/ip4/1.2.3.4/tcp/9096'],
          'peer_name': 'node-1',
          'rpc': '/ip4/1.2.3.4/tcp/9096',
          'version': '1.0.0',
          'commit': 'abc123',
          'rpc_protocol_version': '0.1.0',
        },
      ]);

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final peers = await client.listPeers();

      expect(peers, hasLength(1));
      expect(peers[0].id, equals('12D3KooWPeer1'));
      expect(peers[0].peerName, equals('node-1'));
      expect(peers[0].version, equals('1.0.0'));
    });

    test('health returns cluster health', () async {
      final responseBody = jsonEncode({'healthy': true, 'peers': []});

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final health = await client.health();

      expect(health.healthy, isTrue);
    });

    test('version returns cluster version', () async {
      final responseBody = jsonEncode({'version': '1.1.0', 'commit': 'def456'});

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final version = await client.version();

      expect(version, equals('1.1.0'));
    });

    test('sync sends POST and returns pin status', () async {
      final responseBody = jsonEncode({
        'cid': 'QmSyncTest',
        'status': 'pinned',
        'peer_map': {},
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await client.sync('QmSyncTest');

      expect(result.cid, equals('QmSyncTest'));
      expect(result.status, equals(ClusterPinStatus.pinned));
    });

    test('statusAll returns all pin statuses', () async {
      final responseBody = jsonEncode([
        {'cid': 'QmPin1', 'status': 'pinned', 'peer_map': {}},
        {'cid': 'QmPin2', 'status': 'failed', 'peer_map': {}},
      ]);

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final results = await client.statusAll();

      expect(results, hasLength(2));
      expect(results[1].status, equals(ClusterPinStatus.failed));
    });

    test('ClusterPinStatus fromString roundtrip', () {
      for (final status in ClusterPinStatus.values) {
        if (status == ClusterPinStatus.unknown) continue;
        final parsed = ClusterPinStatus.fromString(status.toApiString());
        expect(parsed, equals(status));
      }
      expect(
        ClusterPinStatus.fromString(null),
        equals(ClusterPinStatus.unknown),
      );
      expect(
        ClusterPinStatus.fromString('invalid'),
        equals(ClusterPinStatus.unknown),
      );
    });

    test('ReplicationFactor values', () {
      expect(ReplicationFactor.all.value, equals(-1));
      expect(ReplicationFactor.defaultFactor.value, equals(0));
      expect(ReplicationFactor.min(3).value, equals(3));
    });

    test('ClusterPinOptions toJson', () {
      const options = ClusterPinOptions(
        name: 'test',
        replicationFactor: ReplicationFactor(3),
        allocations: ['peer1', 'peer2'],
      );
      final json = options.toJson();
      expect(json['name'], equals('test'));
      expect(json['replication_factor_min'], equals(3));
      expect(json['replication_factor_max'], equals(3));
      expect(json['allocations'], containsAll(['peer1', 'peer2']));
    });

    test('ClusterPin toJson', () {
      final pin = ClusterPin(
        cid: 'QmTest',
        status: ClusterPinStatus.pinned,
        name: 'test',
        allocations: ['peer1'],
        replicationFactorMin: 1,
        replicationFactorMax: 1,
      );
      final json = pin.toJson();
      expect(json['cid'], equals('QmTest'));
      expect(json['status'], equals('pinned'));
      expect(json['name'], equals('test'));
      expect(json['allocations'], contains('peer1'));
    });

    test('ClusterPeerInfo fromJson', () {
      final info = ClusterPeerInfo.fromJson({
        'peer_name': 'node-1',
        'status': 'pinned',
        'error': '',
        'ts': '2025-01-01T00:00:00Z',
      });
      expect(info.peerName, equals('node-1'));
      expect(info.status, equals(ClusterPinStatus.pinned));
      expect(info.error, isEmpty);
    });

    test('ClusterPeer fromJson', () {
      final peer = ClusterPeer.fromJson({
        'id': '12D3KooWTest',
        'addresses': ['/ip4/1.2.3.4/tcp/9096'],
        'peer_name': 'node-1',
        'rpc': '/ip4/1.2.3.4/tcp/9096',
        'version': '1.0.0',
        'commit': 'abc',
        'rpc_protocol_version': '0.1.0',
      });
      expect(peer.id, equals('12D3KooWTest'));
      expect(peer.addresses, hasLength(1));
      expect(peer.peerName, equals('node-1'));
    });

    test('ClusterHealth fromJson', () {
      final health = ClusterHealth.fromJson({
        'healthy': false,
        'error': 'peer disconnected',
      });
      expect(health.healthy, isFalse);
      expect(health.error, equals('peer disconnected'));
    });

    test('dispose closes client', () {
      client.dispose();
      verify(mockClient.close()).called(1);
    });

    test('basic auth credentials', () async {
      final c = IPFSClusterClient(
        endpoint: 'https://cluster.example.com',
        username: 'admin',
        password: 'secret',
        httpClient: mockClient,
      );
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('{"version":"1.0"}', 200));

      await c.version();
      c.dispose();
      // Just verify it doesn't throw
    });
  });
}
