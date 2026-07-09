// test/core/peering/peering_service_test.dart
import 'dart:async';

import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/peering/peering_service.dart';

import '../../fakes/fake_router.dart';

class _FakeRouter extends FakeRouter {
  final Set<String> _connected = {};
  final List<String> connectAttempts = [];
  bool failConnect = false;

  void setConnected(String peerId, bool connected) {
    if (connected) {
      _connected.add(peerId);
    } else {
      _connected.remove(peerId);
    }
  }

  @override
  bool isConnectedPeer(String peerIdStr) => _connected.contains(peerIdStr);

  @override
  Future<void> connect(String multiaddress) async {
    final parts = multiaddress.split('/p2p/');
    final peerId = parts.length > 1 ? parts.last : multiaddress;
    connectAttempts.add(peerId);
    if (failConnect) throw Exception('connect failed');
    _connected.add(peerId);
  }
}

void main() {
  group('PeeringConfig', () {
    test('toJson/fromJson roundtrip', () {
      const config = PeeringConfig(
        enabled: true,
        peers: ['/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'],
        checkInterval: Duration(seconds: 10),
        initialReconnectDelay: Duration(seconds: 1),
        maxReconnectDelay: Duration(minutes: 1),
        maxReconnectAttempts: 3,
      );
      final json = config.toJson();
      final parsed = PeeringConfig.fromJson(json);
      expect(parsed.enabled, equals(config.enabled));
      expect(parsed.peers, equals(config.peers));
      expect(parsed.checkInterval, equals(config.checkInterval));
      expect(parsed.initialReconnectDelay, equals(config.initialReconnectDelay));
      expect(parsed.maxReconnectDelay, equals(config.maxReconnectDelay));
      expect(parsed.maxReconnectAttempts, equals(config.maxReconnectAttempts));
    });

    test('fromJson uses defaults', () {
      final parsed = PeeringConfig.fromJson({});
      expect(parsed.enabled, isTrue);
      expect(parsed.peers, isEmpty);
      expect(parsed.checkInterval, equals(const Duration(seconds: 30)));
      expect(parsed.initialReconnectDelay, equals(const Duration(seconds: 5)));
      expect(parsed.maxReconnectDelay, equals(const Duration(minutes: 10)));
      expect(parsed.maxReconnectAttempts, equals(0));
    });
  });

  group('PeeringService', () {
    late _FakeRouter fakeRouter;
    late NetworkHandler networkHandler;
    late IPFSConfig config;

    setUp(() {
      fakeRouter = _FakeRouter();
      config = IPFSConfig(network: NetworkConfig());
      networkHandler = NetworkHandler(config, router: fakeRouter);
    });

    tearDown(() async {
      await networkHandler.stop();
    });

    test('start and stop when disabled', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(enabled: false),
      );
      await service.start();
      final status = await service.getStatus();
      expect(status['running'], isTrue);
      expect(status['enabled'], isFalse);
      await service.stop();
      expect((await service.getStatus())['running'], isFalse);
    });

    test('start idempotency', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(enabled: false),
      );
      await service.start();
      await service.start();
      expect((await service.getStatus())['running'], isTrue);
      await service.stop();
    });

    test('stop idempotency', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(enabled: false),
      );
      await service.start();
      await service.stop();
      await service.stop();
      expect((await service.getStatus())['running'], isFalse);
    });

    test('start with peer already connected emits connected event', () async {
      const peerAddr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      fakeRouter.setConnected('QmPeer', true);
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: [peerAddr],
          checkInterval: Duration(hours: 1),
        ),
      );
      final events = <PeeringEvent>[];
      service.events.listen(events.add);
      await service.start();
      expect(events, hasLength(1));
      expect(events.first.type, equals(PeeringEventType.connected));
      expect(events.first.peerId, equals('QmPeer'));
      final status = await service.getStatus();
      expect(status['connected'], equals(1));
      expect(status['total_peers'], equals(1));
      await service.stop();
    });

    test('connects to a disconnected peer and emits event later', () async {
      const peerAddr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer2';
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: PeeringConfig(
          peers: [peerAddr],
          checkInterval: const Duration(milliseconds: 10),
        ),
      );
      final events = <PeeringEvent>[];
      service.events.listen(events.add);
      await service.start();
      // Wait for the periodic check to observe the successful connection.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeRouter.connectAttempts, contains('QmPeer2'));
      expect(events.any((e) => e.type == PeeringEventType.connected), isTrue);
      await service.stop();
    });

    test('addPeer extracts peerId and connects', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          checkInterval: Duration(hours: 1),
        ),
      );
      await service.start();
      service.addPeer('/ip4/1.2.3.4/tcp/4001/p2p/QmAdded');
      expect(service.peeredPeerIds, contains('QmAdded'));
      expect(fakeRouter.connectAttempts, contains('QmAdded'));
      await service.stop();
    });

    test('addPeer ignores invalid multiaddr', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(),
      );
      await service.start();
      service.addPeer('/ip4/1.2.3.4/tcp/4001');
      expect(service.peeredPeerIds, isEmpty);
      await service.stop();
    });

    test('addPeer ignores duplicate peer', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: ['/ip4/1.2.3.4/tcp/4001/p2p/QmDup'],
        ),
      );
      await service.start();
      service.addPeer('/ip4/1.2.3.4/tcp/4001/p2p/QmDup');
      expect(service.peeredPeerIds, equals(['QmDup']));
      await service.stop();
    });

    test('removePeer removes and reports missing', () async {
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: ['/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'],
        ),
      );
      await service.start();
      service.removePeer('QmPeer');
      expect(service.peeredPeerIds, isEmpty);
      service.removePeer('QmPeer');
      await service.stop();
    });

    test('isPeerConnected reflects state', () async {
      const peerAddr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      fakeRouter.setConnected('QmPeer', true);
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: [peerAddr],
          checkInterval: Duration(hours: 1),
        ),
      );
      await service.start();
      expect(service.isPeerConnected('QmPeer'), isTrue);
      await service.stop();
      expect(service.isPeerConnected('QmPeer'), isFalse);
    });

    test('status is consistent after stop', () async {
      const peerAddr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: [peerAddr],
        ),
      );
      await service.start();
      await service.stop();
      final status = await service.getStatus();
      expect(status['running'], isFalse);
      expect(status['total_peers'], equals(0));
    });

    test('emits disconnected event when peer goes offline', () async {
      const peerAddr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      fakeRouter.setConnected('QmPeer', true);
      final service = PeeringService(
        config,
        networkHandler,
        peeringConfig: const PeeringConfig(
          peers: [peerAddr],
          checkInterval: const Duration(milliseconds: 10),
        ),
      );
      final events = <PeeringEvent>[];
      service.events.listen(events.add);
      await service.start();
      fakeRouter.setConnected('QmPeer', false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events.any((e) => e.type == PeeringEventType.disconnected), isTrue);
      await service.stop();
    });
  });
}
