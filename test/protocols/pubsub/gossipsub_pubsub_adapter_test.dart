// test/protocols/pubsub/gossipsub_pubsub_adapter_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/gossipsub.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

class _FakeRouter implements RouterInterface {
  final _handlers = <String, void Function(NetworkPacket)>{};
  final _events = StreamController<ConnectionEvent>.broadcast();

  @override
  String get peerID => 'localPeer';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => {};

  @override
  Stream<ConnectionEvent> get connectionEvents => _events.stream;

  @override
  Stream<MessageEvent> get messageEvents => const Stream<MessageEvent>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {}

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}

  @override
  List<String> get listeningAddresses => [];

  @override
  List<String> listConnectedPeers() => [];

  @override
  bool isConnectedPeer(String peerIdStr) => false;

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {}

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  Stream<Uint8List> receiveMessages(String peerId) => const Stream.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void unregisterProtocolHandler(String protocolId) {}

  @override
  void removeMessageHandler(String protocolId) {}

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async => Uint8List(0);

  @override
  void registerProtocol(String protocolId) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

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

  void deliverMessage(String peerId, Uint8List datagram, {String? protocolId}) {
    final handler = _handlers[protocolId ?? '/meshsub/1.1.0'];
    handler?.call(NetworkPacket(srcPeerId: peerId, datagram: datagram));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GossipsubHandler> _createHandler(_FakeRouter router) async {
  final keyPair = await Ed25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final signer = Ed25519MessageSigner(keyPair);
  return GossipsubHandler(
    router: router,
    signer: signer,
    peerId: Uint8List.fromList(publicKey.bytes),
  );
}

void main() {
  group('GossipsubPubSubAdapter', () {
    late _FakeRouter router;
    late GossipsubHandler handler;
    late GossipsubPubSubAdapter adapter;

    setUp(() async {
      router = _FakeRouter();
      handler = await _createHandler(router);
      adapter = GossipsubPubSubAdapter(handler);
    });

    tearDown(() async {
      await adapter.stop();
    });

    test('subscribes and publishes to a topic', () async {
      await adapter.start();
      await adapter.subscribe('test-topic');
      expect(handler.subscriptions, contains('test-topic'));

      await adapter.publish('test-topic', 'hello world');
      // Publishing should not throw; the handler signs and broadcasts the
      // message even when no peers are connected.
    });

    test('delivers decoded string messages to onMessage handlers', () async {
      await adapter.start();
      await adapter.subscribe('test-topic');

      final completer = Completer<String>();
      adapter.onMessage('test-topic', completer.complete);

      // Inject a message from a peer using a fresh signer so signature
      // verification succeeds in this controlled test.
      final senderKeyPair = await Ed25519().newKeyPair();
      final senderSigner = Ed25519MessageSigner(senderKeyPair);
      final senderPublicKey = await senderKeyPair.extractPublicKey();
      final message = Message()
        ..from = Uint8List.fromList(senderPublicKey.bytes)
        ..data = Uint8List.fromList(utf8.encode('hello from adapter'))
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..topic = 'test-topic';
      message.signature = await senderSigner.signMessage(message);
      message.key = Uint8List.fromList(senderPublicKey.bytes);

      final rpc = RPC()..publish.add(message);
      router.deliverMessage('peer1', rpc.writeToBuffer());

      final received = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      expect(received, equals('hello from adapter'));
    });

    test('unsubscribe cancels handler subscription', () async {
      await adapter.start();
      await adapter.subscribe('test-topic');
      await adapter.unsubscribe('test-topic');
      expect(handler.subscriptions, isNot(contains('test-topic')));
    });
  });
}
