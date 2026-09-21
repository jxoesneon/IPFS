// Tests for PubSubClient's gossipsub wire interop: the protobuf RPC
// protocol spoken on /meshsub/1.1.0 and /meshsub/1.0.0 with Kubo/Helia/
// libp2p peers.
//
// Covered: protocol registration, capability discovery, SubOpts tracking,
// strict-signing verification (key field and identity peer IDs), forgery
// rejection, dedup, IHAVE/IWANT exchange, GRAFT/PRUNE, IDONTWANT, and the
// dual-stack publish path (protobuf to meshsub peers, JSON to the rest).

import 'dart:async';
import 'dart:convert';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart'
    show SimpleKeyPair, SimpleKeyPairData, SimplePublicKey;
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/gossipsub/gossipsub_rpc.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pubsub_client_coverage_test.mocks.dart';

const _meshsub = '/meshsub/1.1.0';
const _meshsubV10 = '/meshsub/1.0.0';

Uint8List _seqno(int n) {
  final seqno = Uint8List(8);
  ByteData.sublistView(seqno).setUint64(0, n);
  return seqno;
}

void main() {
  late PubSubClient client;
  late MockRouterInterface mockRouter;

  const localPeerId = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
  const kuboPeer = 'QmKuboPeerAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA111';

  /// Captures the packet handler registered for [protocolId].
  void Function(NetworkPacket) handlerFor(String protocolId) =>
      verify(
            mockRouter.registerProtocolHandler(protocolId, captureAny),
          ).captured.single
          as void Function(NetworkPacket);

  /// Sends a gossipsub RPC datagram as if it arrived from [srcPeer].
  void deliverGossipSub(
    void Function(NetworkPacket) handler,
    String srcPeer,
    GossipSubRpc rpc,
  ) {
    handler(
      NetworkPacket(
        srcPeerId: srcPeer,
        datagram: GossipSubRpcCodec.encode(rpc),
      ),
    );
  }

  /// Waits a moment for the client's unawaited async dispatch.
  Future<void> flush() => Future.delayed(const Duration(milliseconds: 30));

  setUp(() {
    mockRouter = MockRouterInterface();
    client = PubSubClient(mockRouter, localPeerId);
  });

  tearDown(() async {
    if (client.isStarted) await client.stop();
  });

  group('registration and capability discovery', () {
    test('start registers both meshsub protocol handlers', () async {
      await client.start();
      verify(mockRouter.registerProtocolHandler(_meshsub, any)).called(1);
      verify(mockRouter.registerProtocolHandler(_meshsubV10, any)).called(1);
    });

    test('first meshsub frame marks the peer and replies with our '
        'subscriptions', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      await client.subscribe('topic-x');
      clearInteractions(mockRouter);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          subscriptions: [
            GossipSubSubOpts(subscribe: true, topicId: 'topic-x'),
          ],
        ),
      );
      await flush();

      // The hello reply carries our subscription set as SubOpts records.
      final sent =
          verify(
                mockRouter.sendMessage(
                  kuboPeer,
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      final hello = GossipSubRpcCodec.decode(sent);
      expect(hello.subscriptions.map((s) => s.topicId), contains('topic-x'));
      expect(hello.subscriptions.single.subscribe, isTrue);

      // The inbound SubOpts also registered the peer for the topic.
      expect(client.peersForTopic('topic-x'), contains(kuboPeer));
    });

    test('malformed gossipsub frames are dropped without throwing', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      handler(
        NetworkPacket(
          srcPeerId: kuboPeer,
          datagram: Uint8List.fromList([0x0A, 0xFF, 0xFF, 0xFF]),
        ),
      );
      await flush();
      // No crash, no outbound traffic.
      verifyNever(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      );
    });
  });

  group('subscriptions and control handling', () {
    test('SubOpts unsubscribe removes the topic peer', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          subscriptions: [GossipSubSubOpts(subscribe: true, topicId: 't')],
        ),
      );
      await flush();
      expect(client.peersForTopic('t'), contains(kuboPeer));

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          subscriptions: [GossipSubSubOpts(subscribe: false, topicId: 't')],
        ),
      );
      await flush();
      expect(client.peersForTopic('t'), isNot(contains(kuboPeer)));
    });

    test('GRAFT adds the peer to the mesh and tracks its topic', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(
            graft: [GossipSubGraft(topicId: 't-graft')],
          ),
        ),
      );
      await flush();

      expect(client.peersForTopic('t-graft'), contains(kuboPeer));

      // Mesh membership: publishing now reaches the peer. (The empty
      // first-contact hello RPC is filtered out by the payload matcher.)
      await client.publish('t-graft', 'hi');
      verify(
        mockRouter.sendMessage(
          kuboPeer,
          argThat(isNotEmpty),
          protocolId: _meshsub,
        ),
      ).called(1);
    });

    test('PRUNE removes the peer from the mesh and the topic', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(graft: [GossipSubGraft(topicId: 't')]),
        ),
      );
      await flush();

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(prune: [GossipSubPrune(topicId: 't')]),
        ),
      );
      await flush();

      expect(client.peersForTopic('t'), isNot(contains(kuboPeer)));
      clearInteractions(mockRouter);
      await expectLater(
        client.publish('t', 'msg'),
        throwsA(isA<PubSubDeliveryError>()),
      );
    });

    test('a peer disconnect clears its gossipsub and topic state', () async {
      final events = StreamController<ConnectionEvent>();
      addTearDown(events.close);
      when(mockRouter.connectionEvents).thenAnswer((_) => events.stream);
      await client.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          subscriptions: [GossipSubSubOpts(subscribe: true, topicId: 't')],
          control: GossipSubControl(graft: [GossipSubGraft(topicId: 't')]),
        ),
      );
      await flush();
      expect(client.peersForTopic('t'), contains(kuboPeer));

      events.add(
        ConnectionEvent(
          type: ConnectionEventType.disconnected,
          peerId: kuboPeer,
        ),
      );
      await flush();

      // Mesh, gossipsub-capability, and topic membership must all forget
      // the peer — otherwise publishes keep targeting a dead connection.
      expect(client.peersForTopic('t'), isNot(contains(kuboPeer)));
    });

    test(
      'drops publishes sourced from a peer we are not connected to',
      () async {
        // Lax mode so the unsigned test message survives signature
        // screening and reaches the connectivity check.
        final laxClient = PubSubClient(
          mockRouter,
          localPeerId,
          strictAuthentication: false,
        );
        addTearDown(() async {
          if (laxClient.isStarted) await laxClient.stop();
        });
        await laxClient.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(false);

        var delivered = false;
        final sub = laxClient.messagesStream.listen((_) => delivered = true);
        addTearDown(sub.cancel);

        deliverGossipSub(
          handler,
          kuboPeer,
          GossipSubRpc(
            publish: [
              GossipSubMessage(
                from: Uint8List.fromList([9, 9]),
                data: Uint8List.fromList(utf8.encode('spoofed')),
                seqno: _seqno(1),
                topic: 't',
              ),
            ],
          ),
        );
        await flush();

        // A replayed/forged datagram from an address we hold no connection
        // to must never reach subscribers.
        expect(delivered, isFalse);
      },
    );

    test('IHAVE triggers IWANT for unseen message IDs on meshsub', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      clearInteractions(mockRouter);

      final wanted = Uint8List.fromList([1, 2, 3, 4]);
      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(
            ihave: [
              GossipSubIHave(topicId: 't', messageIds: [wanted]),
            ],
          ),
        ),
      );
      await flush();

      final sent =
          verify(
                mockRouter.sendMessage(
                  kuboPeer,
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      final rpc = GossipSubRpcCodec.decode(sent);
      expect(rpc.control, isNotNull);
      expect(rpc.control!.iwant.single.messageIds.single, equals(wanted));
    });

    test('IHAVE for already-seen IDs does not trigger IWANT', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      // Deliver an unsigned publish (accepted in lax mode); its ID is then
      // in the seen set.
      final msg = GossipSubMessage(
        from: Uint8List.fromList([9, 9]),
        data: Uint8List.fromList(utf8.encode('x')),
        seqno: _seqno(1),
        topic: 't',
      );
      deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [msg]));
      await flush();
      clearInteractions(mockRouter);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(
            ihave: [
              GossipSubIHave(
                topicId: 't',
                messageIds: [gossipSubDefaultMessageId(msg)],
              ),
            ],
          ),
        ),
      );
      await flush();

      verifyNever(mockRouter.sendMessage(kuboPeer, any, protocolId: _meshsub));
      await laxClient.stop();
    });
  });

  group('publish path', () {
    test('publish sends protobuf RPC to gossipsub-capable peers', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final pubKeyBytes = await signer.extractPublicKeyBytes(keyPair);
      final localId = PeerId.fromPublicKey(
        pubKeyBytes,
        type: 'Ed25519',
      ).toBase58();

      final keyedClient = PubSubClient(mockRouter, localId, keyPair: keyPair);
      await keyedClient.start();
      final handler = handlerFor(_meshsub);

      // Learn that kuboPeer speaks meshsub.
      deliverGossipSub(handler, kuboPeer, GossipSubRpc());
      await flush();

      keyedClient.graftPeer(kuboPeer);
      await keyedClient.publish('interop-topic', 'hello kubo');

      final sent =
          verify(
                mockRouter.sendMessage(
                  kuboPeer,
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      final rpc = GossipSubRpcCodec.decode(sent);
      expect(rpc.publish, hasLength(1));

      final msg = rpc.publish.single;
      expect(msg.topic, 'interop-topic');
      expect(utf8.decode(msg.data!), 'hello kubo');
      expect(msg.from, isNotEmpty);
      expect(msg.seqno, hasLength(8));
      // Identity-multihash peer IDs embed the key, so `key` stays empty —
      // matching go-libp2p-pubsub behavior.
      expect(msg.key, isNull);

      // The signature verifies against the spec payload and the key
      // embedded in `from`.
      final embeddedKey = gossipSubPeerIdPublicKey(msg.from!);
      expect(embeddedKey, isNotNull);
      final valid = await signer.verify(
        gossipSubSigningPayload(msg),
        msg.signature!,
        signer.publicKeyFromBytes(embeddedKey!),
      );
      expect(valid, isTrue);

      await keyedClient.stop();
    });

    test(
      'publishData carries binary payloads verbatim on the gossipsub wire',
      () async {
        final signer = Ed25519Signer();
        final keyPair = await signer.generateKeyPair();
        final pubKeyBytes = await signer.extractPublicKeyBytes(keyPair);
        final localId = PeerId.fromPublicKey(
          pubKeyBytes,
          type: 'Ed25519',
        ).toBase58();

        final keyedClient = PubSubClient(mockRouter, localId, keyPair: keyPair);
        await keyedClient.start();
        final handler = handlerFor(_meshsub);

        deliverGossipSub(handler, kuboPeer, GossipSubRpc());
        await flush();

        keyedClient.graftPeer(kuboPeer);
        // Bytes 0x80+ are not valid UTF-8 here — any String conversion on
        // the publish path would corrupt them.
        final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
        await keyedClient.publishData('binary-topic', payload);

        final sent =
            verify(
                  mockRouter.sendMessage(
                    kuboPeer,
                    captureAny,
                    protocolId: _meshsub,
                  ),
                ).captured.last
                as Uint8List;
        final rpc = GossipSubRpcCodec.decode(sent);
        expect(rpc.publish, hasLength(1));

        final msg = rpc.publish.single;
        expect(msg.topic, 'binary-topic');
        expect(msg.data, equals(payload));

        final embeddedKey = gossipSubPeerIdPublicKey(msg.from!);
        final valid = await signer.verify(
          gossipSubSigningPayload(msg),
          msg.signature!,
          signer.publicKeyFromBytes(embeddedKey!),
        );
        expect(valid, isTrue);

        await keyedClient.stop();
      },
    );

    test('publish still sends JSON to non-gossipsub peers', () async {
      await client.start();
      client.graftPeer('json-peer');

      await client.publish('t', 'hello');
      final sent =
          verify(
                mockRouter.sendMessage(
                  'json-peer',
                  captureAny,
                  protocolId: 'pubsub',
                ),
              ).captured.single
              as Uint8List;
      expect(() => jsonDecode(utf8.decode(sent)), returnsNormally);
    });
  });

  group('strict-signing message verification', () {
    late Ed25519Signer signer;
    late SimpleKeyPair authorKeyPair;
    late Uint8List authorPubKey;
    late PeerId authorPeerId;
    late String authorPeerIdStr;

    setUp(() async {
      signer = Ed25519Signer();
      authorKeyPair = await signer.generateKeyPair();
      authorPubKey = await signer.extractPublicKeyBytes(authorKeyPair);
      authorPeerId = PeerId.fromPublicKey(authorPubKey, type: 'Ed25519');
      authorPeerIdStr = authorPeerId.toBase58();
    });

    /// Builds a spec-conformant signed gossipsub message.
    Future<GossipSubMessage> signedMessage({
      required SimpleKeyPair keyPair,
      required Uint8List from,
      required String topic,
      required String content,
      int seq = 1,
      Uint8List? keyField,
    }) async {
      final msg = GossipSubMessage(
        from: from,
        data: Uint8List.fromList(utf8.encode(content)),
        seqno: _seqno(seq),
        topic: topic,
        key: keyField,
      );
      // Sign BEFORE attaching key — matching go-libp2p-pubsub signMessage.
      msg.signature = await signer.sign(gossipSubSigningPayload(msg), keyPair);
      msg.key = keyField;
      return msg;
    }

    test(
      'accepts a signed message with an identity peer ID (key embedded)',
      () async {
        await client.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

        final msg = await signedMessage(
          keyPair: authorKeyPair,
          from: authorPeerId.value,
          topic: 'signed-topic',
          content: 'authentic content',
        );

        final received = client.messagesStream.first;
        deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [msg]));

        final delivered = await received;
        expect(delivered.topic, 'signed-topic');
        expect(delivered.content, 'authentic content');
        expect(delivered.sender, authorPeerIdStr);
      },
    );

    test('accepts a signed message with the key field (Qm peer ID)', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      // A non-identity (sha256 multihash) peer ID, as older/RSA-style
      // libp2p hosts use: 0x12 0x20 sha256(marshalled key).
      final digest = _sha256MultihashPeerId(authorPubKey);
      final msg = await signedMessage(
        keyPair: authorKeyPair,
        from: digest,
        topic: 'key-field-topic',
        content: 'signed via key field',
        keyField: marshalGossipSubEd25519PublicKey(authorPubKey),
      );

      final received = client.messagesStream.first;
      deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [msg]));

      final delivered = await received;
      expect(delivered.content, 'signed via key field');
    });

    test(
      'rejects a message signed with a key that does not match `from`',
      () async {
        await client.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

        // Attacker signs with their own key but claims the victim's `from`.
        final attackerKeyPair = await signer.generateKeyPair();
        final forged = await signedMessage(
          keyPair: attackerKeyPair,
          from: authorPeerId.value,
          topic: 'forgery-topic',
          content: 'impersonation attempt',
        );

        var delivered = false;
        final sub = client.messagesStream.listen((_) => delivered = true);
        deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [forged]));
        await flush();

        expect(delivered, isFalse);
        await sub.cancel();
      },
    );

    test(
      'rejects a message whose key field does not derive to `from`',
      () async {
        await client.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

        final attackerKeyPair = await signer.generateKeyPair();
        final attackerPubKey = await signer.extractPublicKeyBytes(
          attackerKeyPair,
        );
        // Attacker carries THEIR key in the key field but the victim's
        // peer ID in `from` — the binding check must catch it.
        final forged = await signedMessage(
          keyPair: attackerKeyPair,
          from: authorPeerId.value,
          topic: 'key-spoof-topic',
          content: 'bad key binding',
          keyField: marshalGossipSubEd25519PublicKey(attackerPubKey),
        );

        var delivered = false;
        final sub = client.messagesStream.listen((_) => delivered = true);
        deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [forged]));
        await flush();

        expect(delivered, isFalse);
        await sub.cancel();
      },
    );

    test('rejects an unsigned message in strict authentication mode', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      final unsigned = GossipSubMessage(
        from: authorPeerId.value,
        data: Uint8List.fromList(utf8.encode('no signature')),
        seqno: _seqno(9),
        topic: 'strict-topic',
      );

      var delivered = false;
      final sub = client.messagesStream.listen((_) => delivered = true);
      deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [unsigned]));
      await flush();

      expect(delivered, isFalse);
      await sub.cancel();
    });

    test(
      'accepts an unsigned message when strict authentication is off',
      () async {
        final laxClient = PubSubClient(
          mockRouter,
          localPeerId,
          strictAuthentication: false,
        );
        await laxClient.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

        final unsigned = GossipSubMessage(
          from: authorPeerId.value,
          data: Uint8List.fromList(utf8.encode('lax content')),
          seqno: _seqno(3),
          topic: 'lax-topic',
        );

        final received = laxClient.messagesStream.first;
        deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [unsigned]));

        final delivered = await received;
        expect(delivered.content, 'lax content');
        await laxClient.stop();
      },
    );

    test('binary payloads survive delivery via PubSubMessage.data', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final unsigned = GossipSubMessage(
        from: authorPeerId.value,
        data: payload,
        seqno: _seqno(4),
        topic: 'binary-inbound',
      );

      final received = laxClient.messagesStream.first;
      deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [unsigned]));

      final delivered = await received;
      expect(delivered.data, equals(payload));
      // content is the lossy view — it must not be confused with the payload.
      expect(utf8.encode(delivered.content), isNot(equals(payload)));
      await laxClient.stop();
    });

    test('deduplicates repeated messages by from||seqno', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      final msg = await signedMessage(
        keyPair: authorKeyPair,
        from: authorPeerId.value,
        topic: 'dedup-topic',
        content: 'once only',
      );

      final received = client.messagesStream.first;
      final frame = GossipSubRpcCodec.encode(GossipSubRpc(publish: [msg]));
      handler(NetworkPacket(srcPeerId: kuboPeer, datagram: frame));
      await received;

      var delivered = false;
      final sub = client.messagesStream.listen((_) => delivered = true);
      handler(NetworkPacket(srcPeerId: kuboPeer, datagram: frame));
      await flush();
      expect(delivered, isFalse);
      await sub.cancel();
    });

    test('IWANT serves a previously received signed message', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer(kuboPeer)).thenReturn(true);

      final msg = await signedMessage(
        keyPair: authorKeyPair,
        from: authorPeerId.value,
        topic: 'iwant-topic',
        content: 'cached content',
      );
      deliverGossipSub(handler, kuboPeer, GossipSubRpc(publish: [msg]));
      await flush();
      clearInteractions(mockRouter);

      deliverGossipSub(
        handler,
        kuboPeer,
        GossipSubRpc(
          control: GossipSubControl(
            iwant: [
              GossipSubIWant(messageIds: [gossipSubDefaultMessageId(msg)]),
            ],
          ),
        ),
      );
      await flush();

      final sent =
          verify(
                mockRouter.sendMessage(
                  kuboPeer,
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      final rpc = GossipSubRpcCodec.decode(sent);
      expect(rpc.publish, hasLength(1));
      expect(utf8.decode(rpc.publish.single.data!), 'cached content');
      expect(rpc.publish.single.signature, equals(msg.signature));
    });
  });

  group('remaining gossipsub branches', () {
    late Ed25519Signer signer;
    late SimpleKeyPair authorKeyPair;
    late Uint8List authorPubKey;
    late PeerId authorPeerId;
    late String authorPeerIdStr;

    setUp(() async {
      signer = Ed25519Signer();
      authorKeyPair = await signer.generateKeyPair();
      authorPubKey = await signer.extractPublicKeyBytes(authorKeyPair);
      authorPeerId = PeerId.fromPublicKey(authorPubKey, type: 'Ed25519');
      authorPeerIdStr = authorPeerId.toBase58();
    });

    /// Reads a private field on [instance] via mirrors — used only to seed
    /// bounded collections that are impractical to fill through the public
    /// API (caps of 256–1024 entries).
    T privateField<T>(Object instance, String name) {
      final instanceMirror = mirrors.reflect(instance);
      final library = instanceMirror.type.owner! as mirrors.LibraryMirror;
      return instanceMirror
              .getField(mirrors.MirrorSystem.getSymbol(name, library))
              .reflectee
          as T;
    }

    /// Builds a spec-conformant signed gossipsub message.
    Future<GossipSubMessage> signedMessage({
      required SimpleKeyPair keyPair,
      required Uint8List from,
      required String topic,
      required String content,
      int seq = 1,
      Uint8List? keyField,
    }) async {
      final msg = GossipSubMessage(
        from: from,
        data: Uint8List.fromList(utf8.encode(content)),
        seqno: _seqno(seq),
        topic: topic,
        key: keyField,
      );
      msg.signature = await signer.sign(gossipSubSigningPayload(msg), keyPair);
      msg.key = keyField;
      return msg;
    }

    test('rejects unsigned unsubscribe announcements in strict mode', () async {
      await client.start();
      final handler = handlerFor('pubsub');

      handler(
        NetworkPacket(
          srcPeerId: 'QmAnnouncer',
          datagram: Uint8List.fromList(utf8.encode('unsubscribe:t1')),
        ),
      );
      await flush();

      expect(client.peersForTopic('t1'), isNot(contains('QmAnnouncer')));
    });

    test('signed ihave resolves the sender key from the registry and the '
        'reply iwant is signed', () async {
      final localKeyPair = await signer.generateKeyPair();
      final localPub = await signer.extractPublicKeyBytes(localKeyPair);
      final localId = PeerId.fromPublicKey(
        localPub,
        type: 'Ed25519',
      ).toBase58();
      final keyedClient = PubSubClient(
        mockRouter,
        localId,
        keyPair: localKeyPair,
      );

      // The control message carries no inline key, so verification must
      // fall back to the registry.
      keyedClient.keyRegistry.registerPublicKey(authorPeerIdStr, authorPubKey);

      await keyedClient.start();
      final handler = handlerFor('pubsub');
      when(mockRouter.isConnectedPeer(authorPeerIdStr)).thenReturn(true);

      final sig = await signer.sign(utf8.encode('ihave:topic1'), authorKeyPair);
      handler(
        NetworkPacket(
          srcPeerId: authorPeerIdStr,
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'action': 'ihave',
                'sender': authorPeerIdStr,
                'topic': 'topic1',
                'msgIds': ['m1'],
                'ed25519_signature': base64Encode(sig),
              }),
            ),
          ),
        ),
      );
      await flush();

      final sent =
          verify(
                mockRouter.sendMessage(
                  authorPeerIdStr,
                  captureAny,
                  protocolId: 'pubsub',
                ),
              ).captured.last
              as Uint8List;
      final iwant = jsonDecode(utf8.decode(sent)) as Map<String, dynamic>;
      expect(iwant['action'], 'iwant');
      expect(iwant['msgIds'], contains('m1'));
      expect(iwant['ed25519_signature'], isNotEmpty);
      expect(iwant['pubkey'], isNotEmpty);
      await keyedClient.stop();
    });

    test('evicts the oldest gossipsub peer beyond the cap', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      final peers = privateField<Set<String>>(client, '_gossipsubPeers');
      for (var i = 0; i < 1024; i++) {
        peers.add('peer-$i');
      }

      deliverGossipSub(handler, 'new-peer', GossipSubRpc());
      await flush();

      expect(peers, contains('new-peer'));
      expect(peers.length, 1024);
    });

    test(
      'router errors during publish handling are logged, not thrown',
      () async {
        final laxClient = PubSubClient(
          mockRouter,
          localPeerId,
          strictAuthentication: false,
        );
        await laxClient.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer(any)).thenThrow(StateError('boom'));

        final msg = GossipSubMessage(
          from: Uint8List.fromList([9, 9]),
          data: Uint8List.fromList(utf8.encode('x')),
          seqno: _seqno(1),
          topic: 't',
        );
        deliverGossipSub(handler, 'peer-x', GossipSubRpc(publish: [msg]));
        await flush();
        await laxClient.stop();
      },
    );

    test('rejects gossipsub publishes missing topic or from', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      var delivered = false;
      final sub = client.messagesStream.listen((_) => delivered = true);

      deliverGossipSub(
        handler,
        'peer-x',
        GossipSubRpc(
          publish: [
            GossipSubMessage(
              from: Uint8List.fromList([9, 9]),
              data: Uint8List.fromList(utf8.encode('x')),
              seqno: _seqno(1),
              topic: '',
            ),
          ],
        ),
      );
      deliverGossipSub(
        handler,
        'peer-x',
        GossipSubRpc(
          publish: [
            GossipSubMessage(
              data: Uint8List.fromList(utf8.encode('x')),
              seqno: _seqno(1),
              topic: 't',
            ),
          ],
        ),
      );
      await flush();

      expect(delivered, isFalse);
      await sub.cancel();
    });

    test(
      'rejects an unsigned publish when the author key is registered',
      () async {
        client.keyRegistry.registerPublicKey(authorPeerIdStr, authorPubKey);
        await client.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer('peer-x')).thenReturn(true);

        var delivered = false;
        final sub = client.messagesStream.listen((_) => delivered = true);
        deliverGossipSub(
          handler,
          'peer-x',
          GossipSubRpc(
            publish: [
              GossipSubMessage(
                from: authorPeerId.value,
                data: Uint8List.fromList(utf8.encode('x')),
                seqno: _seqno(1),
                topic: 't',
              ),
            ],
          ),
        );
        await flush();

        expect(delivered, isFalse);
        await sub.cancel();
      },
    );

    test('evicts the oldest cached gossipsub message beyond the cap', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      final cache = privateField<Map<String, Uint8List>>(
        laxClient,
        '_gossipsubMessageCache',
      );
      for (var i = 0; i < 1024; i++) {
        cache['id$i'] = Uint8List(0);
      }
      when(mockRouter.isConnectedPeer('peer-x')).thenReturn(true);

      final msg = GossipSubMessage(
        from: Uint8List.fromList([9, 9]),
        data: Uint8List.fromList(utf8.encode('x')),
        seqno: _seqno(1),
        topic: 't',
      );
      deliverGossipSub(handler, 'peer-x', GossipSubRpc(publish: [msg]));
      await flush();

      expect(cache.length, 1024);
      await laxClient.stop();
    });

    test('forwards publishes to gossipsub peers, honoring IDONTWANT', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer('src')).thenReturn(true);

      // peerA and peerB join the mesh for the topic and speak gossipsub.
      for (final peer in ['peer-a', 'peer-b']) {
        deliverGossipSub(
          handler,
          peer,
          GossipSubRpc(
            control: GossipSubControl(graft: [GossipSubGraft(topicId: 't')]),
          ),
        );
      }
      // The source peer only needs gossipsub capability.
      deliverGossipSub(handler, 'src', GossipSubRpc());
      await flush();

      // peerB opted out of this specific message ID.
      final msg = GossipSubMessage(
        from: Uint8List.fromList([9, 9]),
        data: Uint8List.fromList(utf8.encode('fwd')),
        seqno: _seqno(1),
        topic: 't',
      );
      deliverGossipSub(
        handler,
        'peer-b',
        GossipSubRpc(
          control: GossipSubControl(
            idontwant: [
              GossipSubIDontWant(messageIds: [gossipSubDefaultMessageId(msg)]),
            ],
          ),
        ),
      );
      await flush();
      clearInteractions(mockRouter);

      deliverGossipSub(handler, 'src', GossipSubRpc(publish: [msg]));
      await flush();

      verify(
        mockRouter.sendMessage('peer-a', any, protocolId: _meshsub),
      ).called(1);
      verifyNever(mockRouter.sendMessage('peer-b', any, protocolId: _meshsub));
      await laxClient.stop();
    });

    test('IWANT serves cached messages and drops corrupted entries', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      final cache = privateField<Map<String, Uint8List>>(
        laxClient,
        '_gossipsubMessageCache',
      );

      final msg = GossipSubMessage(
        from: Uint8List.fromList([9, 9]),
        data: Uint8List.fromList(utf8.encode('cached')),
        seqno: _seqno(2),
        topic: 't',
      );
      final msgId = gossipSubDefaultMessageId(msg);
      cache[hex.encode(msgId)] = GossipSubRpcCodec.encodeMessage(msg);
      // Corrupted entry: decodes to a FormatException on serve.
      cache['aa'] = Uint8List.fromList([0xFF]);

      deliverGossipSub(
        handler,
        'peer-x',
        GossipSubRpc(
          control: GossipSubControl(
            iwant: [
              GossipSubIWant(
                messageIds: [
                  msgId,
                  Uint8List.fromList([0xAA]),
                ],
              ),
            ],
          ),
        ),
      );
      await flush();

      expect(cache.containsKey('aa'), isFalse);
      final sent =
          verify(
                mockRouter.sendMessage(
                  'peer-x',
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      expect(GossipSubRpcCodec.decode(sent).publish, hasLength(1));
      await laxClient.stop();
    });

    test('IDONTWANT beyond the per-peer cap evicts oldest ids', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      final ids1 = List.generate(
        512,
        (i) => Uint8List.fromList([i & 0xFF, i >> 8]),
      );
      final ids2 = List.generate(
        512,
        (i) => Uint8List.fromList([i & 0xFF, (i >> 8) | 0x80]),
      );
      deliverGossipSub(
        handler,
        'peer-x',
        GossipSubRpc(
          control: GossipSubControl(
            idontwant: [
              GossipSubIDontWant(messageIds: ids1),
              GossipSubIDontWant(messageIds: ids2),
            ],
          ),
        ),
      );
      await flush();

      final map = privateField<Map<String, Set<String>>>(client, '_idontwant');
      expect(map['peer-x']!.length, 512);
    });

    test('IDONTWANT beyond the peer cap evicts the oldest peer', () async {
      await client.start();
      final handler = handlerFor(_meshsub);
      final map = privateField<Map<String, Set<String>>>(client, '_idontwant');
      for (var i = 0; i < 256; i++) {
        map['p$i'] = <String>{};
      }

      deliverGossipSub(
        handler,
        'new-peer',
        GossipSubRpc(
          control: GossipSubControl(
            idontwant: [
              GossipSubIDontWant(
                messageIds: [
                  Uint8List.fromList([1]),
                ],
              ),
            ],
          ),
        ),
      );
      await flush();

      expect(map.length, 256);
      expect(map, isNot(contains('p0')));
    });

    test('IHAVE without a topicId checks every seen topic', () async {
      final laxClient = PubSubClient(
        mockRouter,
        localPeerId,
        strictAuthentication: false,
      );
      await laxClient.start();
      final handler = handlerFor(_meshsub);
      when(mockRouter.isConnectedPeer('src')).thenReturn(true);

      final msg = GossipSubMessage(
        from: Uint8List.fromList([9, 9]),
        data: Uint8List.fromList(utf8.encode('x')),
        seqno: _seqno(1),
        topic: 't',
      );
      deliverGossipSub(handler, 'src', GossipSubRpc(publish: [msg]));
      await flush();
      clearInteractions(mockRouter);

      // The already-seen ID under a null topic hits the fallback scan.
      deliverGossipSub(
        handler,
        'src',
        GossipSubRpc(
          control: GossipSubControl(
            ihave: [
              GossipSubIHave(messageIds: [gossipSubDefaultMessageId(msg)]),
            ],
          ),
        ),
      );
      await flush();

      verifyNever(mockRouter.sendMessage('src', any, protocolId: _meshsub));
      await laxClient.stop();
    });

    test(
      'signed publish resolves a registered key for non-identity from',
      () async {
        await client.start();
        final handler = handlerFor(_meshsub);
        when(mockRouter.isConnectedPeer('src')).thenReturn(true);

        // A sha256-multihash (Qm-style) author: the key is not embedded, the
        // message carries no key field, so verification falls back to the
        // registry. `registerPublicKey` only accepts identity peer IDs, so
        // the verified binding is injected directly.
        final digest = _sha256MultihashPeerId(authorPubKey);
        final qmSender = Base58().encode(digest);
        privateField<Map<String, Uint8List>>(
          client.keyRegistry,
          '_keys',
        )[qmSender] = authorPubKey;

        final msg = await signedMessage(
          keyPair: authorKeyPair,
          from: digest,
          topic: 'reg-key-topic',
          content: 'registry key content',
        );

        final received = client.messagesStream.first;
        deliverGossipSub(handler, 'src', GossipSubRpc(publish: [msg]));

        final delivered = await received;
        expect(delivered.content, 'registry key content');
        expect(delivered.sender, qmSender);
      },
    );

    test(
      'subscribe announces SubOpts and GRAFT to gossipsub topic peers',
      () async {
        await client.start();
        final handler = handlerFor(_meshsub);

        // kuboPeer speaks gossipsub and announced interest in the topic.
        deliverGossipSub(
          handler,
          kuboPeer,
          GossipSubRpc(
            control: GossipSubControl(graft: [GossipSubGraft(topicId: 't')]),
          ),
        );
        await flush();
        clearInteractions(mockRouter);

        await client.subscribe('t');
        await flush();

        final sent =
            verify(
                  mockRouter.sendMessage(
                    kuboPeer,
                    captureAny,
                    protocolId: _meshsub,
                  ),
                ).captured.last
                as Uint8List;
        final rpc = GossipSubRpcCodec.decode(sent);
        expect(rpc.subscriptions.single.topicId, 't');
        expect(rpc.subscriptions.single.subscribe, isTrue);
        expect(rpc.control!.graft.single.topicId, 't');
      },
    );

    test('gossipsub send failures are logged and swallowed', () async {
      await client.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(handler, kuboPeer, GossipSubRpc());
      await flush();

      when(
        mockRouter.sendMessage(kuboPeer, any, protocolId: _meshsub),
      ).thenThrow(StateError('network down'));

      // The subscription announcement fails on send; subscribe must not.
      await client.subscribe('t2');
      await flush();
      expect(client.subscribedTopics, contains('t2'));
    });

    test(
      'publish includes the key field for a non-identity local peer ID',
      () async {
        final localKeyPair = await signer.generateKeyPair();
        final keyedClient = PubSubClient(
          mockRouter,
          localPeerId, // Qm-style: no embedded public key
          keyPair: localKeyPair,
        );
        await keyedClient.start();
        final handler = handlerFor(_meshsub);

        deliverGossipSub(handler, kuboPeer, GossipSubRpc());
        await flush();

        keyedClient.graftPeer(kuboPeer);
        await keyedClient.publish('t', 'signed publish');

        final sent =
            verify(
                  mockRouter.sendMessage(
                    kuboPeer,
                    captureAny,
                    protocolId: _meshsub,
                  ),
                ).captured.last
                as Uint8List;
        final msg = GossipSubRpcCodec.decode(sent).publish.single;
        expect(msg.key, isNotNull);
        expect(
          unmarshalGossipSubPublicKey(msg.key!),
          equals(await signer.extractPublicKeyBytes(localKeyPair)),
        );
        expect(msg.signature, isNotNull);
        await keyedClient.stop();
      },
    );

    test('publish proceeds unsigned when signing throws', () async {
      final realKeyPair = await signer.generateKeyPair();
      final keyedClient = PubSubClient(
        mockRouter,
        localPeerId,
        keyPair: _SignOnlyFailsKeyPair(await realKeyPair.extractPublicKey()),
      );
      await keyedClient.start();
      final handler = handlerFor(_meshsub);

      deliverGossipSub(handler, kuboPeer, GossipSubRpc());
      await flush();

      keyedClient.graftPeer(kuboPeer);
      await keyedClient.publish('t', 'unsigned after sign failure');

      final sent =
          verify(
                mockRouter.sendMessage(
                  kuboPeer,
                  captureAny,
                  protocolId: _meshsub,
                ),
              ).captured.last
              as Uint8List;
      final msg = GossipSubRpcCodec.decode(sent).publish.single;
      expect(msg.signature, isNull);
      await keyedClient.stop();
    });
  });
}

/// A [SimpleKeyPair] whose private key material is unavailable — public-key
/// lookups succeed but any signing attempt throws. Exercises the
/// signing-failure path in gossipsub publish.
class _SignOnlyFailsKeyPair implements SimpleKeyPair {
  _SignOnlyFailsKeyPair(this._publicKey);

  final SimplePublicKey _publicKey;

  @override
  bool get hasBeenDestroyed => false;

  @override
  void destroy() {}

  @override
  Future<SimpleKeyPairData> extract() =>
      throw StateError('private key unavailable');

  @override
  Future<List<int>> extractPrivateKeyBytes() =>
      throw StateError('private key unavailable');

  @override
  Future<SimplePublicKey> extractPublicKey() async => _publicKey;
}

/// Builds the sha256-multihash peer ID bytes (`0x12 0x20 <digest>`) for an
/// Ed25519 public key — the `Qm...` form used when the key is not embedded.
Uint8List _sha256MultihashPeerId(Uint8List publicKey) {
  final digest = sha256.convert(marshalGossipSubEd25519PublicKey(publicKey));
  return Uint8List.fromList([0x12, 0x20, ...digest.bytes]);
}
