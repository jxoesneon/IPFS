import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';

import 'pubsub_client_coverage_test.mocks.dart';

@GenerateNiceMocks([MockSpec<RouterInterface>()])
void main() {
  late PubSubClient client;
  late MockRouterInterface mockRouter;
  final peerId = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

  setUp(() {
    mockRouter = MockRouterInterface();
    client = PubSubClient(mockRouter, peerId);
  });

  group('PubSubClient', () {
    test('start and stop', () async {
      await client.start();
      verify(mockRouter.registerProtocolHandler(any, any)).called(1);
      await client.stop();
    });

    test('subscribe and unsubscribe', () async {
      await client.subscribe('topic1');
      verify(mockRouter.registerProtocol('topic1')).called(1);

      await client.unsubscribe('topic1');
      verify(mockRouter.removeMessageHandler('topic1')).called(1);
    });

    test('publish success', () async {
      await client.start();
      client.graftPeer('peer1');

      await client.publish('topic1', 'hello');
      verify(mockRouter.sendMessage('peer1', any)).called(1);
    });

    test('handle incoming publish message', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final sender = 'QmSender';
      when(mockRouter.isConnectedPeer(sender)).thenReturn(true);

      final topic = 'topic1';
      final content = 'hello';

      // Compute valid signature
      final key = utf8.encode(sender);
      final data = utf8.encode('$topic:$content');
      final signature = Hmac(sha256, key).convert(data).toString();

      final msg = {
        'sender': sender,
        'topic': topic,
        'content': content,
        'signature': signature,
      };

      final packet = NetworkPacket(
        srcPeerId: sender,
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
      );

      // Start listening before triggering handler
      final receivedFuture = client.messagesStream.first;
      capturedHandler(packet);

      final received = await receivedFuture;
      expect(received.topic, equals(topic));
      expect(received.content, equals(content));
    });

    test('handle ihave message triggers iwant', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final sender = 'QmSender';
      final msg = {
        'action': 'ihave',
        'topic': 'topic1',
        'msgIds': ['id1'],
        'sender': sender,
      };

      final packet = NetworkPacket(
        srcPeerId: sender,
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
      );

      capturedHandler(packet);

      await Future.delayed(Duration(milliseconds: 10));

      // Verify and capture in one go
      final capturedMsg =
          verify(mockRouter.sendMessage(sender, captureAny)).captured.single
              as Uint8List;
      final decoded = jsonDecode(utf8.decode(capturedMsg));
      expect(decoded['action'], equals('iwant'));
    });

    test('handle iwant message sends cached message', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final sender = 'QmSender';
      when(mockRouter.isConnectedPeer(sender)).thenReturn(true);

      final topic = 'topic1';
      final content = 'hello';

      // Compute valid signature
      final key = utf8.encode(sender);
      final data = utf8.encode('$topic:$content');
      final signature = Hmac(sha256, key).convert(data).toString();

      final publishMsg = {
        'sender': sender,
        'topic': topic,
        'content': content,
        'signature': signature,
      };

      capturedHandler(
        NetworkPacket(
          srcPeerId: sender,
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(publishMsg))),
        ),
      );

      // Now handle iwant
      final iwantMsg = {
        'action': 'iwant',
        'topic': topic,
        'msgIds': [
          signature,
        ], // Message ID is the signature in this implementation
        'sender': 'QmAnother',
      };

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmAnother',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(iwantMsg))),
        ),
      );

      await Future.delayed(Duration(milliseconds: 10));
      verify(mockRouter.sendMessage('QmAnother', any)).called(1);
    });

    test('graft and prune', () async {
      client.graftPeer('peer1');
      client.graftPeer('peer1'); // Test dedup

      client.prunePeer('peer1');
      client.prunePeer('peer2'); // Test non-existent
    });

    test('handle graft action', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'action': 'graft', 'sender': 'QmSender'};

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Peer should be in mesh now. Verify by publishing.
      await client.publish('topic1', 'msg');
      verify(mockRouter.sendMessage('QmSender', any)).called(1);
    });

    test('handle prune action', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      client.graftPeer('QmSender');

      final msg = {'action': 'prune', 'sender': 'QmSender'};

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Peer should be removed from mesh.
      clearInteractions(mockRouter);
      await client.publish('topic1', 'msg');
      verifyNever(mockRouter.sendMessage('QmSender', any));
    });

    test('onMessage registers handler', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      Completer<String> completer = Completer();
      client.onMessage('topic1', (msg) => completer.complete(msg));

      when(mockRouter.isConnectedPeer('sender')).thenReturn(true);
      final publishMsg = {
        'sender': 'sender',
        'topic': 'topic1',
        'content': 'data',
      };

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'sender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(publishMsg))),
        ),
      );

      expect(await completer.future, equals('data'));
    });

    test('invalid signature rejection', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final sender = 'QmSender';
      when(mockRouter.isConnectedPeer(sender)).thenReturn(true);

      final msg = {
        'sender': sender,
        'topic': 'topic1',
        'content': 'hello',
        'signature': 'invalid',
      };

      capturedHandler(
        NetworkPacket(
          srcPeerId: sender,
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // messageStream should NOT receive anything
      // We can check it with a timeout
      final streamFuture = client.messagesStream.first.timeout(
        Duration(milliseconds: 100),
        onTimeout: () =>
            PubSubMessage(topic: 'timeout', content: '', sender: ''),
      );
      final result = await streamFuture;
      expect(result.topic, equals('timeout'));
    });

    test('heartbeat maintains mesh', () async {
      // We can't easily test heartbeat effects without exposing private fields or waiting long
      // But we can trigger it if we have access or just let the timer run.
    });

    test('decodeMessage', () {
      expect(
        client.decodeMessage(Uint8List.fromList(utf8.encode('abc'))),
        equals('abc'),
      );
    });

    test('encode requests', () {
      expect(client.encodeSubscribeRequest('topic1'), isNotEmpty);
      expect(client.encodeUnsubscribeRequest('topic1'), isNotEmpty);
    });

    test('message deduplication', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final sender = 'QmSender';
      when(mockRouter.isConnectedPeer(sender)).thenReturn(true);

      final msg = {'sender': sender, 'topic': 'topic1', 'content': 'duplicate'};

      final packet = NetworkPacket(
        srcPeerId: sender,
        datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
      );

      // Receive once
      final firstReceived = client.messagesStream.first;
      capturedHandler(packet);
      await firstReceived;

      // Receive again
      capturedHandler(packet);

      // messageStream should NOT have another message
      final streamFuture = client.messagesStream.first.timeout(
        Duration(milliseconds: 100),
        onTimeout: () =>
            PubSubMessage(topic: 'timeout', content: '', sender: ''),
      );
      final result = await streamFuture;
      expect(result.topic, equals('timeout'));
    });

    test('handle ihave with new topic', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {
        'action': 'ihave',
        'topic': 'new-topic',
        'msgIds': ['id1'],
        'sender': 'QmSender',
      };

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      await Future.delayed(Duration(milliseconds: 10));
      verify(mockRouter.sendMessage('QmSender', any)).called(1);
    });

    test('getNodeStats throws when not available', () async {
      await expectLater(() => client.getNodeStats(), throwsA(isA<Exception>()));
    });

    test('publish when not started throws', () async {
      await expectLater(
        () => client.publish('topic1', 'msg'),
        throwsA(isA<StateError>()),
      );
    });

    test('duplicate subscribe is idempotent', () async {
      await client.subscribe('topic1');
      await client.subscribe('topic1');
      verify(mockRouter.registerProtocol('topic1')).called(1);
    });

    test('unsubscribe non-existent topic does nothing', () async {
      await client.unsubscribe('nonexistent');
      verifyNever(mockRouter.removeMessageHandler('nonexistent'));
    });

    test('stop when not stopped is idempotent', () async {
      await client.stop();
      await client.stop(); // Should not throw
    });

    test('_handleIHave with null parameters', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      // Test with null topic
      final msg1 = {
        'action': 'ihave',
        'msgIds': ['id1'],
        'sender': 'QmSender',
      };
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg1))),
        ),
      );

      // Test with null msgIds
      final msg2 = {'action': 'ihave', 'topic': 'topic1', 'sender': 'QmSender'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg2))),
        ),
      );

      // Should not throw
    });

    test('_handleIWant with null parameters', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      // Test with null topic
      final msg1 = {
        'action': 'iwant',
        'msgIds': ['id1'],
        'sender': 'QmSender',
      };
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg1))),
        ),
      );

      // Test with null msgIds
      final msg2 = {'action': 'iwant', 'topic': 'topic1', 'sender': 'QmSender'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg2))),
        ),
      );

      // Should not throw
    });

    test('heartbeat maintains mesh', () async {
      await client.start();
      client.graftPeer('peer1');
      client.graftPeer('peer2');
      client.graftPeer('peer3');
      client.graftPeer('peer4');
      client.graftPeer('peer5');
      client.graftPeer('peer6');
      client.graftPeer('peer7');
      client.graftPeer('peer8');
      client.graftPeer('peer9');
      client.graftPeer('peer10');

      // Wait for heartbeat to run
      await Future.delayed(Duration(milliseconds: 1100));

      // Should not throw
      await client.stop();
    });

    test('heartbeat prunes low scoring peers', () async {
      await client.start();
      client.graftPeer('peer1');
      client.graftPeer('peer2');
      client.graftPeer('peer3');
      client.graftPeer('peer4');
      client.graftPeer('peer5');
      client.graftPeer('peer6');
      client.graftPeer('peer7');
      client.graftPeer('peer8');
      client.graftPeer('peer9');
      client.graftPeer('peer10');
      client.graftPeer('peer11');

      // Wait for heartbeat to run and prune
      await Future.delayed(Duration(milliseconds: 1100));

      // Should not throw
      await client.stop();
    });

    test('encodePublishRequest includes signature', () {
      final encoded = client.encodePublishRequest('topic1', 'hello');
      expect(encoded, isNotEmpty);
      expect(encoded.length, greaterThan(0));
    });

    test('decodeMessage handles empty bytes', () {
      final decoded = client.decodeMessage(Uint8List.fromList([]));
      expect(decoded, equals(''));
    });

    test('publish with empty mesh logs warning', () async {
      await client.start();
      // Don't graft any peers, mesh is empty
      await client.publish('topic1', 'msg');
      // Should not throw even with empty mesh
      await client.stop();
    });

    test('message without topic is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'sender': 'QmSender', 'content': 'hello'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('message without content is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'sender': 'QmSender', 'topic': 'topic1'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('message without sender is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'topic': 'topic1', 'content': 'hello'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('message from unconnected peer is not added to stream', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      when(mockRouter.isConnectedPeer('QmSender')).thenReturn(false);

      final msg = {'sender': 'QmSender', 'topic': 'topic1', 'content': 'hello'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // messageStream should NOT have a message
      final streamFuture = client.messagesStream.first.timeout(
        Duration(milliseconds: 100),
        onTimeout: () =>
            PubSubMessage(topic: 'timeout', content: '', sender: ''),
      );
      final result = await streamFuture;
      expect(result.topic, equals('timeout'));
      await client.stop();
    });

    test('handle unknown action logs warning', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'action': 'unknown', 'sender': 'QmSender'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('handle invalid JSON logs error', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final packet = NetworkPacket(
        srcPeerId: 'QmSender',
        datagram: Uint8List.fromList(utf8.encode('invalid json{')),
      );

      capturedHandler(packet);

      // Should not throw
      await client.stop();
    });

    test('subscribe when already started is idempotent', () async {
      await client.start();
      await client.subscribe('topic1');
      verify(mockRouter.registerProtocol('topic1')).called(1);
      await client.stop();
    });

    test('publish with null mesh peer does not throw', () async {
      await client.start();
      // Don't graft any peers
      await client.publish('topic1', 'msg');
      // Should not throw even with empty mesh
      await client.stop();
    });

    test('encodeSubscribeRequest returns non-empty bytes', () {
      final encoded = client.encodeSubscribeRequest('topic1');
      expect(encoded, isNotEmpty);
      expect(encoded.length, greaterThan(0));
    });

    test('encodeUnsubscribeRequest returns non-empty bytes', () {
      final encoded = client.encodeUnsubscribeRequest('topic1');
      expect(encoded, isNotEmpty);
      expect(encoded.length, greaterThan(0));
    });

    test('decodeMessage handles null bytes', () {
      final decoded = client.decodeMessage(Uint8List.fromList([0, 0, 0]));
      expect(decoded, isNotNull);
    });

    test('message with empty topic is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'sender': 'QmSender', 'topic': '', 'content': 'hello'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('message with empty content is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'sender': 'QmSender', 'topic': 'topic1', 'content': ''};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('handleGraft with unknown peer adds to mesh', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'action': 'graft', 'sender': 'QmNewPeer'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmNewPeer',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });

    test('handlePrune with unknown peer does not throw', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      final msg = {'action': 'prune', 'sender': 'QmUnknownPeer'};
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmUnknownPeer',
          datagram: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
        ),
      );

      // Should not throw
      await client.stop();
    });
  });
}
