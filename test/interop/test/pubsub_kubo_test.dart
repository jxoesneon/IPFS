@Tags(['p0'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

/// Blocking (P0) dart_ipfs<->Kubo gossipsub interop: both publish directions,
/// a binary payload, and `pubsub/peers` visibility. These run in the
/// release-blocking interop job — regressions in the gossipsub wire path
/// (framing, signing, session streams, response streaming) must not wait for
/// the nightly Helia run to surface.
void main() {
  final dartIpfs = DartIpfsClient(host: 'dart_ipfs', port: 5001);
  final kubo = KuboClient(host: 'kubo', port: 5001);

  // Subscription announcements and mesh formation need a few seconds after
  // subscribe before publishes reliably reach the remote peer.
  const settle = Duration(seconds: 8);
  const delivery = Duration(seconds: 60);

  group('PubSub/gossipsub wire interop (Kubo)', () {
    test('dart_ipfs publishes, Kubo receives', () async {
      const topic = 'interop-dart-to-kubo';
      const payload = 'hello kubo from dart_ipfs';

      await kubo.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);
      await dartIpfs.pubsubPublish(topic, utf8.encode(payload));

      final message = await kubo.pubsubWaitFor(
        topic,
        expected: payload,
        timeout: delivery,
      );
      expect(message.text, equals(payload));
      await kubo.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Kubo publishes, dart_ipfs receives', () async {
      const topic = 'interop-kubo-to-dart';
      const payload = 'hello dart_ipfs from kubo';

      await dartIpfs.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);
      await kubo.pubsubPublish(topic, utf8.encode(payload));

      final message = await dartIpfs.pubsubWaitFor(
        topic,
        expected: payload,
        timeout: delivery,
      );
      expect(message.text, equals(payload));
      await dartIpfs.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('dart_ipfs publishes a binary payload, Kubo receives it', () async {
      const topic = 'interop-dart-to-kubo-binary';
      final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));

      await kubo.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);
      await dartIpfs.pubsubPublish(topic, payload);

      final message = await kubo.pubsubWaitFor(topic, timeout: delivery);
      expect(message.data, equals(payload));
      await kubo.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('pubsub/peers shows each node subscribed on the other', () async {
      const topic = 'interop-peers-check';
      await dartIpfs.pubsubSubscribe(topic);
      await kubo.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);

      final dartPeerId = (await dartIpfs.id())['ID'] as String;
      final kuboPeerId = (await kubo.id())['ID'] as String;

      // Subscription announcements propagate through gossipsub's peer
      // tracking asynchronously — poll both directions rather than
      // asserting a single snapshot.
      List<String> dartPeers = const [];
      List<String> kuboPeers = const [];
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(deadline) &&
          !(dartPeers.contains(kuboPeerId) && kuboPeers.contains(dartPeerId))) {
        dartPeers = await dartIpfs.pubsubPeers(topic);
        kuboPeers = await kubo.pubsubPeers(topic);
        if (!(dartPeers.contains(kuboPeerId) &&
            kuboPeers.contains(dartPeerId))) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      expect(
        dartPeers,
        contains(kuboPeerId),
        reason: 'dart_ipfs should see Kubo subscribed to $topic',
      );
      expect(
        kuboPeers,
        contains(dartPeerId),
        reason: 'Kubo should see dart_ipfs subscribed to $topic',
      );

      await dartIpfs.pubsubUnsubscribe(topic);
      await kubo.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
