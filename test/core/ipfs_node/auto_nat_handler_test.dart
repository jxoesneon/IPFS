import 'dart:async';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'auto_nat_handler_test.mocks.dart';

@GenerateMocks([NetworkHandler, NatTraversalService])
void main() {
  group('AutoNATHandler', () {
    late AutoNATHandler handler;
    late IPFSConfig config;
    late MockNetworkHandler mockNetworkHandler;
    late MockNatTraversalService mockNatService;

    setUp(() {
      config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
          enableNatTraversal: true,
          bootstrapPeers: ['/ip4/1.2.3.4/tcp/4001'],
        ),
      );
      mockNetworkHandler = MockNetworkHandler();
      mockNatService = MockNatTraversalService();

      // Default behaviors
      when(mockNetworkHandler.canConnectDirectly(any)).thenAnswer((_) async => false);
      when(
        mockNetworkHandler.testConnection(sourcePort: anyNamed('sourcePort')),
      ).thenAnswer((_) async => '4001');
      when(mockNetworkHandler.testDialback()).thenAnswer((_) async => true);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => ['TCP', 'UDP']);
      when(mockNatService.unmapPort(any)).thenAnswer((_) async => {});

      handler = AutoNATHandler(config, mockNetworkHandler, natService: mockNatService);
    });

    tearDown(() async {
      await handler.stop().catchError((_) {});
    });

    test('start detects NAT and attempts port mapping', () async {
      await handler.start();
      verify(mockNatService.mapPort(4001)).called(1);
      final status = await handler.getStatus();
      expect(status['nat_type'], contains('restricted'));
      expect(status['running'], isTrue);
    });

    test('double start log warning and no-op', () async {
      await handler.start();
      await handler.start();
    });

    test('stop unmaps ports and is idempotent', () async {
      await handler.start();
      await handler.stop();
      verify(mockNatService.unmapPort(4001)).called(1);
      expect(await handler.getStatus().then((s) => s['running']), isFalse);

      await handler.stop(); // double stop
    });

    test('detects direct connectivity (NATType.none)', () async {
      when(mockNetworkHandler.canConnectDirectly(any)).thenAnswer((_) async => true);
      await handler.start();
      final status = await handler.getStatus();
      expect(status['nat_type'], contains('none'));
      expect(status['reachable'], isTrue);
    });

    test('detects symmetric NAT', () async {
      when(mockNetworkHandler.testConnection(sourcePort: 4001)).thenAnswer((_) async => '4001');
      when(mockNetworkHandler.testConnection(sourcePort: 4002)).thenAnswer((_) async => '4005');
      await handler.start();
      final status = await handler.getStatus();
      expect(status['nat_type'], contains('symmetric'));
    });

    test('handles NAT detection error gracefully', () async {
      when(mockNetworkHandler.canConnectDirectly(any)).thenThrow(Exception('Connect error'));
      await handler.start();
      final status = await handler.getStatus();
      expect(status['nat_type'], contains('unknown'));
    });

    test('skips port mapping when disabled in config', () async {
      final disabledConfig = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/0.0.0.0/tcp/4005'],
          enableNatTraversal: false,
        ),
      );
      handler = AutoNATHandler(disabledConfig, mockNetworkHandler, natService: mockNatService);
      await handler.start();
      verifyNever(mockNatService.mapPort(any));
    });

    test('handles port mapping failure', () async {
      when(mockNatService.mapPort(any)).thenAnswer((_) async => []);
      await handler.start();
      final status = await handler.getStatus();
      // Should still be running but mappedPort logic might vary
      expect(status['running'], isTrue);
    });

    test('extracts port correctly from various address formats', () async {
      final customConfig = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/udp/9090'],
          enableNatTraversal: true,
        ),
      );
      handler = AutoNATHandler(customConfig, mockNetworkHandler, natService: mockNatService);
      await handler.start();
      verify(mockNatService.mapPort(9090)).called(1);
    });

    test('handles address formats without specific port markers', () async {
      final badConfig = IPFSConfig(
        network: NetworkConfig(listenAddresses: ['/unix/tmp/ipfs.sock'], enableNatTraversal: true),
      );
      handler = AutoNATHandler(badConfig, mockNetworkHandler, natService: mockNatService);
      await handler.start();
      verifyNever(mockNatService.mapPort(any));
    });

    test('stop handles mappedPort null fallback', () async {
      final badConfig = IPFSConfig(
        network: NetworkConfig(listenAddresses: ['/bad'], enableNatTraversal: true),
      );
      handler = AutoNATHandler(badConfig, mockNetworkHandler, natService: mockNatService);

      await handler.start();
      await handler.stop();
      verify(mockNatService.unmapPort(4001)).called(1);
    });

    test('handles errors during stop', () async {
      await handler.start();
      when(mockNatService.unmapPort(any)).thenThrow(Exception('NAT service unmap error'));
      // Expect stop to rethrow or log error depending on implementation
      // Current implementation rethrows
      expect(handler.stop(), throwsA(isA<Exception>()));
    });

    test('handles dialback test error', () async {
      when(mockNetworkHandler.testDialback()).thenThrow(Exception('Dialback error'));
      await handler.start();
      // Small delay to allow fire-and-forget dialback to fail
      await Future.delayed(const Duration(milliseconds: 50));
      final status = await handler.getStatus();
      expect(status['reachable'], isFalse);
    });
  });
}
