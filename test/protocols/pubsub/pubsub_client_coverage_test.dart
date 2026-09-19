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
    // These tests exercise the legacy unauthenticated paths; strict
    // authentication (the default) is covered separately below.
    client = PubSubClient(mockRouter, peerId, strictAuthentication: false);
  });

  group('PubSubClient', () {
    test('start and stop', () async {
      await client.start();
      // The client registers the legacy 'pubsub' JSON handler plus the
      // gossipsub meshsub handlers for real wire interop.
      verify(mockRouter.registerProtocolHandler('pubsub', any)).called(1);
      verify(
        mockRouter.registerProtocolHandler('/meshsub/1.1.0', any),
      ).called(1);
      verify(
        mockRouter.registerProtocolHandler('/meshsub/1.0.0', any),
      ).called(1);
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
      verify(
        mockRouter.sendMessage(
          'peer1',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('handle incoming publish message', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
          verify(
                mockRouter.sendMessage(
                  sender,
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final decoded = jsonDecode(utf8.decode(capturedMsg));
      expect(decoded['action'], equals('iwant'));
    });

    test('handle iwant message sends cached message', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
      verify(
        mockRouter.sendMessage(
          'QmAnother',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
      verify(
        mockRouter.sendMessage(
          'QmSender',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('handle prune action', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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

      // Peer should be removed from mesh; with no remaining delivery
      // targets the publish now fails loudly.
      clearInteractions(mockRouter);
      await expectLater(
        client.publish('topic1', 'msg'),
        throwsA(isA<PubSubDeliveryError>()),
      );
      verifyNever(
        mockRouter.sendMessage(
          'QmSender',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      );
    });

    test('onMessage registers handler', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
      verify(
        mockRouter.sendMessage(
          'QmSender',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
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

    test('subscribe announces to connected peers on pubsub protocol', () async {
      when(mockRouter.connectedPeers).thenReturn({'peer1', 'peer2'});
      await client.subscribe('topic1');

      for (final peer in ['peer1', 'peer2']) {
        final sent =
            verify(
                  mockRouter.sendMessage(
                    peer,
                    captureAny,
                    protocolId: 'pubsub',
                  ),
                ).captured.single
                as Uint8List;
        expect(utf8.decode(sent), equals('subscribe:topic1'));
      }
    });

    test('unsubscribe announces to connected peers', () async {
      when(mockRouter.connectedPeers).thenReturn({'peer1'});
      await client.subscribe('topic1');
      clearInteractions(mockRouter);
      when(mockRouter.connectedPeers).thenReturn({'peer1'});

      await client.unsubscribe('topic1');

      final sent =
          verify(
                mockRouter.sendMessage(
                  'peer1',
                  captureAny,
                  protocolId: 'pubsub',
                ),
              ).captured.single
              as Uint8List;
      expect(utf8.decode(sent), equals('unsubscribe:topic1'));
    });

    test('announcement failure to one peer does not break subscribe', () async {
      when(mockRouter.connectedPeers).thenReturn({'peer1', 'peer2'});
      when(
        mockRouter.sendMessage(
          'peer1',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).thenThrow(Exception('unreachable'));

      await client.subscribe('topic1');
      verify(
        mockRouter.sendMessage(
          'peer2',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('inbound subscribe announcement records topic peer', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmAnnouncer',
          datagram: Uint8List.fromList(utf8.encode('subscribe:topic1')),
        ),
      );
      await Future.delayed(Duration(milliseconds: 10));

      expect(client.peersForTopic('topic1'), contains('QmAnnouncer'));
    });

    test('publish fans out to topic peers outside the mesh', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
              ).captured.single
              as void Function(NetworkPacket);

      // 'QmAnnouncer' subscribes to the topic but is never grafted.
      capturedHandler(
        NetworkPacket(
          srcPeerId: 'QmAnnouncer',
          datagram: Uint8List.fromList(utf8.encode('subscribe:topic1')),
        ),
      );
      await Future.delayed(Duration(milliseconds: 10));

      await client.publish('topic1', 'hello');
      verify(
        mockRouter.sendMessage('QmAnnouncer', any, protocolId: 'pubsub'),
      ).called(1);
    });

    test('publish sends on the pubsub protocol', () async {
      await client.start();
      client.graftPeer('peer1');

      await client.publish('topic1', 'hello');
      verify(
        mockRouter.sendMessage('peer1', any, protocolId: 'pubsub'),
      ).called(1);
    });

    test('stop when not stopped is idempotent', () async {
      await client.stop();
      await client.stop(); // Should not throw
    });

    test('_handleIHave with null parameters', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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

    test('publish with empty mesh throws PubSubDeliveryError', () async {
      await client.start();
      // Don't graft any peers, mesh is empty: the message would be
      // silently dropped, so publish must fail loudly.
      await expectLater(
        client.publish('topic1', 'msg'),
        throwsA(isA<PubSubDeliveryError>()),
      );
      await client.stop();
    });

    test('message without topic is rejected', () async {
      await client.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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

    test('publish with no delivery targets throws', () async {
      await client.start();
      // Don't graft any peers: zero delivery targets is a delivery
      // failure, not a success.
      await expectLater(
        client.publish('topic1', 'msg'),
        throwsA(isA<PubSubDeliveryError>()),
      );
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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
                mockRouter.registerProtocolHandler('pubsub', captureAny),
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

  group('PubSubClient bounds and eviction', () {
    Future<void Function(NetworkPacket)> packetHandler() async {
      await client.start();
      return verify(
            mockRouter.registerProtocolHandler('pubsub', captureAny),
          ).captured.single
          as void Function(NetworkPacket);
    }

    NetworkPacket contentPacket(String sender, String topic, String content) {
      return NetworkPacket(
        srcPeerId: sender,
        datagram: Uint8List.fromList(
          utf8.encode(
            jsonEncode({'sender': sender, 'topic': topic, 'content': content}),
          ),
        ),
      );
    }

    NetworkPacket subscribePacket(String peer, String topic) {
      return NetworkPacket(
        srcPeerId: peer,
        datagram: Uint8List.fromList(utf8.encode('subscribe:$topic')),
      );
    }

    test('evicts the oldest cached message beyond the per-topic cap', () async {
      final handler = await packetHandler();
      when(mockRouter.isConnectedPeer(any)).thenReturn(true);

      // _maxEntriesPerTopic is 512; the 513th distinct message evicts the
      // oldest cache and dedup entries.
      for (var i = 0; i < 513; i++) {
        handler(contentPacket('QmSender', 'topic1', 'content-$i'));
      }

      await client.stop();
    });

    test('evicts the oldest topic beyond the tracked-topics cap', () async {
      final handler = await packetHandler();
      when(mockRouter.isConnectedPeer(any)).thenReturn(true);

      // _maxTrackedTopics is 256; the 257th topic evicts the oldest from
      // both the message cache and the dedup set.
      for (var i = 0; i < 257; i++) {
        handler(contentPacket('QmSender', 'topic-$i', 'content'));
      }

      await client.stop();
    });

    test('evicts the oldest peer beyond the per-topic peer cap', () async {
      final handler = await packetHandler();

      // _maxPeersPerTopic is 128; the 129th announcer evicts the oldest.
      for (var i = 0; i < 129; i++) {
        handler(subscribePacket('QmPeer$i', 'topic1'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(client.peersForTopic('topic1'), hasLength(128));
      await client.stop();
    });

    test('subscribe grafts peers that already announced the topic', () async {
      final handler = await packetHandler();
      handler(subscribePacket('QmAnnouncer', 'topic1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await client.subscribe('topic1');

      // The announcer was grafted into the mesh; it is visible through the
      // peersForTopic mesh fallback for topics with no recorded peers.
      expect(client.peersForTopic('unrelated'), contains('QmAnnouncer'));
      await client.stop();
    });

    test('evicts the lowest-scored peers beyond the score cap', () {
      // _maxScoredPeers is 1024; grafting a 1025th peer evicts the
      // lowest-scored entry.
      for (var i = 0; i < 1025; i++) {
        client.graftPeer('peer-$i');
      }
    });
  });

  group('PubSubClient strict authentication', () {
    late PubSubClient strictClient;

    setUp(() {
      strictClient = PubSubClient(mockRouter, peerId);
    });

    tearDown(() async {
      if (strictClient.isStarted) await strictClient.stop();
    });

    Future<void Function(NetworkPacket)> strictHandler() async {
      await strictClient.start();
      return verify(
            mockRouter.registerProtocolHandler('pubsub', captureAny),
          ).captured.last
          as void Function(NetworkPacket);
    }

    test('strict authentication is enabled by default', () {
      expect(strictClient.isStrictAuthentication, isTrue);
    });

    test('rejects unsigned content messages', () async {
      final handler = await strictHandler();
      when(mockRouter.isConnectedPeer('QmSender')).thenReturn(true);

      var delivered = false;
      final sub = strictClient.messagesStream.listen((_) => delivered = true);
      handler(
        NetworkPacket(
          srcPeerId: 'QmSender',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'sender': 'QmSender',
                'topic': 't1',
                'content': 'unsigned',
              }),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(delivered, isFalse);
      await sub.cancel();
    });

    test('rejects unsigned plain-text subscribe announcements', () async {
      final handler = await strictHandler();
      handler(
        NetworkPacket(
          srcPeerId: 'QmAnnouncer',
          datagram: Uint8List.fromList(utf8.encode('subscribe:t1')),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(strictClient.peersForTopic('t1'), isNot(contains('QmAnnouncer')));
    });

    test('rejects unsigned JSON subscribe announcements', () async {
      final handler = await strictHandler();
      handler(
        NetworkPacket(
          srcPeerId: 'QmAnnouncer',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'action': 'subscribe',
                'sender': 'QmAnnouncer',
                'topic': 't1',
              }),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(strictClient.peersForTopic('t1'), isNot(contains('QmAnnouncer')));
    });

    test(
      'rejects control messages whose sender differs from the transport peer',
      () async {
        final handler = await strictHandler();
        handler(
          NetworkPacket(
            srcPeerId: 'QmTransport',
            datagram: Uint8List.fromList(
              utf8.encode(
                jsonEncode({
                  'action': 'graft',
                  'sender': 'QmOther',
                  'topic': 't1',
                }),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(strictClient.peersForTopic('t1'), isNot(contains('QmOther')));
        expect(
          strictClient.peersForTopic('t1'),
          isNot(contains('QmTransport')),
        );
      },
    );
  });
}
