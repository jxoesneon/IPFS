import 'dart:io';

import 'package:p2plib/p2plib.dart';
import 'package:test/test.dart';

import '../mock.dart';

void main() {
  group('DHT Security', () {
    late RouterL2 router;

    setUp(() async {
      router = RouterL2(
        crypto: MockCrypto(),
        transports: [
          TransportUdp(
            bindAddress: FullAddress(
              address: InternetAddress.loopbackIPv4,
              port: 4000,
            ),
          ),
        ],
      );
      // We don't call router.init() if MockCrypto handles keys
      // or we do if MockCrypto.init works.
      // Router base init calls crypto.init.
      await router.init();
      await router.start();
    });

    tearDown(() {
      router.stop();
    });

    test('Sybil Attack Protection: Limits peers per IP', () async {
      // Configuration
      const maxPeersPerIp = 5; // Expected limit
      const numAttackers = 20;
      final attackerIp = InternetAddress('192.168.1.100');
      const attackerPort = 5000;

      // Simulate flooding
      var acceptedPeers = 0;
      for (var i = 0; i < numAttackers; i++) {
        // Generate random PeerId
        final attackerId = PeerId(value: getRandomBytes(PeerId.length));

        try {
          // Direct attack on routing table
          router.addPeerAddress(
            peerId: attackerId,
            address: FullAddress(address: attackerIp, port: attackerPort + i),
            properties: AddressProperties(),
            canForward: false,
          );

          if (router.routes.containsKey(attackerId)) {
            acceptedPeers++;
          }
        } on Object {
          // Ignore
        }
      }

      // Initial Expectation: FAILS (Accepts all 20)
      // Goal: acceptedPeers <= maxPeersPerIp
      // print('Accepted Peers: $acceptedPeers / $numAttackers');

      // If code is vulnerable, it accepts all.
      // We want to assert that it is SECURE.
      // So this test will FAIL until we fix it.
      expect(
        acceptedPeers,
        lessThanOrEqualTo(maxPeersPerIp),
        reason: 'Should limit peers from same IP',
      );
    });
  });
}

class MockCrypto implements Crypto {
  @override
  Future<({Uint8List encPubKey, Uint8List seed, Uint8List signPubKey})> init([
    Uint8List? seed,
  ]) async {
    return (
      encPubKey: Uint8List(32),
      signPubKey: Uint8List(32),
      seed: seed ?? Uint8List(32),
    );
  }

  @override
  Future<Uint8List> seal(Uint8List datagram) async => datagram;

  @override
  Future<Uint8List> unseal(Uint8List datagram) async => datagram;

  @override
  Future<Uint8List> verify(Uint8List datagram) async => datagram;
}
