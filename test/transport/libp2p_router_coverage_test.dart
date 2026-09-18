import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:test/test.dart';

List<int> _varintBytes(int value) {
  final out = <int>[];
  var n = value;
  while (n >= 0x80) {
    out.add((n & 0x7F) | 0x80);
    n >>= 7;
  }
  out.add(n);
  return out;
}

void main() {
  group('Libp2pRouter Coverage', () {
    late Libp2pRouter router;
    late IPFSConfig config;
    late Directory repoDir;

    IPFSConfig createConfig([int port = 0]) {
      return IPFSConfig(
        dataPath: '${repoDir.path}/node_$port',
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/$port'],
          bootstrapPeers: [],
        ),
      );
    }

    setUp(() {
      repoDir = Directory.systemTemp.createTempSync('ipfs_router_repo_');
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
        IPFSConfig(
          dataPath: '${repoDir.path}/empty',
          network: NetworkConfig(listenAddresses: []),
        ),
      );
      await emptyRouter.start();
      expect(emptyRouter.hasStarted, isTrue);
      await emptyRouter.stop();
    });

    test('start should handle invalid port in listen addresses', () async {
      final invalidRouter = Libp2pRouter(
        IPFSConfig(
          dataPath: '${repoDir.path}/invalid',
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

      await Future<void>.delayed(Duration(milliseconds: 1000));
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
      await Future<void>.delayed(Duration(milliseconds: 1000));

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
      await Future<void>.delayed(Duration(milliseconds: 500));
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
      final res = <dynamic>[];
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
      expect(router.supportedProtocols, contains('/new'));
      expect(() => router.supportedProtocols.add('/x'), throwsUnsupportedError);
    });

    test('unregisterProtocolHandler removes protocol and handler', () async {
      await router.start();
      router.registerProtocolHandler('/test/unreg/1.0.0', (_) {});
      expect(router.supportedProtocols, contains('/test/unreg/1.0.0'));
      router.unregisterProtocolHandler('/test/unreg/1.0.0');
      expect(router.supportedProtocols, isNot(contains('/test/unreg/1.0.0')));
    });

    test('registerRelayedConnection tracks the peer', () async {
      await router.start();
      router.registerRelayedConnection(
        'relay-target',
        '/p2p/relay/p2p-circuit/p2p/relay-target',
      );
      expect(router.isConnectedPeer('relay-target'), isTrue);
      expect(router.connectedPeers, contains('relay-target'));
    });

    test('stop closes per-peer message stream controllers', () async {
      await router.start();
      // receiveMessages() lazily creates a broadcast controller per peer;
      // stop() must close it so listeners observe a done event.
      final done = Completer<void>();
      router.receiveMessages('peer-x').listen((_) {}, onDone: done.complete);

      await router.stop();
      await done.future.timeout(const Duration(seconds: 5));
    });

    test(
      'start fails when the configured swarm key cannot be read',
      () async {
        // A swarm key file that exists but is unreadable makes
        // loadSwarmKey's platform read throw, which propagates through
        // _loadPrivateNetworkPsk into start()'s catch -> StateError.
        final keyFile = File(
          '${repoDir.path}/swarm.key',
        )..writeAsStringSync('/key/swarm/psk/1.0.0/\n/base16/\n${'00' * 32}\n');
        await Process.run('chmod', ['000', keyFile.path]);

        final pskRouter = Libp2pRouter(
          IPFSConfig(
            dataPath: '${repoDir.path}/psk_fail',
            network: NetworkConfig(
              listenAddresses: const ['/ip4/127.0.0.1/tcp/0'],
              bootstrapPeers: const [],
              swarmKeyPath: keyFile.path,
            ),
          ),
        );

        try {
          await expectLater(pskRouter.start(), throwsStateError);
          expect(pskRouter.hasStarted, isFalse);
        } finally {
          await Process.run('chmod', ['600', keyFile.path]);
        }
      },
      // chmod is POSIX-only; the test environment is Linux.
      testOn: '!windows',
    );

    group('inbound protocol streams', () {
      IPFSConfig nodeConfig(String name) {
        return IPFSConfig(
          dataPath: '${repoDir.path}/$name',
          network: NetworkConfig(
            listenAddresses: const ['/ip4/127.0.0.1/tcp/0'],
            bootstrapPeers: [],
          ),
        );
      }

      Future<String> dialAddressOf(Libp2pRouter peer) async {
        final addr = peer.listeningAddresses.firstWhere(
          (a) => a.contains('/tcp/'),
        );
        return '$addr/p2p/${peer.peerID}';
      }

      test('attaches protocol handlers registered before start', () async {
        final rA = Libp2pRouter(nodeConfig('pre_a'));
        final rB = Libp2pRouter(nodeConfig('pre_b'));

        const protocol = '/test/prestart/1.0.0';
        final completer = Completer<NetworkPacket>();
        // Registered before the host exists; start() must replay the
        // attachment once the host is created.
        rB.registerProtocolHandler(protocol, completer.complete);

        await rA.start();
        await rB.start();

        await rA.connect(await dialAddressOf(rB));
        await rA.sendMessage(
          rB.peerID,
          Uint8List.fromList([1, 2, 3]),
          protocolId: protocol,
        );

        final packet = await completer.future.timeout(
          const Duration(seconds: 5),
        );
        expect(packet.datagram, equals([1, 2, 3]));

        await rA.stop();
        await rB.stop();
      });

      test(
        'closes the inbound stream after the remote peer finishes',
        () async {
          final rA = Libp2pRouter(nodeConfig('close_a'));
          final rB = Libp2pRouter(nodeConfig('close_b'));
          await rA.start();
          await rB.start();

          const protocol = '/test/close/1.0.0';
          final completer = Completer<NetworkPacket>();
          rB.registerProtocolHandler(protocol, completer.complete);

          await rA.connect(await dialAddressOf(rB));
          // sendMessage writes one length-prefixed message and closes the
          // stream; the server observes EOF, exits its read loop, and closes
          // its side of the stream in the finally block.
          await rA.sendMessage(
            rB.peerID,
            Uint8List.fromList([7]),
            protocolId: protocol,
          );

          final packet = await completer.future.timeout(
            const Duration(seconds: 5),
          );
          expect(packet.datagram, equals([7]));

          await Future<void>.delayed(const Duration(milliseconds: 300));

          await rA.stop();
          await rB.stop();
        },
      );

      test('rejects an oversized inbound message', () async {
        final rA = Libp2pRouter(nodeConfig('big_a'));
        final rB = Libp2pRouter(nodeConfig('big_b'));
        await rA.start();
        await rB.start();

        const protocol = '/test/oversize/1.0.0';
        final received = <Uint8List>[];
        rB.registerProtocolHandler(protocol, (p) => received.add(p.datagram));

        await rA.connect(await dialAddressOf(rB));

        // Advertise a body one byte over the 4 MiB inbound cap: the server
        // rejects the length prefix (FormatException) and drops the stream
        // without invoking the handler.
        final stream = await rA.host!.newStream(
          libp2p.PeerId.fromString(rB.peerID),
          [protocol],
          libp2p.Context(timeout: const Duration(seconds: 10)),
        );
        try {
          await stream.write(
            Uint8List.fromList(_varintBytes(4 * 1024 * 1024 + 1)),
          );
        } finally {
          await stream.close();
        }

        // The connection still serves well-formed messages afterwards.
        await rA.sendMessage(
          rB.peerID,
          Uint8List.fromList([9]),
          protocolId: protocol,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(received.length, equals(1));
        expect(received.first, equals([9]));

        await rA.stop();
        await rB.stop();
      });

      test('warns and continues on an empty inbound message', () async {
        final rA = Libp2pRouter(nodeConfig('empty_a'));
        final rB = Libp2pRouter(nodeConfig('empty_b'));
        await rA.start();
        await rB.start();

        const protocol = '/test/empty/1.0.0';
        final completer = Completer<NetworkPacket>();
        rB.registerProtocolHandler(protocol, completer.complete);

        await rA.connect(await dialAddressOf(rB));
        // A zero-length body decodes to an empty datagram: the server logs a
        // warning and keeps reading instead of dispatching to the handler.
        await rA.sendMessage(rB.peerID, Uint8List(0), protocolId: protocol);
        await rA.sendMessage(
          rB.peerID,
          Uint8List.fromList([5]),
          protocolId: protocol,
        );

        final packet = await completer.future.timeout(
          const Duration(seconds: 5),
        );
        expect(packet.datagram, equals([5]));

        await rA.stop();
        await rB.stop();
      });

      test('responder swallows write errors on a closed stream', () async {
        final rA = Libp2pRouter(nodeConfig('resp_a'));
        final rB = Libp2pRouter(nodeConfig('resp_b'));
        await rA.start();
        await rB.start();

        const protocol = '/test/responder/1.0.0';
        final completer = Completer<NetworkPacket>();
        rB.registerProtocolHandler(protocol, completer.complete);

        await rA.connect(await dialAddressOf(rB));
        // sendMessage writes one message and closes the stream; by the time
        // the responder is invoked below, B has observed EOF and closed its
        // side too, so the response write fails and is logged internally.
        await rA.sendMessage(
          rB.peerID,
          Uint8List.fromList([3]),
          protocolId: protocol,
        );

        final packet = await completer.future.timeout(
          const Duration(seconds: 5),
        );
        expect(packet.responder, isNotNull);

        await Future<void>.delayed(const Duration(milliseconds: 500));
        // The responder must not propagate the write failure to the handler.
        await packet.responder!(Uint8List.fromList([9, 9, 9]));

        await rA.stop();
        await rB.stop();
      });

      test('logs an error when the protocol handler throws', () async {
        final rA = Libp2pRouter(nodeConfig('err_a'));
        final rB = Libp2pRouter(nodeConfig('err_b'));
        await rA.start();
        await rB.start();

        const protocol = '/test/throwing/1.0.0';
        rB.registerProtocolHandler(
          protocol,
          (_) => throw StateError('handler boom'),
        );

        await rA.connect(await dialAddressOf(rB));
        // The throw escapes the dispatch loop into the stream-level catch;
        // the stream is still closed in the finally block.
        await rA.sendMessage(
          rB.peerID,
          Uint8List.fromList([1]),
          protocolId: protocol,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));

        await rA.stop();
        await rB.stop();
      });

      test(
        'emits a disconnected event when a connected peer goes away',
        () async {
          final rA = Libp2pRouter(nodeConfig('disc_a'));
          final rB = Libp2pRouter(nodeConfig('disc_b'));
          await rA.start();
          await rB.start();

          final connected = Completer<ConnectionEvent>();
          final disconnected = Completer<ConnectionEvent>();
          rB.connectionEvents.listen((e) {
            if (e.peerId != rA.peerID) return;
            if (e.type == ConnectionEventType.connected &&
                !connected.isCompleted) {
              connected.complete(e);
            }
            if (e.type == ConnectionEventType.disconnected &&
                !disconnected.isCompleted) {
              disconnected.complete(e);
            }
          });

          await rA.connect(await dialAddressOf(rB));
          await connected.future.timeout(const Duration(seconds: 10));
          expect(rB.isConnectedPeer(rA.peerID), isTrue);

          // Let the post-connect identify exchange settle — tearing the
          // connection down mid-response makes the remote's Yamux write
          // race the dead session (observed as an unhandled async error
          // on Windows CI).
          await Future.delayed(const Duration(seconds: 1));

          // Simulate the connection dying: recording a closure on the
          // SwarmConn's health metrics transitions it to failed, so the
          // swarm removes the connection and fires disconnectedF (which
          // emits the event asserted below).
          final peerId = libp2p.PeerId.fromString(rA.peerID);
          final conn = rB.host!.network.connsToPeer(peerId).first;
          (conn as dynamic).healthMetrics.recordClosure();

          final event = await disconnected.future.timeout(
            const Duration(seconds: 10),
          );
          expect(event.type, equals(ConnectionEventType.disconnected));
          expect(rB.isConnectedPeer(rA.peerID), isFalse);

          await rA.stop();
          await rB.stop();
        },
      );

      test(
        'resolvePeerId returns listen addrs for self and dialed peers',
        () async {
          final rA = Libp2pRouter(nodeConfig('res_a'));
          final rB = Libp2pRouter(nodeConfig('res_b'));
          await rA.start();
          await rB.start();

          // The router's own peer ID resolves to its listening addresses.
          expect(rA.resolvePeerId(rA.peerID), equals(rA.listeningAddresses));
          // Unknown peers resolve to an empty list.
          expect(rA.resolvePeerId('unknown-peer'), isEmpty);

          await rA.connect(await dialAddressOf(rB));
          final addrs = rA.resolvePeerId(rB.peerID);
          expect(addrs, isNotEmpty);
          // The returned list must not be mutable by callers.
          expect(() => addrs.add('x'), throwsUnsupportedError);

          await rA.stop();
          await rB.stop();
        },
      );
    });
  });
}
