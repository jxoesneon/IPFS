import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler_io.dart'; // import IO version for testing
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/transport/router_events.dart'; // Needed for NetworkPacket
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

// --- Mocks ---

class MockRouterInterface extends Mock implements RouterInterface {
  final _connectedPeers = <String>[];

  @override
  List<String> listConnectedPeers() => _connectedPeers;

  @override
  Future<void> connect(String address) async {
    _connectedPeers.add(address);
  }

  @override
  Future<void> disconnect(String address) async {
    _connectedPeers.remove(address);
  }

  // We need to capture the address passed to sendMessage/sendRequest to verify the fix
  String? lastTargetAddress;

  @override
  Future<Uint8List> sendRequest(
    String address,
    String protocol,
    Uint8List data,
  ) async {
    lastTargetAddress = address;
    return Uint8List.fromList([
      1,
    ]); // Return success (non-empty for isNotEmpty check)
  }

  @override
  String get peerID => 'QmLocalNode';

  @override
  Stream<ConnectionEvent> get connectionEvents => Stream.empty();

  @override
  Stream<MessageEvent> get messageEvents => Stream.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    // No-op for mock
  }

  @override
  void removeMessageHandler(String protocolId) {
    // No-op for mock
  }
}

class FakeNatTraversalService implements NatTraversalService {
  final mappedPorts = <int>[];
  final unmappedPorts = <int>[];

  @override
  Future<List<String>> mapPort(int port, {Duration? leaseDuration}) async {
    // print('DEBUG: mapPort called for $port');
    mappedPorts.add(port);
    return ['TCP', 'UDP'];
  }

  @override
  Future<void> unmapPort(int port) async {
    unmappedPorts.add(port);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubNetworkHandler extends Fake implements NetworkHandler {
  @override
  IPFSConfig get config => IPFSConfig(network: NetworkConfig()); // Dummy config if accessed

  @override
  Future<bool> canConnectDirectly(String peerAddress) async {
    return false; // Simulate NOT reachable directly
  }

  @override
  Future<String> testConnection({required int sourcePort}) async {
    return '1.2.3.4'; // Simulate fixed external IP
  }

  @override
  Future<bool> testDialback() async {
    return false; // Dialback check itself is not the focus of Port Mapping test, but result is stored.
  }
}

// --- Tests ---

void main() {
  group('Full NAT Integration Test', () {
    test(
      'NetworkHandler.testDialback correctly extracts PeerID from Multiaddr (Fix Verification)',
      () async {
        // Setup
        final config = IPFSConfig(
          network: NetworkConfig(
            // Provide a bootstrap peer with a Multiaddr containing path segments
            bootstrapPeers: ['/ip4/127.0.0.1/tcp/4001/p2p/QmTargetPeerID'],
          ),
        );

        final mockRouter = MockRouterInterface();
        final networkHandler = NetworkHandler(config, router: mockRouter);

        // Execute
        final result = await networkHandler.testDialback();

        // Verify
        expect(result, isTrue, reason: 'Dialback should succeed via mock');

        // CRITICAL: Check that the router received the extracted PeerID ('QmTargetPeerID'),
        // NOT the full Multiaddr ('/ip4/.../QmTargetPeerID').
        expect(
          mockRouter.lastTargetAddress,
          'QmTargetPeerID',
          reason:
              'NetworkHandler incorrectly sent the full Multiaddr instead of PeerID',
        );
      },
    );

    test('AutoNATHandler full lifecycle with NAT and Port Mapping', () async {
      // Setup
      final config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/0.0.0.0/tcp/5001'], // use different port
          enableNatTraversal: true,
          bootstrapPeers: [
            '/ip4/1.2.3.4/tcp/4001',
            '/ip4/5.6.7.8/tcp/4001',
          ], // Needs >1 peers to fail loose threshold (1 ~/ 2 = 0)
        ),
        debug: true,
      );

      final stubNetworkHandler = StubNetworkHandler();

      final natService = FakeNatTraversalService();

      final autoNat = AutoNATHandler(
        config,
        stubNetworkHandler,
        natService: natService,
      );

      // Execute Start
      await autoNat.start();

      // Verify Status (should be running)
      final status = await autoNat.getStatus();
      expect(status['running'], isTrue);

      // Verify Port Mapping attempted
      expect(natService.mappedPorts, contains(5001));

      // Execute Stop
      await autoNat.stop();

      // Verify Stops cleanly and unmaps
      expect(natService.unmappedPorts, contains(5001));
      final assignedStatus = await autoNat.getStatus();
      expect(assignedStatus['running'], isFalse);
    });
  });
}
