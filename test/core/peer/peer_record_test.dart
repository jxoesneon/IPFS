// test/core/peer/peer_record_test.dart
//
// Tests for signed peer records (libp2p RFC 0002).

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/peer/peer_record.dart';
import 'package:dart_ipfs/src/core/peer/peer_record_pb.dart';
import 'package:test/test.dart';

void main() {
  group('PeerRecordPb', () {
    test('encode/decode roundtrip preserves all fields', () {
      final record = PeerRecordPb(
        peerId: Uint8List.fromList([1, 2, 3, 4, 5]),
        addresses: [
          Uint8List.fromList([10, 20, 30]),
          Uint8List.fromList([40, 50, 60, 70]),
        ],
        timestamp: 1700000000000000,
        seq: 42,
      );

      final encoded = record.encode();
      final decoded = PeerRecordPb.decode(encoded);

      expect(decoded, equals(record));
      expect(decoded.peerId, equals(record.peerId));
      expect(decoded.addresses.length, equals(2));
      expect(decoded.timestamp, equals(1700000000000000));
      expect(decoded.seq, equals(42));
    });

    test('encode/decode with empty addresses', () {
      final record = PeerRecordPb(
        peerId: Uint8List.fromList([0xFF]),
        addresses: [],
        timestamp: 0,
        seq: 1,
      );

      final encoded = record.encode();
      final decoded = PeerRecordPb.decode(encoded);

      expect(decoded, equals(record));
      expect(decoded.addresses, isEmpty);
    });

    test('encode/decode with large seq and timestamp values', () {
      final record = PeerRecordPb(
        peerId: Uint8List(32),
        addresses: [
          Uint8List.fromList([1]),
        ],
        timestamp: 0xFFFFFFFFFFFFFF,
        seq: 0xFFFFFFFF,
      );

      final encoded = record.encode();
      final decoded = PeerRecordPb.decode(encoded);

      expect(decoded.timestamp, equals(0xFFFFFFFFFFFFFF));
      expect(decoded.seq, equals(0xFFFFFFFF));
    });

    test('toString contains useful info', () {
      final record = PeerRecordPb(
        peerId: Uint8List.fromList([1, 2]),
        addresses: [
          Uint8List.fromList([3, 4]),
        ],
        timestamp: 100,
        seq: 5,
      );
      final s = record.toString();
      expect(s, contains('seq: 5'));
      expect(s, contains('addresses: 1'));
    });
  });

  group('PublicKeyPb', () {
    test('encode/decode roundtrip for Ed25519', () {
      final key = PublicKeyPb(
        type: KeyType.ed25519,
        data: Uint8List.fromList(List.generate(32, (i) => i)),
      );

      final encoded = key.encode();
      final decoded = PublicKeyPb.decode(encoded);

      expect(decoded, equals(key));
      expect(decoded.type, equals(KeyType.ed25519));
      expect(decoded.data.length, equals(32));
    });

    test('KeyType.fromValue throws for unknown', () {
      expect(() => KeyType.fromValue(99), throwsArgumentError);
    });

    test('KeyType enum values are correct', () {
      expect(KeyType.rsa.value, equals(0));
      expect(KeyType.ed25519.value, equals(1));
      expect(KeyType.secp256k1.value, equals(2));
      expect(KeyType.ecdsa.value, equals(3));
    });
  });

  group('EnvelopePb', () {
    test('encode/decode roundtrip', () {
      final pubKey = PublicKeyPb(
        type: KeyType.ed25519,
        data: Uint8List.fromList(List.generate(32, (i) => i)),
      );
      final env = EnvelopePb(
        publicKey: pubKey,
        payloadType: Uint8List.fromList([0x03, 0x01]),
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
        signature: Uint8List.fromList(List.generate(64, (i) => i)),
      );

      final encoded = env.encode();
      final decoded = EnvelopePb.decode(encoded);

      expect(decoded, equals(env));
      expect(decoded.publicKey.type, equals(KeyType.ed25519));
      expect(decoded.payload, equals(env.payload));
      expect(decoded.signature.length, equals(64));
    });
  });

  group('Varint encoding', () {
    test('encodeVarint for small values', () {
      expect(encodeVarint(0), equals([0]));
      expect(encodeVarint(1), equals([1]));
      expect(encodeVarint(127), equals([127]));
    });

    test('encodeVarint for multi-byte values', () {
      expect(encodeVarint(128), equals([0x80, 0x01]));
      expect(encodeVarint(300), equals([0xAC, 0x02]));
    });

    test('decodeVarint roundtrip', () {
      for (final value in [0, 1, 127, 128, 300, 16384, 1000000]) {
        final encoded = Uint8List.fromList(encodeVarint(value));
        final (decoded, consumed) = decodeVarint(encoded, 0);
        expect(decoded, equals(value));
        expect(consumed, equals(encoded.length));
      }
    });

    test('decodeVarint throws on truncated', () {
      expect(
        () => decodeVarint(Uint8List.fromList([0x80]), 0),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PeerRecordSigner', () {
    late SimpleKeyPair keyPair;
    late Uint8List publicKeyBytes;
    late Uint8List peerIdBytes;
    late PeerRecordSigner signer;

    setUp(() async {
      final ed25519 = Ed25519();
      keyPair = await ed25519.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      publicKeyBytes = Uint8List.fromList(pubKey.bytes);
      // Use the public key bytes as a stand-in for peer ID bytes in tests.
      peerIdBytes = Uint8List.fromList(pubKey.bytes);

      signer = PeerRecordSigner(
        keyPair: keyPair,
        peerIdBytes: peerIdBytes,
        publicKeyBytes: publicKeyBytes,
      );
    });

    test('create produces a valid signed peer record', () async {
      final addresses = [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5, 6]),
      ];

      final spr = await signer.create(addresses);

      expect(spr.record.peerId, equals(peerIdBytes));
      expect(spr.record.addresses.length, equals(2));
      expect(spr.record.seq, equals(1));
      expect(spr.record.timestamp, greaterThan(0));
      expect(spr.envelope.publicKey.type, equals(KeyType.ed25519));
      expect(spr.envelope.publicKey.data, equals(publicKeyBytes));
      expect(spr.envelope.signature.length, equals(64));
      expect(spr.envelope.payloadType, equals(peerRecordPayloadType));
    });

    test('seq increments on each create', () async {
      final spr1 = await signer.create([]);
      final spr2 = await signer.create([]);
      final spr3 = await signer.create([]);

      expect(spr1.record.seq, equals(1));
      expect(spr2.record.seq, equals(2));
      expect(spr3.record.seq, equals(3));
    });

    test('envelope bytes can be verified', () async {
      final addresses = [
        Uint8List.fromList([10, 20, 30]),
      ];
      final spr = await signer.create(addresses);

      final verifier = PeerRecordVerifier();
      final result = await verifier.verify(spr.envelopeBytes);

      expect(result, isNotNull);
      expect(result!.record.peerId, equals(peerIdBytes));
      expect(result.record.addresses.length, equals(1));
      expect(result.record.seq, equals(1));
    });

    test('verifyPeerId matches', () async {
      final spr = await signer.create([]);
      final verifier = PeerRecordVerifier();
      final verified = await verifier.verify(spr.envelopeBytes);

      expect(verifier.verifyPeerId(verified!, peerIdBytes), isTrue);
      expect(
        verifier.verifyPeerId(verified, Uint8List.fromList([0, 0, 0])),
        isFalse,
      );
    });

    test('tampered signature fails verification', () async {
      final spr = await signer.create([
        Uint8List.fromList([1]),
      ]);

      // Tamper with the signature.
      final tamperedSig = Uint8List.fromList(spr.envelope.signature);
      tamperedSig[0] ^= 0xFF;

      final tamperedEnv = EnvelopePb(
        publicKey: spr.envelope.publicKey,
        payloadType: spr.envelope.payloadType,
        payload: spr.envelope.payload,
        signature: tamperedSig,
      );

      final verifier = PeerRecordVerifier();
      final result = await verifier.verifyEnvelope(tamperedEnv);

      expect(result, isNull);
    });

    test('tampered payload fails verification', () async {
      final spr = await signer.create([
        Uint8List.fromList([1]),
      ]);

      // Tamper with the payload.
      final tamperedPayload = Uint8List.fromList(spr.envelope.payload);
      tamperedPayload[0] ^= 0xFF;

      final tamperedEnv = EnvelopePb(
        publicKey: spr.envelope.publicKey,
        payloadType: spr.envelope.payloadType,
        payload: tamperedPayload,
        signature: spr.envelope.signature,
      );

      final verifier = PeerRecordVerifier();
      final result = await verifier.verifyEnvelope(tamperedEnv);

      expect(result, isNull);
    });

    test('wrong key type fails verification', () async {
      final spr = await signer.create([]);

      final wrongKeyEnv = EnvelopePb(
        publicKey: PublicKeyPb(
          type: KeyType.rsa,
          data: spr.envelope.publicKey.data,
        ),
        payloadType: spr.envelope.payloadType,
        payload: spr.envelope.payload,
        signature: spr.envelope.signature,
      );

      final verifier = PeerRecordVerifier();
      final result = await verifier.verifyEnvelope(wrongKeyEnv);

      expect(result, isNull);
    });

    test('wrong payload type fails verification', () async {
      final spr = await signer.create([]);

      final wrongTypeEnv = EnvelopePb(
        publicKey: spr.envelope.publicKey,
        payloadType: Uint8List.fromList([0x99, 0x99]),
        payload: spr.envelope.payload,
        signature: spr.envelope.signature,
      );

      final verifier = PeerRecordVerifier();
      final result = await verifier.verifyEnvelope(wrongTypeEnv);

      expect(result, isNull);
    });

    test('malformed envelope bytes return null', () async {
      final verifier = PeerRecordVerifier();
      final result = await verifier.verify(Uint8List.fromList([0xFF, 0xFF]));
      expect(result, isNull);
    });

    test('buildSigningBuffer produces correct format', () {
      final buffer = PeerRecordSigner.buildSigningBuffer(
        domain: 'test-domain',
        payloadType: Uint8List.fromList([0x03, 0x01]),
        payload: Uint8List.fromList([1, 2, 3]),
      );

      // domain "test-domain" = 11 bytes
      // encodeVarint(11) = [11]
      // domain bytes = 11 bytes
      // encodeVarint(2) = [2]
      // payload_type = 2 bytes
      // encodeVarint(3) = [3]
      // payload = 3 bytes
      expect(buffer[0], equals(11));
      expect(buffer.length, equals(1 + 11 + 1 + 2 + 1 + 3));
    });
  });

  group('SignedPeerRecord', () {
    test('toString contains useful info', () async {
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final publicKeyBytes = Uint8List.fromList(pubKey.bytes);

      final signer = PeerRecordSigner(
        keyPair: keyPair,
        peerIdBytes: publicKeyBytes,
        publicKeyBytes: publicKeyBytes,
      );

      final spr = await signer.create([
        Uint8List.fromList([1, 2]),
      ]);
      final s = spr.toString();
      expect(s, contains('seq: 1'));
      expect(s, contains('addresses: 1'));
    });

    test('envelopeBytes matches envelope.encode()', () async {
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final publicKeyBytes = Uint8List.fromList(pubKey.bytes);

      final signer = PeerRecordSigner(
        keyPair: keyPair,
        peerIdBytes: publicKeyBytes,
        publicKeyBytes: publicKeyBytes,
      );

      final spr = await signer.create([]);
      expect(spr.envelopeBytes, equals(spr.envelope.encode()));
    });
  });
}
