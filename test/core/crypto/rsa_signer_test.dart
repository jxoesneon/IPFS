// test/core/crypto/rsa_signer_test.dart
//
// Tests for the RSA signer and peer ID derivation.

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/rsa_signer.dart';
import 'package:dart_ipfs/src/core/peer/peer_record_pb.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  group('RsaSigner', () {
    late RsaSigner signer;

    setUp(() {
      signer = RsaSigner();
    });

    test('generateKeyPair produces valid 2048-bit key pair', () async {
      final keyPair = await signer.generateKeyPair();
      expect(keyPair.publicKey.modulus!.bitLength, greaterThanOrEqualTo(2047));
      expect(keyPair.privateKey.modulus, equals(keyPair.publicKey.modulus));
      expect(
        keyPair.privateKey.publicExponent,
        equals(keyPair.publicKey.publicExponent),
      );
    });

    test('generateKeyPair with custom key size', () async {
      final keyPair = await signer.generateKeyPair(keySize: 3072);
      expect(keyPair.publicKey.modulus!.bitLength, greaterThanOrEqualTo(3071));
    });

    test('generateKeyPair rejects key size below 2048', () async {
      expect(() => signer.generateKeyPair(keySize: 1024), throwsArgumentError);
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
      final invalidSig = Uint8List.fromList(List.filled(256, 0));

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
      expect(reconstructed.modulus, equals(keyPair.publicKey.modulus));
      expect(
        reconstructed.publicExponent,
        equals(keyPair.publicKey.publicExponent),
      );
    });

    test('serializePrivateKey produces valid DER', () async {
      final keyPair = await signer.generateKeyPair();
      final derBytes = signer.serializePrivateKey(keyPair.privateKey);
      expect(derBytes.length, greaterThan(0));
      // DER sequence should start with 0x30
      expect(derBytes[0], equals(0x30));
    });

    test('derivePeerId returns non-empty base58 string', () async {
      final keyPair = await signer.generateKeyPair();
      final peerId = signer.derivePeerId(keyPair.publicKey);
      expect(peerId, isNotEmpty);
      // RSA peer IDs are SHA-256 multihash = 34 bytes + base58 encoding
      // Should be around 46 characters
      expect(peerId.length, greaterThan(40));
      // Should start with 'Qm' for SHA-256 multihash (common in IPFS)
      // Actually for RSA it's a 34-byte multihash base58 encoded
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
      expect(decoded.modulus, equals(keyPair.publicKey.modulus));
      expect(decoded.publicExponent, equals(keyPair.publicKey.publicExponent));
    });

    test('encodePublicKeyPb uses RSA key type', () async {
      final keyPair = await signer.generateKeyPair();
      final pbBytes = signer.encodePublicKeyPb(keyPair.publicKey);
      final pb = PublicKeyPb.decode(pbBytes);
      expect(pb.type, equals(KeyType.rsa));
    });

    test('decodePublicKeyPb rejects non-RSA key type', () async {
      final pb = PublicKeyPb(type: KeyType.ed25519, data: Uint8List(32));
      expect(() => signer.decodePublicKeyPb(pb.encode()), throwsArgumentError);
    });

    test('RsaKeyPair stores both keys', () async {
      final keyPair = await signer.generateKeyPair();
      expect(keyPair.publicKey.modulus, equals(keyPair.privateKey.modulus));
      expect(
        keyPair.publicKey.publicExponent,
        equals(keyPair.privateKey.publicExponent),
      );
    });
  });
}
