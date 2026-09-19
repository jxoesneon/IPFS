// Tests for PubSubClient's gossipsub wire interop: the protobuf RPC
// protocol spoken on /meshsub/1.1.0 and /meshsub/1.0.0 with Kubo/Helia/
// libp2p peers.
//
// Covered: protocol registration, capability discovery, SubOpts tracking,
// strict-signing verification (key field and identity peer IDs), forgery
// rejection, dedup, IHAVE/IWANT exchange, GRAFT/PRUNE, IDONTWANT, and the
// dual-stack publish path (protobuf to meshsub peers, JSON to the rest).

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show SimpleKeyPair;
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/gossipsub/gossipsub_rpc.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
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

      // Mesh membership: publishing now reaches the peer.
      await client.publish('t-graft', 'hi');
      verify(
        mockRouter.sendMessage(kuboPeer, any, protocolId: _meshsub),
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
}

/// Builds the sha256-multihash peer ID bytes (`0x12 0x20 <digest>`) for an
/// Ed25519 public key — the `Qm...` form used when the key is not embedded.
Uint8List _sha256MultihashPeerId(Uint8List publicKey) {
  final digest = sha256.convert(marshalGossipSubEd25519PublicKey(publicKey));
  return Uint8List.fromList([0x12, 0x20, ...digest.bytes]);
}
