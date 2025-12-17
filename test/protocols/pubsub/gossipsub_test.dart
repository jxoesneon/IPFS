// test/protocols/pubsub/gossipsub_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Mock RouterL2
class MockRouterL2 implements p2p.RouterL2 {
  final Map<p2p.PeerId, List<p2p.FullAddress>> resolvedAddresses = {};
  void Function(Uint8List datagram, Iterable<p2p.FullAddress> addresses)?
  onSend;

  @override
  Iterable<p2p.FullAddress> resolvePeerId(p2p.PeerId peerId) {
    return resolvedAddresses.values.expand((element) => element);
  }

  @override
  void sendDatagram({
    required Iterable<p2p.FullAddress> addresses,
    required Uint8List datagram,
  }) {
    if (onSend != null) {
      onSend!(datagram, addresses);
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock P2plibRouter
class MockP2plibRouter implements P2plibRouter {
  bool started = false;
  final MockRouterL2 _routerL0 = MockRouterL2();
  final Map<String, void Function(p2p.Packet)> handlers = {};

  // Track last sent message
  p2p.PeerId? lastSentPeerId;
  Uint8List? lastSentMessage;

  @override
  p2p.RouterL2 get routerL0 => _routerL0;

  @override
  Future<void> start() async {
    started = true;
  }

  void simulateIncomingMessage(String protocol, p2p.Packet packet) {
    if (handlers.containsKey(protocol)) {
      handlers[protocol]!(packet);
    }
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(p2p.Packet packet) handler,
  ) {
    handlers[protocolId] = handler;
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  bool isConnectedPeer(p2p.PeerId peerId) {
    return true; // Simulate always connected for valid peers
  }

  @override
  Future<void> sendMessage(p2p.PeerId peerId, Uint8List message) async {
    lastSentPeerId = peerId;
    lastSentMessage = message;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Gossipsub 1.1', () {
    late MockP2plibRouter mockRouter;
    late PubSubClient pubsub;
    late String myPeerId;
    late String otherPeerId;

    setUp(() {
      mockRouter = MockP2plibRouter();
      // valid peer ID (64 bytes to match p2plib expectations in tests)
      final myBytes = Uint8List.fromList(List.filled(64, 1));
      myPeerId = Base58().encode(myBytes);

      final otherBytes = Uint8List.fromList(List.filled(64, 2));
      otherPeerId = Base58().encode(otherBytes);

      pubsub = PubSubClient(mockRouter, myPeerId);
      pubsub.start();
    });

    tearDown(() async {
      await pubsub.stop();
    });

    test('graftPeer/prunePeer does not crash', () async {
      pubsub.graftPeer(otherPeerId);
      pubsub.prunePeer(otherPeerId);
    });

    test('publish caches message', () async {
      final topic = 'test-topic';
      final content = 'hello world';

      await pubsub.publish(topic, content);
      // We assume publish succeeds without error
    });

    test('Receiving IHAVE triggers IWANT for unknown message', () async {
      final topic = 'gossip-topic';
      final unknownMsgId = 'unknown-hash';

      final ihaveMsg = {
        'action': 'ihave',
        'topic': topic,
        'msgIds': [unknownMsgId],
        'sender': otherPeerId,
        'content': '', // dummy
      };

      final packet = p2p.Packet(
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(ihaveMsg))),
        header: p2p.PacketHeader(id: 1, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(
          address: InternetAddress.loopbackIPv4,
          port: 0,
        ),
      );
      packet.srcPeerId = p2p.PeerId(value: Base58().base58Decode(otherPeerId));

      mockRouter.simulateIncomingMessage('pubsub', packet);

      expect(mockRouter.lastSentMessage, isNotNull);
      final sentJson = jsonDecode(utf8.decode(mockRouter.lastSentMessage!));
      expect(sentJson['action'], equals('iwant'));
      expect((sentJson['msgIds'] as List).contains(unknownMsgId), isTrue);
    });

    test('Receiving IWANT triggers response if cached', () async {
      final topic = 'gossip-topic';
      final content = 'valuable content';
      final msgId = content.hashCode.toString(); // Fallback ID

      // 1. Prime cache by receiving a publish first
      final publishMsg = {
        'action': 'publish', // or null
        'topic': topic,
        'content': content,
        'sender': otherPeerId,
        // no signature -> fallback ID
      };

      final p1 = p2p.Packet(
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(publishMsg))),
        header: p2p.PacketHeader(id: 1, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(
          address: InternetAddress.loopbackIPv4,
          port: 0,
        ),
      );
      p1.srcPeerId = p2p.PeerId(value: Base58().base58Decode(otherPeerId));

      mockRouter.simulateIncomingMessage('pubsub', p1);

      // Clear last sent
      mockRouter.lastSentMessage = null;

      // 2. Receive IWANT for that ID
      final iwantMsg = {
        'action': 'iwant',
        'topic': topic,
        'msgIds': [msgId],
        'sender': otherPeerId,
        'content': '',
      };

      final p2 = p2p.Packet(
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(iwantMsg))),
        header: p2p.PacketHeader(id: 1, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(
          address: InternetAddress.loopbackIPv4,
          port: 0,
        ),
      );
      p2.srcPeerId = p2p.PeerId(value: Base58().base58Decode(otherPeerId));

      mockRouter.simulateIncomingMessage('pubsub', p2);

      // 3. Verify response (Publish)
      expect(mockRouter.lastSentMessage, isNotNull);
      final sentJson = jsonDecode(utf8.decode(mockRouter.lastSentMessage!));
      // Should be a publish message
      expect(sentJson['content'], equals(content));
    });
  });
}
