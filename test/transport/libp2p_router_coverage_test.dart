import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

void main() {
  group('Libp2pRouter Coverage', () {
    late Libp2pRouter router;
    late IPFSConfig config;

    IPFSConfig createConfig([int port = 0]) {
      return IPFSConfig(
        network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/tcp/$port']),
      );
    }

    setUp(() {
      config = createConfig();
      router = Libp2pRouter(config);
    });

    tearDown(() async {
      if (router.hasStarted) {
        await router.stop();
      }
    });

    test('initialize should handle seed', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final seedRouter = Libp2pRouter(createConfig(), seed: seed);
      await seedRouter.initialize();
      expect(
        seedRouter.isInitialized,
        isTrue,
        reason: 'Router should be initialized after calling initialize()',
      );
      expect(seedRouter.peerID, isNotEmpty);
    });

    test('initialize should not re-initialize', () async {
      await router.initialize();
      expect(router.isInitialized, isTrue);
      final pidBefore = router.peerID;
      await router.initialize();
      expect(router.peerID, pidBefore);
    });

    test('start should handle empty listen addresses', () async {
      final emptyRouter = Libp2pRouter(
        IPFSConfig(network: NetworkConfig(listenAddresses: [])),
      );
      await emptyRouter.start();
      expect(emptyRouter.hasStarted, isTrue);
      await emptyRouter.stop();
    });

    test('start should handle invalid port in listen addresses', () async {
      final invalidRouter = Libp2pRouter(
        IPFSConfig(
          network: NetworkConfig(
            listenAddresses: ['/ip4/127.0.0.1/tcp/invalid'],
          ),
        ),
      );
      await invalidRouter.start();
      expect(invalidRouter.hasStarted, isTrue);
      await invalidRouter.stop();
    });

    test('start should not re-start', () async {
      await router.start();
      expect(router.hasStarted, isTrue);
      await router.start();
      expect(router.hasStarted, isTrue);
    });

    test('stop should handle not started', () async {
      await router.stop();
      expect(router.hasStarted, isFalse);
    });

    test('connect should throw on invalid multiaddress', () async {
      await router.start();
      expect(
        () => router.connect('/ip4/127.0.0.1/tcp/4001'),
        throwsArgumentError,
      );
    });

    test('disconnect should handle multiaddress and peerId', () async {
      await router.start();
      final peerId = '12D3KooWK39Nd6yHE6xy5ZNG95ukvrQZF2axYZr6RSKoyMbAkGD2';
      final multiaddr = '/ip4/127.0.0.1/tcp/4001/p2p/$peerId';

      router.connectedPeers.add(peerId);
      await router.disconnect(multiaddr);
      expect(router.connectedPeers, isNot(contains(peerId)));

      router.connectedPeers.add(peerId);
      await router.disconnect(peerId);
      expect(router.connectedPeers, isNot(contains(peerId)));
    });

    test('broadcastMessage should send to multiple peers', () async {
      final rA = Libp2pRouter(createConfig(4501));
      final rB = Libp2pRouter(createConfig(4502));
      final rC = Libp2pRouter(createConfig(4503));

      await Future.wait([rA.start(), rB.start(), rC.start()]);

      final completerB = Completer<void>();
      final completerC = Completer<void>();
      final protocol = '/test/broadcast/1.0.0';

      rB.registerProtocolHandler(protocol, (_) => completerB.complete());
      rC.registerProtocolHandler(protocol, (_) => completerC.complete());

      await rA.connect('/ip4/127.0.0.1/tcp/4502/p2p/${rB.peerID}');
      await rA.connect('/ip4/127.0.0.1/tcp/4503/p2p/${rC.peerID}');

      await Future.delayed(Duration(milliseconds: 1000));
      await rA.broadcastMessage(
        protocol,
        Uint8List.fromList(utf8.encode('hi')),
      );

      await Future.wait([
        completerB.future.timeout(Duration(seconds: 5)),
        completerC.future.timeout(Duration(seconds: 5)),
      ]);

      await Future.wait([rA.stop(), rB.stop(), rC.stop()]);
    });

    test('sendRequest should receive response', () async {
      final rA = Libp2pRouter(createConfig(4601));
      final rB = Libp2pRouter(createConfig(4602));

      await rA.start();
      await rB.start();

      final protocol = '/test/request/1.0.0';
      rB.registerProtocolHandler(protocol, (packet) async {
        if (packet.responder != null) {
          final resp = utf8.encode('Echo: ${utf8.decode(packet.datagram)}');
          await packet.responder!(Uint8List.fromList(resp));
        }
      });

      await rA.connect('/ip4/127.0.0.1/tcp/4602/p2p/${rB.peerID}');
      await Future.delayed(Duration(milliseconds: 1000));

      final result = await rA.sendRequest(
        rB.peerID,
        protocol,
        Uint8List.fromList(utf8.encode('Hello')),
      );

      expect(result, isNotNull);
      expect(utf8.decode(result!), equals('Echo: Hello'));

      await rA.stop();
      await rB.stop();
    });

    test('getters and basic methods', () async {
      expect(router.listeningAddresses, equals(config.network.listenAddresses));
      expect(router.connectionEvents, isA<Stream<ConnectionEvent>>());
      expect(router.messageEvents, isA<Stream<MessageEvent>>());
      expect(router.connectedPeers, isEmpty);
      expect(router.hasStarted, isFalse);
      expect(router.isInitialized, isFalse);
      expect(router.peerID, isEmpty);

      await router.initialize();
      expect(router.isInitialized, isTrue);
      expect(router.peerID, isNotEmpty);

      expect(router.listConnectedPeers(), isEmpty);
      expect(router.isConnectedPeer('any'), isFalse);
    });

    test('broadcastMessage should handle failure for some peers', () async {
      await router.start();
      final fakePeer = '12D3KooWK39Nd6yHE6xy5ZNG95ukvrQZF2axYZr6RSKoyMbAkGD2';
      router.connectedPeers.add(fakePeer);
      await router.broadcastMessage('/test', Uint8List(0));
      router.connectedPeers.remove(fakePeer);
    });

    test('sendMessage should handle large messages', () async {
      final rA = Libp2pRouter(createConfig(4701));
      final rB = Libp2pRouter(createConfig(4702));
      await rA.start();
      await rB.start();

      final protocol = '/ipfs/1.0.0';
      rB.registerProtocolHandler(protocol, (_) {});

      await rA.connect('/ip4/127.0.0.1/tcp/4702/p2p/${rB.peerID}');
      await Future.delayed(Duration(milliseconds: 500));
      await rA.sendMessage(rB.peerID, Uint8List(300), protocolId: protocol);

      await rA.stop();
      await rB.stop();
    });

    test('stop should handle multiple calls', () async {
      await router.start();
      await router.stop();
      await router.stop();
      expect(router.hasStarted, isFalse);
    });

    test('receiveMessages should return same stream', () {
      final s1 = router.receiveMessages('p1');
      final s2 = router.receiveMessages('p1');
      expect(s1, equals(s2));
    });

    test('event methods management', () {
      final res = [];
      void h(dynamic m) => res.add(m);
      router.onEvent('t', h);
      router.emitEvent('t', Uint8List.fromList([1]));
      expect(res.length, 1);
      router.offEvent('t', h);
      router.emitEvent('t', Uint8List.fromList([2]));
      expect(res.length, 1);
    });

    test('parseMultiaddr and resolvePeerId', () {
      expect(router.parseMultiaddr('invalid'), isNull);
      expect(router.resolvePeerId('any'), isEmpty);
    });

    test('methods should throw if not started', () async {
      expect(() => router.connect('...'), throwsStateError);
      expect(() => router.sendMessage('p', Uint8List(0)), throwsStateError);
      expect(
        () => router.sendRequest('p', 'pr', Uint8List(0)),
        throwsStateError,
      );
      expect(
        () => router.broadcastMessage('pr', Uint8List(0)),
        throwsStateError,
      );
    });

    test('protocol management', () {
      router.registerProtocolHandler('/p', (_) {});
      router.removeMessageHandler('/p');
      router.registerProtocol('/new');
    });
  });
}
