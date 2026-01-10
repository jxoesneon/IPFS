import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:test/test.dart';

void main() {
  group('Ed25519Signer', () {
    late Ed25519Signer signer;

    setUp(() {
      signer = Ed25519Signer();
    });

    test('generateKeyPair without seed', () async {
      final keyPair = await signer.generateKeyPair();
      expect(keyPair, isA<SimpleKeyPair>());
      final pub = await keyPair.extractPublicKey();
      expect(pub.bytes.length, equals(32));
    });

    test('generateKeyPair with seed', () async {
      final seed = Uint8List(32)..fillRange(0, 32, 5);
      final keyPair = await signer.generateKeyPair(seed: seed);
      
      final seed2 = Uint8List(32)..fillRange(0, 32, 5);
      final keyPair2 = await signer.generateKeyPair(seed: seed2);
      
      final pub1 = await keyPair.extractPublicKey();
      final pub2 = await keyPair2.extractPublicKey();
      expect(pub1.bytes, equals(pub2.bytes));
    });

    test('generateKeyPair with invalid seed length', () {
      expect(() => signer.generateKeyPair(seed: Uint8List(31)), throwsArgumentError);
    });

    test('keyPairFromSeed', () async {
      final seed = Uint8List(32)..fillRange(0, 32, 10);
      final kp = await signer.keyPairFromSeed(seed);
      expect(kp, isA<SimpleKeyPair>());
    });

    test('keyPairFromSeed with invalid seed length', () {
      expect(() => signer.keyPairFromSeed(Uint8List(33)), throwsArgumentError);
    });

    test('sign and verify roundtrip', () async {
      final kp = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      final signature = await signer.sign(data, kp);
      expect(signature.length, equals(64));
      
      final pub = await signer.extractPublicKey(kp);
      final isValid = await signer.verify(data, signature, pub);
      expect(isValid, isTrue);
    });

    test('verify failure with wrong data', () async {
      final kp = await signer.generateKeyPair();
      final data = Uint8List.fromList([1, 2, 3]);
      final sig = await signer.sign(data, kp);
      
      final pub = await signer.extractPublicKey(kp);
      final isValid = await signer.verify(Uint8List.fromList([1, 2, 4]), sig, pub);
      expect(isValid, isFalse);
    });

    test('verify failure with catch path', () async {
      // Pass invalid signature length (not 64 bytes) to trigger catch
      final kp = await signer.generateKeyPair();
      final pub = await signer.extractPublicKey(kp);
      final isValid = await signer.verify(Uint8List(0), Uint8List(10), pub);
      expect(isValid, isFalse);
    });

    test('extractPublicKeyBytes', () async {
      final kp = await signer.generateKeyPair();
      final bytes = await signer.extractPublicKeyBytes(kp);
      expect(bytes.length, equals(32));
    });

    test('extractSeed', () async {
      final kp = await signer.generateKeyPair();
      final seed = await signer.extractSeed(kp);
      expect(seed.length, equals(32));
    });

    test('publicKeyFromBytes', () {
      final bytes = Uint8List(32)..fillRange(0, 32, 1);
      final pub = signer.publicKeyFromBytes(bytes);
      expect(pub.bytes, equals(bytes));
    });

    test('publicKeyFromBytes invalid length', () {
      expect(() => signer.publicKeyFromBytes(Uint8List(31)), throwsArgumentError);
    });

    test('KeyPairExtensions.extractSeedAndZero', () async {
      final kp = await signer.generateKeyPair();
      final seed = await kp.extractSeedAndZero();
      expect(seed.length, equals(32));
    });
  });
}
