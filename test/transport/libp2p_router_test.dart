import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

void main() {
  group('Libp2pRouter Integration', () {
    late Libp2pRouter routerA;
    late Libp2pRouter routerB;
    late IPFSConfig configA;
    late IPFSConfig configB;

    setUp(() async {
      // Config for Node A (Port 0 for dynamic assignment if supported, or explicit 4101)
      configA = IPFSConfig(
        network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/tcp/4101']),
      );

      // Config for Node B (Port 4102)
      configB = IPFSConfig(
        network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/tcp/4102']),
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
      expect(routerA.listeningAddresses, contains('/ip4/127.0.0.1/tcp/4101'));

      await routerA.stop();
      expect(routerA.hasStarted, isFalse);
    });

    test('should connect to another peer', () async {
      await routerA.start();
      await routerB.start();

      // Connect A -> B
      // Construct B's multiaddr with its PeerID
      final addrB = '/ip4/127.0.0.1/tcp/4102/p2p/${routerB.peerID}';

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

      final addrB = '/ip4/127.0.0.1/tcp/4102/p2p/${routerB.peerID}';
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
  });
}
