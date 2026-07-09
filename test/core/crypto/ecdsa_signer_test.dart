// test/core/crypto/ecdsa_signer_test.dart
//
// Tests for the ECDSA signer and peer ID derivation.

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/ecdsa_signer.dart';
import 'package:dart_ipfs/src/core/peer/peer_record_pb.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:test/test.dart';

void main() {
  group('EcdsaSigner', () {
    late EcdsaSigner signer;

    setUp(() {
      signer = EcdsaSigner();
    });

    test('generateKeyPair produces valid P-256 key pair', () async {
      final keyPair = await signer.generateKeyPair();
      expect(keyPair.publicKey.Q, isNotNull);
      expect(keyPair.privateKey.d, isNotNull);
      expect(keyPair.publicKey.parameters!.domainName, equals('secp256r1'));
    });

    test('sign and verify roundtrip', () async {
      final keyPair = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final signature = await signer.sign(data, keyPair);
      expect(signature.length, greaterThan(0));

      final isValid = await signer.verify(data, signature, keyPair.publicKey);
      expect(isValid, isTrue);
    });

    test('verify fails with wrong data', () async {
      final keyPair = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3]);
      final sig = await signer.sign(data, keyPair);

      final isValid = await signer.verify(
        Uint8List.fromList([1, 2, 4]),
        sig,
        keyPair.publicKey,
      );
      expect(isValid, isFalse);
    });

    test('verify fails with wrong key', () async {
      final keyPair1 = await signer.generateKeyPair();
      final keyPair2 = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3]);
      final sig = await signer.sign(data, keyPair1);

      final isValid = await signer.verify(data, sig, keyPair2.publicKey);
      expect(isValid, isFalse);
    });

    test('verify fails with invalid signature bytes', () async {
      final keyPair = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3]);
      final invalidSig = Uint8List.fromList([0, 1, 2, 3]);

      final isValid = await signer.verify(data, invalidSig, keyPair.publicKey);
      expect(isValid, isFalse);
    });

    test('serializePublicKey produces valid DER', () async {
      final keyPair = await signer.generateKeyPair();
      final derBytes = signer.serializePublicKey(keyPair.publicKey);
      expect(derBytes.length, greaterThan(0));
      // DER sequence should start with 0x30
      expect(derBytes[0], equals(0x30));
    });

    test('deserializePublicKey reconstructs the same key', () async {
      final keyPair = await signer.generateKeyPair();
      final derBytes = signer.serializePublicKey(keyPair.publicKey);
      final reconstructed = signer.deserializePublicKey(derBytes);
      expect(
        reconstructed.Q!.getEncoded(false),
        equals(keyPair.publicKey.Q!.getEncoded(false)),
      );
    });

    test('derivePeerId returns non-empty base58 string', () async {
      final keyPair = await signer.generateKeyPair();
      final peerId = signer.derivePeerId(keyPair.publicKey);
      expect(peerId, isNotEmpty);
      // ECDSA P-256 keys are > 42 bytes when protobuf-encoded, so SHA-256
      expect(peerId.length, greaterThan(40));
      expect(peerId.startsWith('Qm'), isTrue);
    });

    test('derivePeerId is deterministic for same key', () async {
      final keyPair = await signer.generateKeyPair();
      final peerId1 = signer.derivePeerId(keyPair.publicKey);
      final peerId2 = signer.derivePeerId(keyPair.publicKey);
      expect(peerId1, equals(peerId2));
    });

    test('derivePeerId differs for different keys', () async {
      final keyPair1 = await signer.generateKeyPair();
      final keyPair2 = await signer.generateKeyPair();
      final peerId1 = signer.derivePeerId(keyPair1.publicKey);
      final peerId2 = signer.derivePeerId(keyPair2.publicKey);
      expect(peerId1, isNot(equals(peerId2)));
    });

    test('encodePublicKeyPb produces valid protobuf', () async {
      final keyPair = await signer.generateKeyPair();
      final pbBytes = signer.encodePublicKeyPb(keyPair.publicKey);
      expect(pbBytes.length, greaterThan(0));

      // Decode it back
      final decoded = signer.decodePublicKeyPb(pbBytes);
      expect(
        decoded.Q!.getEncoded(false),
        equals(keyPair.publicKey.Q!.getEncoded(false)),
      );
    });

    test('encodePublicKeyPb uses ECDSA key type', () async {
      final keyPair = await signer.generateKeyPair();
      final pbBytes = signer.encodePublicKeyPb(keyPair.publicKey);
      final pb = PublicKeyPb.decode(pbBytes);
      expect(pb.type, equals(KeyType.ecdsa));
    });

    test('decodePublicKeyPb rejects non-ECDSA key type', () async {
      final pb = PublicKeyPb(type: KeyType.ed25519, data: Uint8List(32));
      expect(() => signer.decodePublicKeyPb(pb.encode()), throwsArgumentError);
    });

    test('EcdsaKeyPair stores both keys', () async {
      final keyPair = await signer.generateKeyPair();
      expect(keyPair.publicKey, isA<ECPublicKey>());
      expect(keyPair.privateKey, isA<ECPrivateKey>());
    });

    test(
      'sign produces different signatures for same data (non-deterministic)',
      () async {
        final keyPair = await signer.generateKeyPair();
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);

        final sig1 = await signer.sign(data, keyPair);
        final sig2 = await signer.sign(data, keyPair);

        // ECDSA is non-deterministic (uses random k), so signatures should differ
        // But both should verify
        expect(sig1, isNot(equals(sig2)));
        expect(await signer.verify(data, sig1, keyPair.publicKey), isTrue);
        expect(await signer.verify(data, sig2, keyPair.publicKey), isTrue);
      },
    );
  });
}
