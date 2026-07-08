import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/gossipsub.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

class _FakeRouter implements RouterInterface {
  final Set<String> _peers = {};
  final Map<String, void Function(NetworkPacket)> _handlers = {};
  final _connectionEvents = StreamController<ConnectionEvent>.broadcast();
  final _messageEvents = StreamController<MessageEvent>.broadcast();
  final _sentMessages = <_SentMessage>[];

  @override
  String get peerID => 'localPeer';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => Set<String>.from(_peers);

  @override
  Stream<ConnectionEvent> get connectionEvents => _connectionEvents.stream;

  @override
  Stream<MessageEvent> get messageEvents => _messageEvents.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {
    final peerId = multiaddress.split('/p2p/').last;
    _peers.add(peerId);
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}

  @override
  List<String> get listeningAddresses => [];

  @override
  List<String> listConnectedPeers() => _peers.toList();

  @override
  bool isConnectedPeer(String peerIdStr) => _peers.contains(peerIdStr);

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    _sentMessages.add(_SentMessage(peerIdStr, message, protocolId));
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  Stream<Uint8List> receiveMessages(String peerId) =>
      const Stream<Uint8List>.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handlers.remove(protocolId);
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {
    for (final peer in _peers) {
      await sendMessage(peer, message, protocolId: protocolId);
    }
  }

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(dynamic) handler) {}

  @override
  void offEvent(String topic, void Function(dynamic) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  void addPeer(String peerId) {
    _peers.add(peerId);
    _connectionEvents.add(
      ConnectionEvent(peerId: peerId, type: ConnectionEventType.connected),
    );
  }

  void removePeer(String peerId) {
    _peers.remove(peerId);
    _connectionEvents.add(
      ConnectionEvent(peerId: peerId, type: ConnectionEventType.disconnected),
    );
  }

  void deliverMessage(String peerId, Uint8List datagram, {String? protocolId}) {
    final handler = _handlers[protocolId ?? '/meshsub/1.1.0'];
    if (handler != null) {
      handler(NetworkPacket(srcPeerId: peerId, datagram: datagram));
    }
  }

  List<_SentMessage> takeMessages() {
    final result = List<_SentMessage>.from(_sentMessages);
    _sentMessages.clear();
    return result;
  }

  void dispose() {
    _connectionEvents.close();
    _messageEvents.close();
  }
}

class _SentMessage {
  _SentMessage(this.peerId, this.bytes, this.protocolId);

  final String peerId;
  final Uint8List bytes;
  final String? protocolId;
}

Future<GossipsubHandler> _createHandler(_FakeRouter router) async {
  final keyPair = await Ed25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final signer = Ed25519MessageSigner(keyPair);
  // Use a simple 32-byte peer id derived from the public key.
  final peerId = Uint8List.fromList(publicKey.bytes);
  return GossipsubHandler(router: router, signer: signer, peerId: peerId);
}

void main() {
  late _FakeRouter router;

  setUp(() {
    router = _FakeRouter();
  });

  tearDown(() {
    router.dispose();
  });

  group('protobuf', () {
    test('RPC round-trip', () {
      final rpc = RPC()
        ..subscriptions.add(Subscription(subscribe: true, topicid: 't1'))
        ..publish.add(
          Message(
            from: Uint8List.fromList([1, 2, 3]),
            data: Uint8List.fromList([4, 5, 6]),
            seqno: Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1]),
            topic: 't1',
          ),
        )
        ..control = (ControlMessage()
          ..ihave.add(ControlIHave(topicID: 't1', messageIDs: ['m1']))
          ..iwant.add(ControlIWant(messageIDs: ['m1']))
          ..graft.add(ControlGraft(topicID: 't1'))
          ..prune.add(ControlPrune(topicID: 't1')));

      final decoded = RPC.fromBuffer(rpc.writeToBuffer());
      expect(decoded.subscriptions.length, equals(1));
      expect(decoded.subscriptions.first.topicid, equals('t1'));
      expect(decoded.publish.length, equals(1));
      expect(decoded.publish.first.topic, equals('t1'));
      expect(decoded.control.ihave.length, equals(1));
      expect(decoded.control.iwant.length, equals(1));
      expect(decoded.control.graft.length, equals(1));
      expect(decoded.control.prune.length, equals(1));
    });
  });

  group('message signing', () {
    test('sign and verify with Ed25519', () async {
      final keyPair = await Ed25519().newKeyPair();
      final signer = Ed25519MessageSigner(keyPair);
      final publicKey = await signer.publicKey;

      final message = Message()
        ..from = Uint8List.fromList([1, 2, 3])
        ..data = Uint8List.fromList([4, 5, 6])
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..topic = 'test-topic';

      message.signature = await signer.signMessage(message);
      expect(message.signature, isNotEmpty);

      final valid = await signer.verifyMessage(message, publicKey);
      expect(valid, isTrue);
    });

    test('verification fails with wrong public key', () async {
      final keyPair = await Ed25519().newKeyPair();
      final signer = Ed25519MessageSigner(keyPair);
      final otherKeyPair = await Ed25519().newKeyPair();
      final otherPublicKey = await otherKeyPair.extractPublicKey();

      final message = Message()
        ..from = Uint8List.fromList([1, 2, 3])
        ..data = Uint8List.fromList([4, 5, 6])
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..topic = 'test-topic';

      message.signature = await signer.signMessage(message);
      final valid = await signer.verifyMessage(
        message,
        Uint8List.fromList(otherPublicKey.bytes),
      );
      expect(valid, isFalse);
    });
  });

  group('MessageCache', () {
    late MessageCache cache;

    setUp(() {
      cache = MessageCache(capacity: 3);
    });

    Message makeMessage(String topic, List<int> data, int seqno) {
      return Message()
        ..from = Uint8List.fromList([1])
        ..data = Uint8List.fromList(data)
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, seqno])
        ..topic = topic;
    }

    test('adds and deduplicates messages', () {
      final m1 = makeMessage('t1', [1], 1);
      final m2 = makeMessage('t1', [2], 2);
      final m1Dup = makeMessage('t1', [1], 1);

      cache.add(m1);
      cache.add(m2);
      cache.add(m1Dup);

      expect(cache.messageIdsForTopic('t1').length, equals(2));
      expect(cache.contains(m1), isTrue);
      expect(cache.contains(m2), isTrue);
    });

    test('evicts oldest messages when capacity exceeded', () {
      cache.add(makeMessage('t1', [1], 1));
      cache.add(makeMessage('t1', [2], 2));
      cache.add(makeMessage('t1', [3], 3));
      cache.add(makeMessage('t1', [4], 4));

      expect(cache.messageIdsForTopic('t1').length, equals(3));
      expect(cache.contains(makeMessage('t1', [1], 1)), isFalse);
      expect(cache.contains(makeMessage('t1', [4], 4)), isTrue);
    });

    test('serves messages for IWANT', () {
      final m1 = makeMessage('t1', [1], 1);
      final m2 = makeMessage('t1', [2], 2);
      cache.add(m1);
      cache.add(m2);

      final id1 = MessageCache.messageId(m1);
      final result = cache.getForIWant('t1', [id1]);
      expect(result.length, equals(1));
      expect(result.first.data, equals(Uint8List.fromList([1])));
    });
  });

  group('PeerScore', () {
    test('increases on first delivery and penalizes invalid', () {
      final params = {
        't1': const TopicScoreParams(
          meshMessageDeliveriesThreshold: 0.0,
          meshFailurePenaltyWeight: 0.0,
        ),
      };
      final table = PeerScoreTable(topicParams: params);
      final score = table.scoreFor('peer1');

      score.addFirstMessageDelivery('t1');
      expect(table.score('peer1'), greaterThan(0.0));

      score.addInvalidMessageDelivery('t1');
      expect(table.score('peer1'), lessThan(0.0));
    });

    test('score caps topic contributions', () {
      final params = {'t1': const TopicScoreParams(topicScoreCap: 10.0)};
      final table = PeerScoreTable(topicParams: params);
      final score = table.scoreFor('peer1');

      for (var i = 0; i < 100; i++) {
        score.addFirstMessageDelivery('t1');
      }
      expect(table.score('peer1'), lessThanOrEqualTo(10.0));
    });
  });

  group('GossipsubHandler lifecycle', () {
    test('start and stop', () async {
      final handler = await _createHandler(router);
      await handler.start();
      expect(handler.isStarted, isTrue);
      await handler.stop();
      expect(handler.isStarted, isFalse);
    });

    test('subscribe sends SUBSCRIBE RPC', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');

      final messages = router.takeMessages();
      expect(messages.length, equals(1));
      final decoded = RPC.fromBuffer(messages.first.bytes);
      expect(decoded.subscriptions.length, equals(1));
      expect(decoded.subscriptions.first.subscribe, isTrue);
      expect(decoded.subscriptions.first.topicid, equals('topic1'));
      await handler.stop();
    });

    test('publish signs and sends message', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');
      router.takeMessages(); // clear subscription

      await handler.publish('topic1', Uint8List.fromList([1, 2, 3]));

      final messages = router.takeMessages();
      expect(messages.length, greaterThan(0));
      final decoded = RPC.fromBuffer(messages.first.bytes);
      expect(decoded.publish.length, equals(1));
      final msg = decoded.publish.first;
      expect(msg.topic, equals('topic1'));
      expect(msg.data, equals(Uint8List.fromList([1, 2, 3])));
      expect(msg.signature, isNotEmpty);

      await handler.stop();
    });

    test('onMessage receives published message', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');
      router.takeMessages(); // clear subscription

      final received = handler.onMessage('topic1').first;

      // Build a valid signed message from a peer.
      final peerKey = await Ed25519().newKeyPair();
      final peerSigner = Ed25519MessageSigner(peerKey);
      final peerPub = await peerKey.extractPublicKey();
      final peerId = Uint8List.fromList(peerPub.bytes);
      final message = Message()
        ..from = peerId
        ..data = Uint8List.fromList([1, 2, 3])
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..topic = 'topic1';
      message.signature = await peerSigner.signMessage(message);
      message.key = Uint8List.fromList(peerPub.bytes);

      final rpc = RPC()..publish.add(message);
      router.deliverMessage('peer1', rpc.writeToBuffer());

      final got = await received;
      expect(got.topic, equals('topic1'));
      expect(got.data, equals(Uint8List.fromList([1, 2, 3])));
      await handler.stop();
    });

    test('invalid signature is rejected and penalized', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');

      final message = Message()
        ..from = Uint8List.fromList([9, 9, 9])
        ..data = Uint8List.fromList([1, 2, 3])
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..topic = 'topic1'
        ..signature = Uint8List.fromList([0, 0, 0])
        ..key = Uint8List.fromList([0, 0, 0]);

      final rpc = RPC()..publish.add(message);
      router.deliverMessage('peer1', rpc.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(handler.getPeerScore('peer1').topicScore('topic1'), lessThan(0.0));
      await handler.stop();
    });
  });

  group('control messages', () {
    test('GRAFT adds peer to mesh', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');

      final rpc = RPC()
        ..control = (ControlMessage()
          ..graft.add(ControlGraft(topicID: 'topic1')));
      router.deliverMessage('peer1', rpc.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(handler.meshPeers('topic1'), contains('peer1'));
      await handler.stop();
    });

    test('PRUNE removes peer from mesh', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');

      // Graft first
      handler.meshPeers('topic1').add('peer1');

      final rpc = RPC()
        ..control = (ControlMessage()
          ..prune.add(ControlPrune(topicID: 'topic1')));
      router.deliverMessage('peer1', rpc.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(handler.meshPeers('topic1'), isNot(contains('peer1')));
      await handler.stop();
    });

    test('IHAVE triggers IWANT for unknown messages', () async {
      router.addPeer('peer1');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');
      router.takeMessages(); // clear subscription

      final rpc = RPC()
        ..control = (ControlMessage()
          ..ihave.add(
            ControlIHave(topicID: 'topic1', messageIDs: ['missing-id']),
          ));
      router.deliverMessage('peer1', rpc.writeToBuffer());

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final messages = router.takeMessages();
      expect(messages.length, equals(1));
      final decoded = RPC.fromBuffer(messages.first.bytes);
      expect(decoded.control.iwant.length, equals(1));
      expect(decoded.control.iwant.first.messageIDs, contains('missing-id'));
      await handler.stop();
    });

    test('IWANT serves cached messages', () async {
      router.addPeer('peer1');
      router.addPeer('peer2');
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');
      router.takeMessages(); // clear subscription

      await handler.publish('topic1', Uint8List.fromList([1, 2, 3]));
      final publishMessages = router.takeMessages();
      expect(publishMessages, isNotEmpty);
      final published = RPC
          .fromBuffer(publishMessages.first.bytes)
          .publish
          .first;
      final msgId = MessageCache.messageId(published);

      final rpc = RPC()
        ..control = (ControlMessage()
          ..iwant.add(ControlIWant(messageIDs: [msgId])));
      router.deliverMessage('peer2', rpc.writeToBuffer());

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final response = router
          .takeMessages()
          .where((m) => m.peerId == 'peer2')
          .toList();
      expect(response, isNotEmpty);
      final decoded = RPC.fromBuffer(response.first.bytes);
      expect(decoded.publish.length, equals(1));
      expect(decoded.publish.first.data, equals(Uint8List.fromList([1, 2, 3])));
      await handler.stop();
    });
  });

  group('heartbeat', () {
    test('mesh maintenance grafts new peers', () async {
      final handler = await _createHandler(router);
      await handler.start();
      await handler.subscribe('topic1');
      router.takeMessages();

      router.addPeer('peer1');
      // Announce peer1 is subscribed to topic1.
      final sub = RPC()
        ..subscriptions.add(Subscription(subscribe: true, topicid: 'topic1'));
      router.deliverMessage('peer1', sub.writeToBuffer());

      // Trigger heartbeat manually.
      handler.heartbeat();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(handler.meshPeers('topic1'), contains('peer1'));
      await handler.stop();
    });
  });
}
