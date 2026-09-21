@Tags(['p0'])
library;

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

/// Blocking (P0) connection-level interop: mutual `swarm/peers` visibility,
/// go-libp2p ping against dart_ipfs's `/ipfs/ping/1.0.0` responder, and the
/// identify record Kubo holds for dart_ipfs.
///
/// The ping test guards the raw 32-byte echo protocol: dart_ipfs previously
/// routed ping through length-prefixed dispatch and never answered, which is
/// fatal against js-libp2p's connection monitor (it aborts the connection —
/// and every pubsub stream on it — ~5s after a failed ping).
void main() {
  final dartIpfs = DartIpfsClient(host: 'dart_ipfs', port: 5001);
  final kubo = KuboClient(host: 'kubo', port: 5001);

  group('Connection-level interop with Kubo', () {
    test('swarm/peers lists each node on the other', () async {
      final dartPeerId = (await dartIpfs.id())['ID'] as String;
      final kuboPeerId = (await kubo.id())['ID'] as String;

      final dartPeers = await dartIpfs.swarmPeers();
      final kuboPeers = await kubo.swarmPeers();

      expect(
        dartPeers.map((p) => p['Peer']),
        contains(kuboPeerId),
        reason: 'dart_ipfs should report Kubo as a connected peer',
      );
      expect(
        kuboPeers.map((p) => p['Peer']),
        contains(dartPeerId),
        reason: 'Kubo should report dart_ipfs as a connected peer',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Kubo can ping dart_ipfs (raw ping echo)', () async {
      final dartPeerId = (await dartIpfs.id())['ID'] as String;

      final rttNanos = await kubo.pingPeer(dartPeerId);
      expect(rttNanos, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 45)));

    test("Kubo's identify record for dart_ipfs advertises meshsub", () async {
      final dartPeerId = (await dartIpfs.id())['ID'] as String;

      final record = await kubo.idOf(dartPeerId);
      expect(record['ID'], equals(dartPeerId));

      final protocols = [
        for (final p in record['Protocols'] as List? ?? const []) '$p',
      ];
      expect(
        protocols,
        anyElement((String p) => p.startsWith('/meshsub/')),
        reason:
            'dart_ipfs identify should advertise a meshsub protocol; '
            'got $protocols',
      );
      expect(record['AgentVersion'], isA<String>());
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
