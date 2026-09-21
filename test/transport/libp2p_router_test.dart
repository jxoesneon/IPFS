import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/protocols/identify/identify_pb.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:ipfs_libp2p/config/config.dart' as config;
import 'package:ipfs_libp2p/core/crypto/ed25519.dart' as crypto;
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:ipfs_libp2p/p2p/transport/tcp_transport.dart';
import 'package:test/test.dart';

void main() {
  group('Libp2pRouter Integration', () {
    late Libp2pRouter routerA;
    late Libp2pRouter routerB;
    late IPFSConfig configA;
    late IPFSConfig configB;

    setUp(() async {
      final repoDir = Directory.systemTemp.createTempSync('ipfs_router_pair_');

      // Config for Node A (Port 0 for dynamic assignment)
      configA = IPFSConfig(
        dataPath: '${repoDir.path}/a',
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          bootstrapPeers: [],
        ),
      );

      // Config for Node B (Port 0 for dynamic assignment)
      configB = IPFSConfig(
        dataPath: '${repoDir.path}/b',
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          bootstrapPeers: [],
        ),
      );

      routerA = Libp2pRouter(configA);
      routerB = Libp2pRouter(configB);

      await routerA.initialize();
      await routerB.initialize();
    });

    tearDown(() async {
      if (routerA.hasStarted) await routerA.stop();
      if (routerB.hasStarted) await routerB.stop();
    });

    test('should start and stop successfully', () async {
      await routerA.start();
      expect(routerA.hasStarted, isTrue);
      expect(routerA.peerID, isNotEmpty);
      expect(routerA.listeningAddresses, isNotEmpty);
      // Validating it contains a tcp address
      expect(
        routerA.listeningAddresses.any((a) => a.contains('/tcp/')),
        isTrue,
      );

      await routerA.stop();
      expect(routerA.hasStarted, isFalse);
    });

    String getLocalConnectAddress(Libp2pRouter router) {
      var addr = router.listeningAddresses.firstWhere(
        (a) => a.contains('/tcp/'),
        orElse: () =>
            throw Exception('No TCP address found for peer ${router.peerID}'),
      );
      if (addr.contains('/ip4/0.0.0.0/')) {
        addr = addr.replaceAll('/ip4/0.0.0.0/', '/ip4/127.0.0.1/');
      }
      return '$addr/p2p/${router.peerID}';
    }

    test('should connect to another peer', () async {
      await routerA.start();
      await routerB.start();

      // Connect A -> B
      final addrB = getLocalConnectAddress(routerB);
      await routerA.connect(addrB);

      // Verify connection on A side
      expect(routerA.connectedPeers, contains(routerB.peerID));

      // Verify connection on B side (may take a moment for handshake)
      await Future.delayed(Duration(milliseconds: 500));
      expect(routerB.connectedPeers, contains(routerA.peerID));
    });

    test('should send and receive messages', () async {
      await routerA.start();
      await routerB.start();

      final addrB = getLocalConnectAddress(routerB);
      await routerA.connect(addrB);
      await Future.delayed(Duration(milliseconds: 500));

      final protocolId = '/test/1.0.0';
      final messageContent = 'Hello IPFS';
      final completer = Completer<String>();

      // Register handler on B
      routerB.registerProtocolHandler(protocolId, (packet) {
        completer.complete(utf8.decode(packet.datagram));
      });

      // Send message from A to B
      await routerA.sendMessage(
        routerB.peerID,
        Uint8List.fromList(utf8.encode(messageContent)),
        protocolId: protocolId,
      );

      final received = await completer.future.timeout(Duration(seconds: 5));
      expect(received, equals(messageContent));
    }, timeout: Timeout(Duration(seconds: 30)));

    test('respond-first handler sends FIN after response', () async {
      await routerA.start();
      final addrA = getLocalConnectAddress(routerA);

      routerA.registerProtocolHandler('/ipfs/id/1.0.0', (packet) {
        packet.responder?.call(
          IdentifyPb(
            protocolVersion: 'ipfs/0.1.0',
            agentVersion: 'dart_ipfs/test',
            protocols: const ['/ipfs/id/1.0.0'],
          ).encode(),
        );
      });

      // A raw libp2p client emulates go-libp2p's identify reader, which
      // consumes delimited messages until EOF. If the responder never sends
      // FIN, the read hangs until the deadline.
      final keyPair = await crypto.generateEd25519KeyPair();
      final host = await config.Libp2p.new_([
        config.Libp2p.transport(
          TCPTransport(
            resourceManager: ResourceManagerImpl(limiter: FixedLimiter()),
          ),
        ),
        config.Libp2p.listenAddrs([libp2p.MultiAddr('/ip4/0.0.0.0/tcp/0')]),
        config.Libp2p.identity(keyPair),
      ]);
      await host.start();

      try {
        final maddr = libp2p.MultiAddr(addrA);
        final peerId = libp2p.PeerId.fromString(addrA.split('/p2p/').last);
        await host.peerStore.addrBook.addAddrs(peerId, [
          maddr,
        ], const Duration(minutes: 5));
        await host.connect(libp2p.AddrInfo(peerId, [maddr]));

        final stream = await host.newStream(peerId, [
          '/ipfs/id/1.0.0',
        ], libp2p.Context());

        final buf = <int>[];
        var sawEof = false;
        try {
          while (true) {
            final chunk = await stream
                .read(4096)
                .timeout(const Duration(seconds: 3));
            if (chunk.isEmpty) {
              sawEof = true;
              break;
            }
            buf.addAll(chunk);
          }
        } on TimeoutException {
          sawEof = false;
        }

        expect(buf, isNotEmpty);
        expect(
          sawEof,
          isTrue,
          reason: 'Responder must closeWrite so read-until-EOF peers finish',
        );
      } finally {
        await host.close();
      }
    }, timeout: Timeout(Duration(seconds: 60)));

    test('ping protocol echoes an unframed 32-byte payload', () async {
      await routerA.start();
      final addrA = getLocalConnectAddress(routerA);

      // Emulate PingHandler: echo the datagram back through the responder.
      routerA.registerProtocolHandler('/ipfs/ping/1.0.0', (packet) {
        packet.responder?.call(packet.datagram);
      });

      // A raw libp2p client emulates js-libp2p's connection monitor, which
      // pings every peer ~every 10 s and aborts the connection when the
      // echo times out. Ping payloads are written raw — no length prefix.
      final keyPair = await crypto.generateEd25519KeyPair();
      final host = await config.Libp2p.new_([
        config.Libp2p.transport(
          TCPTransport(
            resourceManager: ResourceManagerImpl(limiter: FixedLimiter()),
          ),
        ),
        config.Libp2p.listenAddrs([libp2p.MultiAddr('/ip4/0.0.0.0/tcp/0')]),
        config.Libp2p.identity(keyPair),
      ]);
      await host.start();

      try {
        final maddr = libp2p.MultiAddr(addrA);
        final peerId = libp2p.PeerId.fromString(addrA.split('/p2p/').last);
        await host.peerStore.addrBook.addAddrs(peerId, [
          maddr,
        ], const Duration(minutes: 5));
        await host.connect(libp2p.AddrInfo(peerId, [maddr]));

        final stream = await host.newStream(peerId, [
          '/ipfs/ping/1.0.0',
        ], libp2p.Context());

        final payload = Uint8List.fromList(
          List<int>.generate(32, (i) => i * 7 + 13),
        );
        await stream.write(payload);
        final echo = await stream.read(64).timeout(const Duration(seconds: 5));

        expect(
          echo,
          equals(payload),
          reason: 'Ping responder must echo the raw payload verbatim',
        );
      } finally {
        await host.close();
      }
    }, timeout: Timeout(Duration(seconds: 60)));

    test(
      'session-stream protocols reuse one stream and survive idle',
      () async {
        // Compress the inbound idle bound so the test exercises the
        // session-protocol exemption in milliseconds instead of 30 s.
        final priorIdle = Libp2pRouter.inboundReadIdleTimeout;
        Libp2pRouter.inboundReadIdleTimeout = const Duration(milliseconds: 150);
        addTearDown(() => Libp2pRouter.inboundReadIdleTimeout = priorIdle);

        await routerA.start();
        await routerB.start();
        await routerA.connect(getLocalConnectAddress(routerB));
        await Future.delayed(const Duration(milliseconds: 500));

        final received = <String>[];
        final enough = Completer<void>();
        routerB.registerProtocolHandler('/meshsub/1.1.0', (packet) {
          received.add(utf8.decode(packet.datagram));
          if (received.length >= 4 && !enough.isCompleted) enough.complete();
        });

        Future<void> send(String text) => routerA.sendMessage(
          routerB.peerID,
          Uint8List.fromList(utf8.encode(text)),
          protocolId: '/meshsub/1.1.0',
        );

        await send('m1');
        // Let the inbound stream sit idle longer than the generic read
        // timeout — a session stream must not be reaped for silence.
        await Future.delayed(const Duration(milliseconds: 400));
        expect(routerA.sessionStreams, hasLength(1));
        expect(
          routerA.sessionStreams.values.single.isClosed,
          isFalse,
          reason: 'Idle session stream must stay open past the generic bound',
        );

        // Serialized writers preserve order even when sends overlap.
        final concurrent = [send('m2'), send('m3')];
        await Future.wait(concurrent);
        await send('m4');

        await enough.future.timeout(const Duration(seconds: 5));
        expect(received, equals(['m1', 'm2', 'm3', 'm4']));
        expect(routerA.sessionStreams, hasLength(1));
      },
      timeout: Timeout(Duration(seconds: 60)),
    );

    test('session stream reopens after the remote closes it', () async {
      await routerA.start();
      await routerB.start();
      await routerA.connect(getLocalConnectAddress(routerB));
      await Future.delayed(const Duration(milliseconds: 500));

      final received = Completer<String>();
      routerB.registerProtocolHandler('/meshsub/1.1.0', (packet) {
        if (!received.isCompleted) {
          received.complete(utf8.decode(packet.datagram));
        }
      });

      Future<void> send(String text) => routerA.sendMessage(
        routerB.peerID,
        Uint8List.fromList(utf8.encode(text)),
        protocolId: '/meshsub/1.1.0',
      );

      await send('first');
      final firstStream = routerA.sessionStreams.values.single;

      // Simulate the remote tearing the stream down between sends.
      await firstStream.close();
      expect(routerA.sessionStreams.values.single.isClosed, isTrue);

      await send('second');
      expect(
        identical(routerA.sessionStreams.values.single, firstStream),
        isFalse,
        reason: 'A dead session stream must be replaced on the next send',
      );
      expect(
        await received.future.timeout(const Duration(seconds: 5)),
        'first',
      );
    }, timeout: Timeout(Duration(seconds: 60)));

    test(
      'non-session protocols still enforce the inbound idle timeout',
      () async {
        final priorIdle = Libp2pRouter.inboundReadIdleTimeout;
        Libp2pRouter.inboundReadIdleTimeout = const Duration(milliseconds: 150);
        addTearDown(() => Libp2pRouter.inboundReadIdleTimeout = priorIdle);

        await routerB.start();
        final addrB = getLocalConnectAddress(routerB);

        final received = <String>[];
        routerB.registerProtocolHandler('/test/idle/1.0.0', (packet) {
          received.add(utf8.decode(packet.datagram));
        });

        // A raw client keeps a request/response-class stream open but silent;
        // the inbound bounds must still reap it.
        final keyPair = await crypto.generateEd25519KeyPair();
        final host = await config.Libp2p.new_([
          config.Libp2p.transport(
            TCPTransport(
              resourceManager: ResourceManagerImpl(limiter: FixedLimiter()),
            ),
          ),
          config.Libp2p.listenAddrs([libp2p.MultiAddr('/ip4/0.0.0.0/tcp/0')]),
          config.Libp2p.identity(keyPair),
        ]);
        await host.start();

        try {
          final maddr = libp2p.MultiAddr(addrB);
          final peerId = libp2p.PeerId.fromString(addrB.split('/p2p/').last);
          await host.peerStore.addrBook.addAddrs(peerId, [
            maddr,
          ], const Duration(minutes: 5));
          await host.connect(libp2p.AddrInfo(peerId, [maddr]));

          final stream = await host.newStream(peerId, [
            '/test/idle/1.0.0',
          ], libp2p.Context());

          Uint8List frame(String text) {
            final body = utf8.encode(text);
            return Uint8List.fromList([body.length, ...body]);
          }

          await stream.write(frame('first'));
          await Future.delayed(const Duration(milliseconds: 300));
          expect(received, equals(['first']));

          // Past the idle bound the router must have closed the stream:
          // a further write is lost, and the read side reports EOF.
          await stream.write(frame('second')).catchError((_) => Uint8List(0));
          await Future.delayed(const Duration(milliseconds: 400));
          expect(received, equals(['first']));
        } finally {
          await host.close();
        }
      },
      timeout: Timeout(Duration(seconds: 60)),
    );
  });

  group('Libp2pRouter request/response and session internals', () {
    late Libp2pRouter routerA;
    late Libp2pRouter routerB;

    setUp(() async {
      final dir = Directory.systemTemp.createTempSync('ipfs_router_cov_');
      routerA = Libp2pRouter(
        IPFSConfig(
          dataPath: '${dir.path}/a',
          network: NetworkConfig(
            listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
            bootstrapPeers: [],
          ),
        ),
      );
      routerB = Libp2pRouter(
        IPFSConfig(
          dataPath: '${dir.path}/b',
          network: NetworkConfig(
            listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
            bootstrapPeers: [],
          ),
        ),
      );
      await routerA.initialize();
      await routerB.initialize();
    });

    tearDown(() async {
      if (routerA.hasStarted) await routerA.stop();
      if (routerB.hasStarted) await routerB.stop();
    });

    String connectAddress(Libp2pRouter router) {
      var addr = router.listeningAddresses.firstWhere(
        (a) => a.contains('/tcp/') && a.contains('127.0.0.1'),
        orElse: () => router.listeningAddresses.first,
      );
      return '$addr/p2p/${router.peerID}';
    }

    /// Reads a private field on [instance] via mirrors — used to seed
    /// bounded/session internals that cannot be reached through the public
    /// API deterministically.
    T privateField<T>(Object instance, String name) {
      final instanceMirror = mirrors.reflect(instance);
      final library = instanceMirror.type.owner! as mirrors.LibraryMirror;
      return instanceMirror
              .getField(mirrors.MirrorSystem.getSymbol(name, library))
              .reflectee
          as T;
    }

    test(
      'listeningAddresses expands wildcard listeners to concrete addrs',
      () async {
        // A 0.0.0.0 listener must advertise resolved interface addresses —
        // identify and the RPC surface depend on dialable addrs.
        final dir = Directory.systemTemp.createTempSync('ipfs_wildcard_');
        final wildcard = Libp2pRouter(
          IPFSConfig(
            dataPath: '${dir.path}/node',
            network: NetworkConfig(
              listenAddresses: ['/ip4/0.0.0.0/tcp/0'],
              bootstrapPeers: [],
            ),
          ),
        );
        addTearDown(() async {
          if (wildcard.hasStarted) await wildcard.stop();
        });
        await wildcard.initialize();
        await wildcard.start();

        final addrs = wildcard.listeningAddresses;
        expect(addrs, isNotEmpty);
        expect(
          addrs.every((a) => !a.contains('/ip4/0.0.0.0/')),
          isTrue,
          reason: 'Wildcard listeners must resolve to concrete interfaces',
        );
      },
      timeout: Timeout(Duration(seconds: 60)),
    );

    test('sendRequest returns null when the peer lacks the protocol', () async {
      await routerA.start();
      await routerB.start();
      await routerA.connect(connectAddress(routerB));
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await routerA.sendRequest(
        routerB.peerID,
        '/definitely/not-registered/1.0.0',
        Uint8List.fromList(utf8.encode('ping')),
      );
      expect(result, isNull);
    }, timeout: Timeout(Duration(seconds: 60)));

    test('sendMessageWithResponse round-trips a framed reply', () async {
      await routerA.start();
      await routerB.start();
      routerB.registerProtocolHandler('/test/echo/1.0.0', (packet) async {
        await packet.responder?.call(
          Uint8List.fromList(
            utf8.encode('echo:${utf8.decode(packet.datagram)}'),
          ),
        );
      });
      await routerA.connect(connectAddress(routerB));
      await Future.delayed(const Duration(milliseconds: 500));

      final reply = await routerA.sendMessageWithResponse(
        routerB.peerID,
        Uint8List.fromList(utf8.encode('hello')),
        protocolId: '/test/echo/1.0.0',
      );
      expect(utf8.decode(reply), 'echo:hello');
    }, timeout: Timeout(Duration(seconds: 60)));

    test('a failed session write drops the stream and retries', () async {
      await routerA.start();
      await routerB.start();
      await routerA.connect(connectAddress(routerB));
      await Future.delayed(const Duration(milliseconds: 500));

      final received = Completer<String>();
      routerB.registerProtocolHandler('/meshsub/1.1.0', (packet) {
        if (!received.isCompleted) {
          received.complete(utf8.decode(packet.datagram));
        }
      });

      // Seed a poisoned session stream: reports open but throws on write,
      // so the write path must drop it and reopen.
      final key = '${routerB.peerID}|/meshsub/1.1.0';
      final streams = privateField<Map<String, libp2p.P2PStream<dynamic>>>(
        routerA,
        '_sessionStreams',
      );
      final poisoned = _WriteFailingStream();
      streams[key] = poisoned;

      await routerA.sendMessage(
        routerB.peerID,
        Uint8List.fromList(utf8.encode('recovered')),
        protocolId: '/meshsub/1.1.0',
      );

      expect(
        await received.future.timeout(const Duration(seconds: 10)),
        'recovered',
      );
      expect(poisoned.closed, isTrue);
      expect(
        identical(routerA.sessionStreams[key], poisoned),
        isFalse,
        reason: 'The failed stream must be replaced, not reused',
      );
    }, timeout: Timeout(Duration(seconds: 60)));

    test('session sends past the queue cap are dropped', () async {
      await routerA.start();
      await routerB.start();
      await routerA.connect(connectAddress(routerB));
      await Future.delayed(const Duration(milliseconds: 500));

      var received = 0;
      routerB.registerProtocolHandler('/meshsub/1.1.0', (_) => received++);

      // Simulate a saturated queue slot (cap is 64 pending sends).
      final key = '${routerB.peerID}|/meshsub/1.1.0';
      privateField<Map<String, int>>(routerA, '_sessionStreamQueueDepth')[key] =
          64;

      await routerA.sendMessage(
        routerB.peerID,
        Uint8List.fromList(utf8.encode('dropped')),
        protocolId: '/meshsub/1.1.0',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, 0);
    }, timeout: Timeout(Duration(seconds: 60)));
  });
}

/// A session stream that reports open but fails every write — used to
/// exercise the write-failure drop-and-reopen path.
class _WriteFailingStream implements libp2p.P2PStream<dynamic> {
  var closed = false;

  @override
  bool get isClosed => closed;

  @override
  Future<void> write(Uint8List data) async =>
      throw StateError('injected write failure');

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
