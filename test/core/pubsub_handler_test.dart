import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:test/test.dart';

class MockP2plibRouter implements P2plibRouter {
  final _pubSubEventsController = StreamController<PubSubEvent>.broadcast();
  final _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();
  final _messageEventsController = StreamController<MessageEvent>.broadcast();
  final _dhtEventsController = StreamController<DHTEvent>.broadcast();
  final _streamEventsController = StreamController<StreamEvent>.broadcast();
  final _errorEventsController = StreamController<ErrorEvent>.broadcast();

  final Set<String> registeredProtocols = {};
  final Map<String, String> publishedMessages = {};

  @override
  Stream<PubSubEvent> get pubSubEvents => _pubSubEventsController.stream;
  @override
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;
  @override
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;
  @override
  Stream<DHTEvent> get dhtEvents => _dhtEventsController.stream;
  @override
  Stream<StreamEvent> get streamEvents => _streamEventsController.stream;
  @override
  Stream<ErrorEvent> get errorEvents => _errorEventsController.stream;

  @override
  void registerProtocol(String protocolId) {
    registeredProtocols.add(protocolId);
  }

  @override
  Future<void> sendMessage(
    String peerId,
    Uint8List message, {
    String? protocolId,
  }) async {
    if (protocolId == 'pubsub') {
      // In a real client, the message would be a pubsub-specific format.
      // Here we just track it.
    }
  }

  final Map<String, void Function(NetworkPacket)> handlers = {};

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    handlers[protocolId] = handler;
  }

  @override
  bool isConnectedPeer(String peerId) => true;

  @override
  void removeMessageHandler(String protocolId) {
    handlers.remove(protocolId);
  }

  void simulatePubSubMessage(String topic, String content, String publisher) {
    final data = Uint8List.fromList(utf8.encode(content));

    // Simulate Router-level protocol message (json for PubSubClient)
    final pubsubPacket = {
      'topic': topic,
      'content': content,
      'sender': publisher,
    };
    final datagram = Uint8List.fromList(utf8.encode(jsonEncode(pubsubPacket)));

    if (handlers.containsKey('pubsub')) {
      handlers['pubsub']!(
        NetworkPacket(srcPeerId: publisher, datagram: datagram),
      );
    }

    // Simulate Node-level network event
    final event = PubSubEvent(
      topic: topic,
      message: data,
      publisher: publisher,
      eventType: 'pubsub_message_received',
    );
    _pubSubEventsController.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCircuitRelayClient implements CircuitRelayClient {
  final _eventsController =
      StreamController<CircuitRelayConnectionEvent>.broadcast();

  @override
  Stream<CircuitRelayConnectionEvent> get connectionEvents =>
      _eventsController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PubSubHandler Tests', () {
    late MockP2plibRouter router;
    late MockCircuitRelayClient relayClient;
    late IpfsNodeNetworkEvents networkEvents;
    late PubSubHandler handler;
    const String peerId = 'QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';

    setUp(() async {
      router = MockP2plibRouter();
      relayClient = MockCircuitRelayClient();
      networkEvents = IpfsNodeNetworkEvents(relayClient, router);
      networkEvents.start();
      handler = PubSubHandler(router, peerId, networkEvents);
      await handler.start();
    });

    tearDown(() async {
      await handler.stop();
      networkEvents.dispose();
    });

    test('should subscribe to a topic', () async {
      await handler.subscribe('test-topic');
      final status = await handler.getStatus();
      expect(status['subscribed_topics'], contains('test-topic'));
    });

    test('should unsubscribe from a topic', () async {
      await handler.subscribe('test-topic');
      await handler.unsubscribe('test-topic');
      final status = await handler.getStatus();
      expect(status['subscribed_topics'], isNot(contains('test-topic')));
    });

    test('should receive messages on subscribed topic', () async {
      await handler.subscribe('test-topic');

      final messageFuture = handler.messages.firstWhere(
        (m) => m.topic == 'test-topic',
      );

      router.simulatePubSubMessage('test-topic', 'Hello World', 'other-peer');

      final received = await messageFuture.timeout(const Duration(seconds: 1));
      expect(received.content, equals('Hello World'));
      expect(received.sender, equals('other-peer'));
    });

    test('should track number of published messages', () async {
      await handler.publish('test-topic', 'Message 1');
      await handler.publish('test-topic', 'Message 2');

      final status = await handler.getStatus();
      expect(status['messages_published'], equals(2));
    });

    test('should handle onMessage callback', () async {
      final completer = Completer<String>();

      handler.onMessage('test-topic', (msg) {
        completer.complete(msg);
      });

      await handler.subscribe('test-topic');
      router.simulatePubSubMessage('test-topic', 'Callback Data', 'sender-1');

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result, equals('Callback Data'));
    });
  });
}
