// Unit tests for the hand-rolled gossipsub protobuf RPC codec.
//
// The codec must round-trip every record kind in the libp2p pubsub RPC
// schema, skip unknown fields, and reject malformed or oversized frames.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/gossipsub/gossipsub_rpc.dart';
import 'package:test/test.dart';

Uint8List _u8(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  group('GossipSubRpcCodec round-trips', () {
    test('subscriptions', () {
      final rpc = GossipSubRpc(
        subscriptions: [
          GossipSubSubOpts(subscribe: true, topicId: 'topic-a'),
          GossipSubSubOpts(subscribe: false, topicId: 'topic-b'),
        ],
      );

      final decoded = GossipSubRpcCodec.decode(GossipSubRpcCodec.encode(rpc));

      expect(decoded.subscriptions, hasLength(2));
      expect(decoded.subscriptions[0].subscribe, isTrue);
      expect(decoded.subscriptions[0].topicId, 'topic-a');
      expect(decoded.subscriptions[1].subscribe, isFalse);
      expect(decoded.subscriptions[1].topicId, 'topic-b');
      expect(decoded.publish, isEmpty);
      expect(decoded.control, isNull);
    });

    test('publish messages with all fields', () {
      final msg = GossipSubMessage(
        from: _u8([0x00, 0x24, 1, 2, 3]),
        data: _u8(utf8.encode('hello mesh')),
        seqno: _u8([0, 0, 0, 0, 0, 0, 0, 7]),
        topic: 'news',
        signature: _u8(List.filled(64, 0xAB)),
        key: _u8([0x08, 0x01, 0x12, 0x20, ...List.filled(32, 9)]),
      );

      final decoded = GossipSubRpcCodec.decode(
        GossipSubRpcCodec.encode(GossipSubRpc(publish: [msg])),
      );

      expect(decoded.publish, hasLength(1));
      final m = decoded.publish.single;
      expect(m.from, equals(msg.from));
      expect(m.data, equals(msg.data));
      expect(m.seqno, equals(msg.seqno));
      expect(m.topic, 'news');
      expect(m.signature, equals(msg.signature));
      expect(m.key, equals(msg.key));
    });

    test('control messages of every kind', () {
      final rpc = GossipSubRpc(
        control: GossipSubControl(
          ihave: [
            GossipSubIHave(
              topicId: 't1',
              messageIds: [
                _u8([1, 2]),
                _u8([0xFF, 0x00]),
              ],
            ),
          ],
          iwant: [
            GossipSubIWant(
              messageIds: [
                _u8([9, 9, 9]),
              ],
            ),
          ],
          graft: [GossipSubGraft(topicId: 't2')],
          prune: [GossipSubPrune(topicId: 't3', backoff: 30)],
          idontwant: [
            GossipSubIDontWant(
              messageIds: [
                _u8([4, 5, 6]),
              ],
            ),
          ],
        ),
      );

      final decoded = GossipSubRpcCodec.decode(GossipSubRpcCodec.encode(rpc));
      final control = decoded.control!;

      expect(control.ihave.single.topicId, 't1');
      expect(control.ihave.single.messageIds, hasLength(2));
      // Message IDs are opaque bytes — 0xFF is not valid UTF-8 and must
      // survive the round trip untouched.
      expect(control.ihave.single.messageIds[1], equals(_u8([0xFF, 0x00])));
      expect(control.iwant.single.messageIds.single, equals(_u8([9, 9, 9])));
      expect(control.graft.single.topicId, 't2');
      expect(control.prune.single.topicId, 't3');
      expect(control.prune.single.backoff, 30);
      expect(
        control.idontwant.single.messageIds.single,
        equals(_u8([4, 5, 6])),
      );
    });

    test('emits the exact protobuf wire bytes a libp2p peer produces', () {
      // Golden vectors computed by hand from the proto2 schema — the same
      // bytes go-libp2p-pubsub and js-libp2p emit for equivalent RPCs.

      // RPC{subscriptions: [{subscribe: true, topicid: 't'}]}
      expect(
        GossipSubRpcCodec.encode(
          GossipSubRpc(
            subscriptions: [GossipSubSubOpts(subscribe: true, topicId: 't')],
          ),
        ),
        equals(
          _u8([
            0x0A, 0x05, // field 1, len 5
            0x08, 0x01, // subscribe = true
            0x12, 0x01, 0x74, // topicid = 't'
          ]),
        ),
      );

      // RPC{publish: [Message{from: [1], data: [2], seqno: [3], topic: 'x'}]}
      expect(
        GossipSubRpcCodec.encode(
          GossipSubRpc(
            publish: [
              GossipSubMessage(
                from: _u8([0x01]),
                data: _u8([0x02]),
                seqno: _u8([0x03]),
                topic: 'x',
              ),
            ],
          ),
        ),
        equals(
          _u8([
            0x12, 0x0C, // field 2, len 12
            0x0A, 0x01, 0x01, // from
            0x12, 0x01, 0x02, // data
            0x1A, 0x01, 0x03, // seqno
            0x22, 0x01, 0x78, // topic = 'x'
          ]),
        ),
      );

      // RPC{control: {graft: [{topicID: 'g'}]}}
      expect(
        GossipSubRpcCodec.encode(
          GossipSubRpc(
            control: GossipSubControl(graft: [GossipSubGraft(topicId: 'g')]),
          ),
        ),
        equals(
          _u8([
            0x1A, 0x05, // field 3 (control), len 5
            0x1A, 0x03, // graft (field 3), len 3
            0x0A, 0x01, 0x67, // topicID = 'g'
          ]),
        ),
      );
    });

    test('decodes golden bytes emitted by the reference schema', () {
      // IHAVE{topicID: 't', messageIDs: [[0xDE, 0xAD]]} inside an RPC.
      final frame = _u8([
        0x1A, 0x09, // control, len 9
        0x0A, 0x07, // ihave (field 1), len 7
        0x0A, 0x01, 0x74, // topicID = 't'
        0x12, 0x02, 0xDE, 0xAD, // messageIDs
      ]);
      final decoded = GossipSubRpcCodec.decode(frame);
      final ihave = decoded.control!.ihave.single;
      expect(ihave.topicId, 't');
      expect(ihave.messageIds.single, equals(_u8([0xDE, 0xAD])));
    });

    test('full envelope', () {
      final rpc = GossipSubRpc(
        subscriptions: [GossipSubSubOpts(subscribe: true, topicId: 't')],
        publish: [
          GossipSubMessage(
            from: _u8([1]),
            data: _u8([2]),
            seqno: _u8([3]),
            topic: 't',
          ),
        ],
        control: GossipSubControl(graft: [GossipSubGraft(topicId: 't')]),
      );

      final decoded = GossipSubRpcCodec.decode(GossipSubRpcCodec.encode(rpc));
      expect(decoded.subscriptions.single.topicId, 't');
      expect(decoded.publish.single.topic, 't');
      expect(decoded.control!.graft.single.topicId, 't');
    });
  });

  group('GossipSubRpcCodec robustness', () {
    test('empty input decodes to an empty RPC', () {
      final decoded = GossipSubRpcCodec.decode(Uint8List(0));
      expect(decoded.subscriptions, isEmpty);
      expect(decoded.publish, isEmpty);
      expect(decoded.control, isNull);
    });

    test('skips unknown top-level fields', () {
      final frame = BytesBuilder(copy: false)
        // Field 99, varint wire type, value 42 — must be skipped.
        ..add(_u8([0xF8, 0x06, 0x2A]))
        // Field 1: SubOpts{subscribe: true, topicid: 'x'}.
        ..add(_u8([0x0A, 0x05, 0x08, 0x01, 0x12, 0x01, 0x78]));

      final decoded = GossipSubRpcCodec.decode(frame.takeBytes());
      expect(decoded.subscriptions.single.subscribe, isTrue);
      expect(decoded.subscriptions.single.topicId, 'x');
    });

    test('rejects truncated varint', () {
      expect(
        () => GossipSubRpcCodec.decode(_u8([0x0A, 0x80])),
        throwsFormatException,
      );
    });

    test('rejects length-delimited field exceeding frame', () {
      // Field 1 declares 100 bytes but the frame ends.
      expect(
        () => GossipSubRpcCodec.decode(_u8([0x0A, 0x64, 0x01, 0x02])),
        throwsFormatException,
      );
    });

    test('rejects frames over the maximum RPC size', () {
      final oversized = Uint8List(GossipSubRpcCodec.maxRpcSize + 1);
      expect(() => GossipSubRpcCodec.decode(oversized), throwsFormatException);
    });

    test('rejects unsupported wire types', () {
      // Field 1 with wire type 3 (group start) is not supported.
      expect(
        () => GossipSubRpcCodec.decode(_u8([0x0B, 0x0C])),
        throwsFormatException,
      );
    });

    test('rejects too many publish messages', () {
      final builder = BytesBuilder(copy: false);
      final emptyMsg = _u8([0x12, 0x00]); // field 2, zero-length message
      for (var i = 0; i < GossipSubRpcCodec.maxPublishMessages + 1; i++) {
        builder.add(emptyMsg);
      }
      expect(
        () => GossipSubRpcCodec.decode(builder.takeBytes()),
        throwsFormatException,
      );
    });

    test('rejects invalid UTF-8 in a topic string field', () {
      // Message{topic: <invalid utf8>} — field 4 of Message is a proto
      // `string` and must be valid UTF-8 like go-protobuf enforces.
      final inner = _u8([0x22, 0x02, 0xFF, 0xFF]); // topic = 0xFF 0xFF
      final frame = _u8([0x12, inner.length, ...inner]);
      expect(() => GossipSubRpcCodec.decode(frame), throwsFormatException);
    });
  });

  group('signature payload and message ID', () {
    test('signing payload uses the libp2p-pubsub prefix and excludes '
        'signature and key fields', () {
      final msg = GossipSubMessage(
        from: _u8([1, 2, 3]),
        data: _u8([4, 5]),
        seqno: _u8([6]),
        topic: 't',
        signature: _u8(List.filled(64, 7)),
        key: _u8([8, 8, 8]),
      );

      final payload = gossipSubSigningPayload(msg);
      final prefix = utf8.encode(kGossipSubSignPrefix);

      expect(payload.sublist(0, prefix.length), equals(prefix));
      final body = payload.sublist(prefix.length);
      // The body must equal the message encoding without sig/key fields.
      expect(
        body,
        equals(
          GossipSubRpcCodec.encodeMessage(
            msg,
            includeSignature: false,
            includeKey: false,
          ),
        ),
      );
    });

    test('default message ID is from || seqno', () {
      final msg = GossipSubMessage(from: _u8([1, 2]), seqno: _u8([3, 4, 5]));
      expect(gossipSubDefaultMessageId(msg), equals(_u8([1, 2, 3, 4, 5])));
    });
  });

  group('public key and peer ID helpers', () {
    test('marshal/unmarshal Ed25519 public key round-trips', () {
      final key = _u8(List.generate(32, (i) => i));
      final marshalled = marshalGossipSubEd25519PublicKey(key);
      expect(marshalled.sublist(0, 4), equals(_u8([0x08, 0x01, 0x12, 0x20])));
      expect(unmarshalGossipSubPublicKey(marshalled), equals(key));
    });

    test('unmarshal rejects non-Ed25519 or malformed keys', () {
      // Wrong key type (RSA = 0).
      expect(
        unmarshalGossipSubPublicKey(_u8([0x08, 0x00, 0x12, 0x00])),
        isNull,
      );
      // Truncated garbage.
      expect(unmarshalGossipSubPublicKey(_u8([0x08])), isNull);
      // 31-byte key material.
      expect(
        unmarshalGossipSubPublicKey(
          _u8([0x08, 0x01, 0x12, 0x1F, ...List.filled(31, 1)]),
        ),
        isNull,
      );
    });

    test('identity-multihash peer ID yields its embedded key', () {
      final key = _u8(List.generate(32, (i) => 0x40 + i));
      final peerId = PeerId.fromPublicKey(key, type: 'Ed25519');
      expect(gossipSubPeerIdPublicKey(peerId.value), equals(key));
      expect(gossipSubPeerIdMatchesKey(peerId.value, key), isTrue);
      expect(
        gossipSubPeerIdMatchesKey(peerId.value, _u8(List.filled(32, 0))),
        isFalse,
      );
    });

    test('sha256-multihash peer ID matches via hashed marshalled key', () {
      final key = _u8(List.generate(32, (i) => 0x80 + i));
      final digest = sha256.convert(marshalGossipSubEd25519PublicKey(key));
      final peerId = _u8([0x12, 0x20, ...digest.bytes]);

      // The key is not embedded, so extraction fails but matching works.
      expect(gossipSubPeerIdPublicKey(peerId), isNull);
      expect(gossipSubPeerIdMatchesKey(peerId, key), isTrue);
      expect(
        gossipSubPeerIdMatchesKey(peerId, _u8(List.filled(32, 0))),
        isFalse,
      );
    });
  });
}
