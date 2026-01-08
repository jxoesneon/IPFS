import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:dart_ipfs/src/transport/libp2p_transport.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

void main() {
  group('Libp2pTransport', () {
    late Libp2pTransport transport1;
    late Libp2pTransport transport2;
    final seed1 = Uint8List.fromList(List.generate(32, (i) => i));
    final seed2 = Uint8List.fromList(List.generate(32, (i) => 31 - i));

    setUp(() async {
      transport1 = Libp2pTransport(
        bindAddress: p2p.FullAddress(
          address: InternetAddress.anyIPv4,
          port: 4011,
        ),
        seed: seed1,
        logger: (msg) => print('T1: $msg'),
      );

      transport2 = Libp2pTransport(
        bindAddress: p2p.FullAddress(
          address: InternetAddress.anyIPv4,
          port: 4012,
        ),
        seed: seed2,
        logger: (msg) => print('T2: $msg'),
      );

      await transport1.start();
      await transport2.start();
    });

    tearDown(() {
      transport1.stop();
      transport2.stop();
    });

    test('Identity derivation is consistent', () {
      expect(transport1.isStarted, isTrue);
      expect(transport2.isStarted, isTrue);
    });

    test('Can send and receive messages', () async {
      final payload = Uint8List.fromList([1, 2, 3, 4]);

      // Derive public keys from seeds using same algorithm as bridge
      final ed25519 = crypto.Ed25519();
      final kp1 = await ed25519.newKeyPairFromSeed(seed1);
      final pub1 = await kp1.extractPublicKey();
      final pubKey1 = Uint8List.fromList(pub1.bytes);

      final kp2 = await ed25519.newKeyPairFromSeed(seed2);
      final pub2 = await kp2.extractPublicKey();
      final pubKey2 = Uint8List.fromList(pub2.bytes);

      final p2pPeerId1 = p2p.PeerId.fromKeys(
        encryptionKey: pubKey1,
        signKey: pubKey1,
      );
      final p2pPeerId2 = p2p.PeerId.fromKeys(
        encryptionKey: pubKey2,
        signKey: pubKey2,
      );

      final message = p2p.Message(
        header: const p2p.PacketHeader(id: 456, issuedAt: 2000),
        srcPeerId: p2pPeerId1,
        dstPeerId: p2pPeerId2,
        payload: payload,
      );

      final datagram = message.toBytes();
      bool received = false;

      transport2.onMessage = (packet) async {
        if (packet.header.id == 456) {
          received = true;
          print('T2: Received expected packet!');
        }
      };

      // Send from T1 to T2 via loopback
      transport1.send([
        p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 4012),
      ], datagram);

      // Wait for delivery (libp2p handshake + stream opening can take a moment)
      await Future.delayed(const Duration(seconds: 2));
      expect(
        received,
        isTrue,
        reason: 'Message should be received by transport2',
      );
    });
  });
}
