import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';

import 'auto_nat_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NetworkHandler>(),
  MockSpec<NatTraversalService>(),
])
void main() {
  late AutoNATHandler handler;
  late MockNetworkHandler mockNetworkHandler;
  late MockNatTraversalService mockNatService;
  late IPFSConfig config;

  setUp(() {
    mockNetworkHandler = MockNetworkHandler();
    mockNatService = MockNatTraversalService();
    // Initialize config with NAT traversal enabled and some bootstrap peers
    config = IPFSConfig(
      network: NetworkConfig(
        enableNatTraversal: true,
        bootstrapPeers: ['/ip4/1.2.3.4/tcp/4001/p2p/QmBootstrap'],
        listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
      ),
    );

    handler = AutoNATHandler(
      config,
      mockNetworkHandler,
      natService: mockNatService,
    );
  });

  group('AutoNATHandler', () {
    test('start and stop with direct connectivity', () async {
      // Setup for direct connectivity
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => true);
      when(mockNetworkHandler.testDialback()).thenAnswer((_) async => true);

      await handler.start();

      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      expect(status['nat_type'], equals(NATType.none.toString()));
      expect(status['reachable'], isTrue);

      await handler.stop();
      expect((await handler.getStatus())['running'], isFalse);
    });

    test('start with NAT and port mapping', () async {
      // Setup for NAT detected (canConnectDirectly = false)
      final natConfig = IPFSConfig(
        network: NetworkConfig(
          enableNatTraversal: true,
          bootstrapPeers: ['/ip4/1.2.3.4/tcp/4001/p2p/QmBootstrap'],
          listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
        ),
      );
      handler = AutoNATHandler(
        natConfig,
        mockNetworkHandler,
        natService: mockNatService,
      );

      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(mockNetworkHandler.testDialback()).thenAnswer((_) async => true);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => ['TCP']);

      await handler.start();

      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      expect(status['nat_type'], equals(NATType.restricted.toString()));
      expect(status['reachable'], isTrue);

      verify(mockNatService.mapPort(4001)).called(1);

      await handler.stop();
      verify(mockNatService.unmapPort(4001)).called(1);
    });

    test('start with NAT and port mapping failure', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(mockNetworkHandler.testDialback()).thenAnswer((_) async => false);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => []); // Failure

      await handler.start();

      final status = await handler.getStatus();
      expect(status['reachable'], isFalse);
    });

    test('getStatus returns correct info', () async {
      final status = await handler.getStatus();
      expect(status.containsKey('running'), isTrue);
      expect(status.containsKey('nat_type'), isTrue);
      expect(status.containsKey('reachable'), isTrue);
    });

    test('already running/stopped warnings', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => true);
      await handler.start();
      await handler.start(); // Should log warning

      await handler.stop();
      await handler.stop(); // Should log warning
    });

    test('detectNATType handles error', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenThrow(Exception('Network error'));

      await handler.start();

      final status = await handler.getStatus();
      expect(status['nat_type'], equals(NATType.unknown.toString()));
    });

    test('attemptPortMapping with no ports in config', () async {
      final noPortConfig = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/0.0.0.0'], // No tcp/udp port
        ),
      );
      handler = AutoNATHandler(
        noPortConfig,
        mockNetworkHandler,
        natService: mockNatService,
      );
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);

      await handler.start();

      verifyNever(mockNatService.mapPort(any));
    });

    test('stop handles unmapPort error', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => ['TCP']);
      when(mockNatService.unmapPort(any)).thenThrow(Exception('Unmap error'));

      await handler.start();

      // stop() rethrows exceptions
      expect(() => handler.stop(), throwsException);
    });

    test('periodic dialback test', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => true);
      when(mockNetworkHandler.testDialback()).thenAnswer((_) async => true);

      await handler.start();
      // Verify it was called at least once
      verify(mockNetworkHandler.testDialback()).called(greaterThan(0));
    });

    test('_performDialbackTest handles exception', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(
        mockNetworkHandler.testDialback(),
      ).thenThrow(Exception('Dialback error'));

      await handler.start();

      final status = await handler.getStatus();
      expect(status['reachable'], isFalse);
    });

    test('_checkDirectConnectivity with empty bootstrap list', () async {
      final emptyConfig = IPFSConfig(
        network: NetworkConfig(bootstrapPeers: []),
      );
      handler = AutoNATHandler(
        emptyConfig,
        mockNetworkHandler,
        natService: mockNatService,
      );

      await handler.start();

      final status = await handler.getStatus();
      expect(status['nat_type'], equals(NATType.restricted.toString()));
    });

    test('_attemptPortMapping with multiple addresses', () async {
      final multiConfig = IPFSConfig(
        network: NetworkConfig(
          enableNatTraversal: true,
          listenAddresses: ['/ip4/0.0.0.0/udp/5001', '/ip4/0.0.0.0/tcp/4002'],
        ),
      );
      handler = AutoNATHandler(
        multiConfig,
        mockNetworkHandler,
        natService: mockNatService,
      );
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => ['UDP']);

      await handler.start();

      verify(mockNatService.mapPort(5001)).called(1);
    });

    test('_attemptPortMapping failure', () async {
      when(
        mockNetworkHandler.canConnectDirectly(any),
      ).thenAnswer((_) async => false);
      when(mockNatService.mapPort(any)).thenAnswer((_) async => []);

      await handler.start();

      verify(mockNatService.mapPort(4001)).called(1);
      final status = await handler.getStatus();
      expect(status['reachable'], isFalse);
    });
  });
}
