
import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:multicast_dns/multicast_dns.dart' as mdns;
import 'package:dart_ipfs/src/network/mdns_client.dart';

import 'mdns_client_test.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<mdns.MDnsClient>(as: #MockMDnsClient),
  MockSpec<RawDatagramSocket>(as: #MockRawDatagramSocket),
])
void main() {
  group('MDnsClient', () {
    late MDnsClient client;
    late MockMDnsClient mockInnerClient;

    setUp(() {
      mockInnerClient = MockMDnsClient();
      client = MDnsClient(client: mockInnerClient);
    });

    test('start and stop', () async {
      await client.start();
      expect(client.isRunning, isTrue);
      verify(mockInnerClient.start()).called(1);

      await client.stop();
      expect(client.isRunning, isFalse);
      verify(mockInnerClient.stop()).called(1);
    });

    test('start already running', () async {
      await client.start();
      await client.start(); // Should log warning and return
      verify(mockInnerClient.start()).called(1);
    });

    test('stop when not running', () async {
      await client.stop();
      verifyNever(mockInnerClient.stop());
    });

    test('lookup transforms PTR record', () async {
      await client.start();
      final query = ResourceRecordQuery.serverPointer('_ipfs-discovery._udp');
      final rawRecord = mdns.PtrResourceRecord(
        '_ipfs-discovery._udp.local',
        120000,
        domainName: 'instance.local',
      );

      when(mockInnerClient.lookup(any)).thenAnswer((_) => Stream.fromIterable([rawRecord]));

      final result = await client.lookup<PtrResourceRecord>(query).first;
      expect(result.name, '_ipfs-discovery._udp.local');
      expect(result.domainName, 'instance.local');
    });

    test('lookup transforms SRV record', () async {
      await client.start();
      final query = ResourceRecordQuery.service('instance.local');
      final rawRecord = mdns.SrvResourceRecord(
        'instance.local',
        120000,
        target: 'hostname.local',
        port: 4001,
        priority: 10,
        weight: 20,
      );

      when(mockInnerClient.lookup(any)).thenAnswer((_) => Stream.fromIterable([rawRecord]));

      final result = await client.lookup<SrvResourceRecord>(query).first;
      expect(result.target, 'hostname.local');
      expect(result.port, 4001);
      expect(result.priority, 10);
      expect(result.weight, 20);
    });

    test('lookup transforms TXT record', () async {
      await client.start();
      final query = ResourceRecordQuery.text('instance.local');
      final rawRecord = mdns.TxtResourceRecord(
        'instance.local',
        120000,
        text: 'peerid=123',
      );

      when(mockInnerClient.lookup(any)).thenAnswer((_) => Stream.fromIterable([rawRecord]));

      final result = await client.lookup<TxtResourceRecord>(query).first;
      expect(result.text, ['peerid=123']);
    });

    test('lookup timeout and error handling', () async {
      await client.start();
      final query = ResourceRecordQuery.text('instance.local');
      
      when(mockInnerClient.lookup(any)).thenAnswer((_) => Stream.error(TimeoutException('test')));
      
      // lookup catch TimeoutException and doesn't rethrow, but lookup Stream will terminate
      final results = await client.lookup(query).toList();
      expect(results, isEmpty);

      when(mockInnerClient.lookup(any)).thenAnswer((_) => Stream.error(Exception('other')));
      expect(() => client.lookup(query).toList(), throwsException);
    });
  });
}
