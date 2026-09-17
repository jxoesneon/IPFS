import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/core/ipfs_node/protocol_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

/// Minimal [RouterInterface] stub for PubSub introspection tests.
///
/// Only the members used by [PubSubClient] are implemented; every other
/// member falls through to [noSuchMethod].
class _StubRouter implements RouterInterface {
  /// The handler [PubSubClient.start] registered for the `pubsub` protocol.
  void Function(NetworkPacket)? pubsubPacketHandler;

  /// Peer IDs reported as connected by [isConnectedPeer].
  final Set<String> connected = <String>{};

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    if (protocolId == 'pubsub') {
      pubsubPacketHandler = handler;
    }
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  void removeMessageHandler(String protocolId) {}

  @override
  bool isConnectedPeer(String peerIdStr) => connected.contains(peerIdStr);

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _deliverJson(_StubRouter router, Map<String, Object?> message) {
  router.pubsubPacketHandler!(
    NetworkPacket(
      srcPeerId: (message['sender'] as String?) ?? 'QmSender',
      datagram: Uint8List.fromList(utf8.encode(jsonEncode(message))),
    ),
  );
}

void _deliverRaw(_StubRouter router, String srcPeerId, Uint8List datagram) {
  router.pubsubPacketHandler!(
    NetworkPacket(srcPeerId: srcPeerId, datagram: datagram),
  );
}

void main() {
  const peerId = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

  late _StubRouter router;
  late PubSubClient client;

  setUp(() {
    router = _StubRouter();
    client = PubSubClient(router, peerId);
  });

  tearDown(() async {
    await client.stop();
  });

  group('PubSubClient introspection', () {
    test('subscribedTopics is initially empty', () {
      expect(client.subscribedTopics, isEmpty);
    });

    test('subscribedTopics reflects subscribe and unsubscribe', () async {
      await client.subscribe('topic-a');
      await client.subscribe('topic-b');
      expect(
        client.subscribedTopics,
        containsAll(<String>['topic-a', 'topic-b']),
      );

      await client.unsubscribe('topic-a');
      expect(client.subscribedTopics, equals(<String>['topic-b']));
    });

    test('subscribedTopics returns an unmodifiable snapshot', () async {
      await client.subscribe('topic-a');

      final List<String> snapshot = client.subscribedTopics;
      expect(() => snapshot.add('topic-x'), throwsUnsupportedError);

      await client.subscribe('topic-b');
      expect(snapshot, equals(<String>['topic-a']));
    });

    test('peersForTopic falls back to the mesh without topic data', () {
      client.graftPeer('mesh-peer');
      expect(client.peersForTopic('unknown-topic'), contains('mesh-peer'));
    });

    test('graft control message with topic records a topic peer', () async {
      await client.start();
      _deliverJson(router, {
        'action': 'graft',
        'sender': 'peer-1',
        'topic': 't1',
      });

      expect(client.peersForTopic('t1'), contains('peer-1'));
    });

    test('subscribe announcements record topic peers', () async {
      await client.start();

      // JSON control action form.
      _deliverJson(router, {
        'action': 'subscribe',
        'sender': 'peer-1',
        'topic': 't1',
      });
      // Plain-text form produced by encodeSubscribeRequest.
      _deliverRaw(router, 'peer-2', client.encodeSubscribeRequest('t1'));

      expect(
        client.peersForTopic('t1'),
        containsAll(<String>['peer-1', 'peer-2']),
      );
    });

    test('unsubscribe announcements remove topic peers', () async {
      await client.start();

      _deliverJson(router, {
        'action': 'subscribe',
        'sender': 'peer-1',
        'topic': 't1',
      });
      _deliverRaw(router, 'peer-2', client.encodeSubscribeRequest('t1'));

      // JSON control action form.
      _deliverJson(router, {
        'action': 'unsubscribe',
        'sender': 'peer-1',
        'topic': 't1',
      });
      // Plain-text form produced by encodeUnsubscribeRequest.
      _deliverRaw(router, 'peer-2', client.encodeUnsubscribeRequest('t1'));

      expect(client.peersForTopic('t1'), isEmpty);
    });

    test('prune control message with topic removes a topic peer', () async {
      await client.start();

      _deliverJson(router, {
        'action': 'graft',
        'sender': 'peer-1',
        'topic': 't1',
      });
      _deliverJson(router, {
        'action': 'prune',
        'sender': 'peer-1',
        'topic': 't1',
      });

      expect(client.peersForTopic('t1'), isEmpty);
    });

    test('peersForTopic does not fall back once topic data exists', () async {
      await client.start();
      client.graftPeer('mesh-only'); // mesh member with no topic info

      _deliverJson(router, {
        'action': 'graft',
        'sender': 'peer-1',
        'topic': 't1',
      });
      _deliverJson(router, {
        'action': 'prune',
        'sender': 'peer-1',
        'topic': 't1',
      });

      // 't1' has recorded (now empty) per-topic data: no mesh fallback.
      expect(client.peersForTopic('t1'), isEmpty);
      // 'other' has no recorded data: falls back to the mesh.
      expect(client.peersForTopic('other'), contains('mesh-only'));
    });
  });

  group('ProtocolManager pubsub introspection', () {
    test('returns empty lists when pubsub is disabled', () async {
      final manager = ProtocolManager();

      expect(manager.pubsubLs(), isEmpty);
      expect(await manager.pubsubPeers('t1'), isEmpty);
    });

    test('delegates to the pubsub handler when enabled', () async {
      final handler = PubSubHandler(
        router,
        peerId,
        IpfsNodeNetworkEvents(router),
      );
      final manager = ProtocolManager(pubSubHandler: handler);

      await handler.subscribe('t1');
      expect(manager.pubsubLs(), contains('t1'));

      await handler.start();
      _deliverJson(router, {
        'action': 'graft',
        'sender': 'peer-1',
        'topic': 't1',
      });

      expect(await manager.pubsubPeers('t1'), contains('peer-1'));
      // 't2' has no per-topic data: falls back to the global mesh.
      expect(await manager.pubsubPeers('t2'), contains('peer-1'));

      await handler.stop();
    });
  });
}
