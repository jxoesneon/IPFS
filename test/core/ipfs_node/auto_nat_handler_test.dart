import 'dart:async';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
// import 'package:dart_ipfs/src/core/config/network_config.dart'; // Removed to avoid conflict
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import '../../mocks/mock_nat_traversal_service.dart';

// Mock NetworkHandler manually since we don't have mockito generated code easily available for it
class MockNetworkHandler extends Mock implements NetworkHandler {
  @override
  Future<bool> canConnectDirectly(String addr) async => false;

  @override
  Future<bool> testDialback() async {
    return true;
  }

  @override
  Future<String> testConnection({required int sourcePort}) async {
    return '4001'; // Return same port to simulate restricted (not symmetric) NAT
  }

  @override
  void addListener(void Function(NetworkEvent) listener) {}

  @override
  void removeListener(void Function(NetworkEvent) listener) {}
}

void main() {
  group('AutoNATHandler', () {
    late AutoNATHandler handler;
    late IPFSConfig config;
    late MockNetworkHandler mockNetworkHandler;
    late MockNatTraversalService mockNatService;

    setUp(() {
      config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/0.0.0.0/tcp/4001', '/ip6/::/tcp/4001'],
          enableNatTraversal: true,
        ),
      );
      mockNetworkHandler = MockNetworkHandler();
      mockNatService = MockNatTraversalService();

      handler = AutoNATHandler(
        config,
        mockNetworkHandler,
        natService: mockNatService,
      );
    });

    test('start detects NAT and attempts port mapping', () async {
      await handler.start();

      // Should have attempted to map port 4001 extracted from config
      expect(mockNatService.mappedPorts, contains(4001));

      final status = await handler.getStatus();
      expect(status['running'], true);
    });

    test('stop unmaps ports', () async {
      await handler.start();
      await handler.stop();

      expect(mockNatService.unmappedPorts, contains(4001));
      final status = await handler.getStatus();
      expect(status['running'], false);
    });

    test('extracts port correctly from non-standard config', () async {
      final customConfig = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/8080'],
          enableNatTraversal: true,
        ),
      );
      handler = AutoNATHandler(
        customConfig,
        mockNetworkHandler,
        natService: mockNatService,
      );

      await handler.start();
      expect(mockNatService.mappedPorts, contains(8080));
    });
  });
}
