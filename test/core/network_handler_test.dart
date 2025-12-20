import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

class MockP2plibRouter extends P2plibRouter {
  MockP2plibRouter(super.config) : super.internal();

  bool started = false;
  final List<String> _mockConnectedPeers = [];

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<void> connect(String address) async {
    _mockConnectedPeers.add(address);
  }

  @override
  Future<void> disconnect(String address) async {
    _mockConnectedPeers.remove(address);
  }

  @override
  List<String> listConnectedPeers() {
    return _mockConnectedPeers;
  }

  // Override connectedPeers to avoid errors if called (return empty list of Routes)
  @override
  List<String> get connectedPeers => [];
}

void main() {
  group('NetworkHandler', () {
    late NetworkHandler handler;
    late IPFSConfig config;
    late MockP2plibRouter mockRouter;

    setUp(() {
      config = IPFSConfig(offline: false);
      mockRouter = MockP2plibRouter(config);
      handler = NetworkHandler(config, router: mockRouter);
    });

    test('should start and stop router', () async {
      await handler.start();
      expect(mockRouter.started, isTrue);

      await handler.stop();
      expect(mockRouter.started, isFalse);
    });

    test('should connect to peer', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001';
      await handler.connectToPeer(addr);
      expect(mockRouter.listConnectedPeers(), contains(addr));
    });

    test('should disconnect from peer', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001';
      await handler.connectToPeer(addr);
      await handler.disconnectFromPeer(addr);
      expect(mockRouter.listConnectedPeers(), isEmpty);
    });

    test('should list connected peers', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001';
      await handler.connectToPeer(addr);

      final peers = await handler.listConnectedPeers();
      expect(peers, contains(addr));
    });
  });
}
