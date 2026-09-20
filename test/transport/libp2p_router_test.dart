import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
        await host.peerStore.addrBook.addAddrs(
          peerId,
          [maddr],
          const Duration(minutes: 5),
        );
        await host.connect(libp2p.AddrInfo(peerId, [maddr]));

        final stream =
            await host.newStream(peerId, ['/ipfs/id/1.0.0'], libp2p.Context());

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
  });
}
