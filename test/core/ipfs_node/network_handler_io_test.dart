import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

// Mock Router
class MockRouter implements RouterInterface {
  final StreamController<ConnectionEvent> _connectionEvents =
      StreamController<ConnectionEvent>.broadcast();
  final StreamController<MessageEvent> _messageEvents =
      StreamController<MessageEvent>.broadcast();

  bool isStarted = false;
  Map<String, Uint8List> sentMessages = {};

  @override
  Stream<ConnectionEvent> get connectionEvents => _connectionEvents.stream;
  @override
  Stream<MessageEvent> get messageEvents => _messageEvents.stream;

  @override
  Future<void> start() async {
    isStarted = true;
  }

  @override
  Future<void> stop() async {
    isStarted = false;
    await _connectionEvents.close();
    await _messageEvents.close();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> connect(String multiaddress) async {}

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}

  @override
  List<String> listConnectedPeers() => ['peer1', 'peer2'];

  @override
  Future<void> sendMessage(
    String peerId,
    Uint8List message, {
    String? protocolId,
  }) async {
    sentMessages[peerId] = message;
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    return Uint8List.fromList(utf8.encode('response'));
  }

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {}

  // Stub other methods as they are required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSNode extends IPFSNode {
  MockIPFSNode() : super.fromContainer(ServiceContainer());
  // Helper to allow generic mocking if needed
}

void main() {
  group('NetworkHandler', () {
    late IPFSConfig config;
    late MockRouter mockRouter;
    late NetworkHandler networkHandler;

    setUp(() {
      // Use modifiable list for bootstrap peers
      final networkConfig = NetworkConfig(
        bootstrapPeers: List.of([], growable: true),
        enableMDNS: false,
      );
      config = IPFSConfig(offline: false, network: networkConfig);
      mockRouter = MockRouter();
      networkHandler = NetworkHandler(config, router: mockRouter);
      // We need to inject ipfsNode if we want full event handling
      // networkHandler.setIpfsNode(MockIPFSNode());
    });

    test('initialization and start', () async {
      await networkHandler.initialize();
      await networkHandler.start();
      expect(mockRouter.isStarted, isTrue);
      await networkHandler.stop();
      expect(mockRouter.isStarted, isFalse);
    });

    test('listConnectedPeers delegation', () async {
      final peers = await networkHandler.listConnectedPeers();
      expect(peers, equals(['peer1', 'peer2']));
    });

    test('sendMessage encoding', () async {
      await networkHandler.sendMessage('peer1', 'hello');
      final sent = mockRouter.sentMessages['peer1'];
      expect(utf8.decode(sent!), 'hello');
    });

    test('connectToPeer and disconnectFromPeer do not throw', () async {
      // These are void methods that delegate to router
      await networkHandler.connectToPeer('/ip4/127.0.0.1/tcp/4001');
      await networkHandler.disconnectFromPeer('peer1');
    });

    test('canConnectDirectly returns true on success', () async {
      final result = await networkHandler.canConnectDirectly(
        '/ip4/127.0.0.1/tcp/4001',
      );
      expect(result, isTrue);
    });

    test('testDialback usage', () async {
      // Bootstrap peers are needed for dialback
      config.network.bootstrapPeers.add('/ip4/127.0.0.1/tcp/4001/p2p/QmBoot');
      final result = await networkHandler.testDialback();
      // Our mock returns 'response' which is not null/empty, so should be true
      expect(result, isTrue);
    });
  });
}
