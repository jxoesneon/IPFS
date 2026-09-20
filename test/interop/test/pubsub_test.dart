@Tags(['helia'])
library;

import 'dart:convert';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/helia_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

/// Real-implementation pubsub interop: dart_ipfs speaks the gossipsub wire
/// protocol (/meshsub/1.1.0) with Kubo (go-libp2p-pubsub) and Helia
/// (js-libp2p-gossipsub). Each direction is exercised: subscribe on one
/// side, publish on the other, assert the payload arrives.
void main() {
  final dartIpfs = DartIpfsClient(host: 'dart_ipfs', port: 5001);
  final kubo = KuboClient(host: 'kubo', port: 5001);
  final helia = HeliaClient(host: 'helia', port: 5001);

  // Subscription announcements and mesh formation need a few seconds after
  // subscribe before publishes reliably reach the remote peer.
  const settle = Duration(seconds: 8);
  const delivery = Duration(seconds: 60);

  group('PubSub/gossipsub wire interop', () {
    test('dart_ipfs publishes, Helia receives', () async {
      const topic = 'interop-dart-to-helia';
      const payload = 'hello from dart_ipfs';

      await helia.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);
      await dartIpfs.pubsubPublish(topic, utf8.encode(payload));

      final message = await helia.pubsubWaitFor(
        topic,
        expected: payload,
        timeout: delivery,
      );
      expect(message.text, equals(payload));
      expect(message.from, isNotEmpty);
      await helia.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Helia publishes, dart_ipfs receives', () async {
      const topic = 'interop-helia-to-dart';
      const payload = 'hello from helia';

      await dartIpfs.pubsubSubscribe(topic);
      await Future<void>.delayed(settle);
      await helia.pubsubPublish(topic, utf8.encode(payload));

      final message = await dartIpfs.pubsubWaitFor(
        topic,
        expected: payload,
        timeout: delivery,
      );
      expect(message.text, equals(payload));
      expect(message.from, isNotEmpty);
      await dartIpfs.pubsubUnsubscribe(topic);
    }, timeout: const Timeout(Duration(minutes: 2)));

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

    test('pubsub/ls reflects subscriptions on all three nodes', () async {
      const topic = 'interop-ls-check';
      await dartIpfs.pubsubSubscribe(topic);
      await kubo.pubsubSubscribe(topic);
      await helia.pubsubSubscribe(topic);

      expect(await dartIpfs.pubsubLs(), contains(topic));
      expect(await kubo.pubsubLs(), contains(topic));
      expect(await helia.pubsubLs(), contains(topic));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
