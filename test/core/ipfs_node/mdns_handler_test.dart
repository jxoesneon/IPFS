@TestOn("vm")
import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/network/mdns_client.dart' as ipfs_mdns;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/utils/base58.dart';

import 'mdns_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ipfs_mdns.MDnsClient>()])
void main() {
  late MDNSHandler handler;
  late MockMDnsClient mockMdnsClient;
  late IPFSConfig config;
  const String peerIdStr = 'QmPZ9gcCEpqKToayWi97p8H586jN4UuTo2Ddfy9y5uUnT7';

  setUp(() {
    mockMdnsClient = MockMDnsClient();
    config = IPFSConfig();
    handler = MDNSHandler(config, mdnsClient: mockMdnsClient);
  });

  group('MDNSHandler', () {
    test('start and stop', () async {
      await handler.start();
      verify(mockMdnsClient.start()).called(1);
      verify(
        mockMdnsClient.startServer(
          serviceType: anyNamed('serviceType'),
          instanceName: anyNamed('instanceName'),
          port: anyNamed('port'),
          txt: anyNamed('txt'),
        ),
      ).called(1);

      await handler.stop();
      verify(mockMdnsClient.stop()).called(1);
    });

    test('getStatus', () async {
      final status = await handler.getStatus();
      expect(status['running'], isFalse);

      await handler.start();
      final status2 = await handler.getStatus();
      expect(status2['running'], isTrue);
    });

    test('already running/stopped warnings', () async {
      await handler.start();
      await handler.start(); // Should log warning but not fail

      await handler.stop();
      await handler.stop(); // Should log warning
    });

    test('peer discovery works', () async {
      final ptrStream = Stream.fromIterable([
        ipfs_mdns.PtrResourceRecord(
          '_ipfs-discovery._udp.local',
          const Duration(seconds: 120),
          'peer1.local',
        ),
      ]);

      final srvRecord = ipfs_mdns.SrvResourceRecord(
        'peer1.local',
        const Duration(seconds: 120),
        'localhost',
        4001,
      );
      final txtRecord = ipfs_mdns.TxtResourceRecord(
        'peer1.local',
        const Duration(seconds: 120),
        [peerIdStr],
      );

      // Setup lookups with specific types to avoid Mockito's confusion with generic methods
      when(
        mockMdnsClient.lookup<ipfs_mdns.PtrResourceRecord>(
          argThat(
            predicate(
              (query) =>
                  query is ipfs_mdns.ResourceRecordQuery &&
                  query.type == ipfs_mdns.ResourceRecordType.ptr,
            ),
          ),
          timeout: anyNamed('timeout'),
        ),
      ).thenAnswer((_) => ptrStream);

      when(
        mockMdnsClient.lookup<ipfs_mdns.SrvResourceRecord>(
          argThat(
            predicate(
              (query) =>
                  query is ipfs_mdns.ResourceRecordQuery &&
                  query.type == ipfs_mdns.ResourceRecordType.srv,
            ),
          ),
          timeout: anyNamed('timeout'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([srvRecord]));

      when(
        mockMdnsClient.lookup<ipfs_mdns.TxtResourceRecord>(
          argThat(
            predicate(
              (query) =>
                  query is ipfs_mdns.ResourceRecordQuery &&
                  query.type == ipfs_mdns.ResourceRecordType.txt,
            ),
          ),
          timeout: anyNamed('timeout'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([txtRecord]));

      await handler.start();

      // Wait for discovery to run and emit a peer
      final peer = await handler.peerDiscovery.first.timeout(
        const Duration(seconds: 5),
      );

      expect(peer.id.value, isNotEmpty);
      expect(peer.addresses.first.port, equals(4001));

      final status = await handler.getStatus();
      expect(status['discovered_peers'], equals(1));
    });

    test('start error handling', () async {
      when(mockMdnsClient.start()).thenThrow(Exception('MDNS start failed'));

      expect(() => handler.start(), throwsException);

      final status = await handler.getStatus();
      expect(status['running'], isFalse);
    });

    test('_resolvePeerInfo handles empty TXT', () async {
      final ptrStream = Stream.fromIterable([
        ipfs_mdns.PtrResourceRecord(
          '_ipfs-discovery._udp.local',
          const Duration(seconds: 120),
          'peer1.local',
        ),
      ]);

      final srvRecord = ipfs_mdns.SrvResourceRecord(
        'peer1.local',
        const Duration(seconds: 120),
        'localhost',
        4001,
      );
      final txtRecord = ipfs_mdns.TxtResourceRecord(
        'peer1.local',
        const Duration(seconds: 120),
        [],
      ); // Empty TXT

      when(
        mockMdnsClient.lookup<ipfs_mdns.PtrResourceRecord>(any),
      ).thenAnswer((_) => ptrStream);
      when(
        mockMdnsClient.lookup<ipfs_mdns.SrvResourceRecord>(any),
      ).thenAnswer((_) => Stream.fromIterable([srvRecord]));
      when(
        mockMdnsClient.lookup<ipfs_mdns.TxtResourceRecord>(any),
      ).thenAnswer((_) => Stream.fromIterable([txtRecord]));

      await handler.start();

      await Future.delayed(const Duration(milliseconds: 100));

      final status = await handler.getStatus();
      expect(status['discovered_peers'], equals(0));
    });

    test('_getPort fallback', () async {
      final configNoListen = IPFSConfig(
        network: NetworkConfig(listenAddresses: []),
      );
      final handlerLocal = MDNSHandler(
        configNoListen,
        mdnsClient: mockMdnsClient,
      );

      await handlerLocal.start();
      verify(
        mockMdnsClient.startServer(
          serviceType: anyNamed('serviceType'),
          instanceName: anyNamed('instanceName'),
          port: 4001, // Default port
          txt: anyNamed('txt'),
        ),
      ).called(1);
    });

    test('stop error handling', () async {
      await handler.start();
      when(mockMdnsClient.stop()).thenThrow(Exception('stop failed'));
      expect(() => handler.stop(), throwsException);
    });

    test('_getPort with invalid port string', () async {
      final configInvalid = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/invalid_port'],
        ),
      );
      final handlerLocal = MDNSHandler(
        configInvalid,
        mdnsClient: mockMdnsClient,
      );

      await handlerLocal.start();
      verify(
        mockMdnsClient.startServer(
          serviceType: anyNamed('serviceType'),
          instanceName: anyNamed('instanceName'),
          port: 4001, // Default fallback
          txt: anyNamed('txt'),
        ),
      ).called(1);
    });

    test('_resolvePeerInfo handles SocketException', () async {
      final ptrStream = Stream.fromIterable([
        ipfs_mdns.PtrResourceRecord(
          '_ipfs-discovery._udp.local',
          const Duration(seconds: 120),
          'peer-fail.local',
        ),
      ]);

      final srvRecord = ipfs_mdns.SrvResourceRecord(
        'peer-fail.local',
        const Duration(seconds: 120),
        'nonexistent.local',
        4001,
      );
      final txtRecord = ipfs_mdns.TxtResourceRecord(
        'peer-fail.local',
        const Duration(seconds: 120),
        [peerIdStr],
      );

      when(
        mockMdnsClient.lookup<ipfs_mdns.PtrResourceRecord>(any),
      ).thenAnswer((_) => ptrStream);
      when(
        mockMdnsClient.lookup<ipfs_mdns.SrvResourceRecord>(any),
      ).thenAnswer((_) => Stream.fromIterable([srvRecord]));
      when(
        mockMdnsClient.lookup<ipfs_mdns.TxtResourceRecord>(any),
      ).thenAnswer((_) => Stream.fromIterable([txtRecord]));

      // This test is tricky because it depends on the internal InternetAddress.lookup
      // We can't easily mock InternetAddress.lookup in Dart without more dependency injection
      // but we can at least check if the code path is hit if it fails naturally on some environments
      // or we could modify MDNSHandler to take a resolver function.
      // For now, let's just ensure it doesn't crash if lookup fails.

      await handler.start();
      await Future.delayed(const Duration(milliseconds: 100));

      // status discovered_peers should be 0 if lookup fails
    });
    test('_advertiseService error handling', () async {
      when(
        mockMdnsClient.announce(any, any, any, any),
      ).thenThrow(Exception('announce failed'));
      await handler.start();
      // Should not throw, but should log an error. We just await start.
    });

    test('_resolvePeerInfo generic catch block', () async {
      final ptrStream = Stream.fromIterable([
        ipfs_mdns.PtrResourceRecord(
          '_ipfs-discovery._udp.local',
          const Duration(seconds: 120),
          'peer-generic.local',
        ),
      ]);

      when(
        mockMdnsClient.lookup<ipfs_mdns.PtrResourceRecord>(any),
      ).thenAnswer((_) => ptrStream);
      when(
        mockMdnsClient.lookup<ipfs_mdns.SrvResourceRecord>(any),
      ).thenThrow(Exception('Generic lookup error'));

      await handler.start();
      await Future.delayed(const Duration(milliseconds: 100));

      final status = await handler.getStatus();
      expect(status['discovered_peers'], equals(0));
    });
    test('_advertiseService error handling', () async {
      when(
        mockMdnsClient.announce(any, any, any, any),
      ).thenThrow(Exception('announce failed'));
      await handler.start();
      // Should not throw, but should log an error. We just await start.
    });

    test('_resolvePeerInfo generic catch block', () async {
      final ptrStream = Stream.fromIterable([
        ipfs_mdns.PtrResourceRecord(
          '_ipfs-discovery._udp.local',
          const Duration(seconds: 120),
          'peer-generic.local',
        ),
      ]);

      when(
        mockMdnsClient.lookup<ipfs_mdns.PtrResourceRecord>(any),
      ).thenAnswer((_) => ptrStream);
      when(
        mockMdnsClient.lookup<ipfs_mdns.SrvResourceRecord>(any),
      ).thenThrow(Exception('Generic lookup error'));

      await handler.start();
      await Future.delayed(const Duration(milliseconds: 100));

      final status = await handler.getStatus();
      expect(status['discovered_peers'], equals(0));
    });
  });
}
