import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSPrivateKey', () {
    test('generate and sign/verify roundtrip', () async {
      final pk = await IPFSPrivateKey.generate();
      expect(pk.algorithm, equals('ECDSA'));
      expect(pk.publicKeyBytes.length, equals(33)); // Compressed SEC1

      final data = Uint8List.fromList(utf8.encode('test data'));
      final signature = pk.sign(data);
      expect(signature.length, equals(64)); // 32 bytes R + 32 bytes S

      final isValid = pk.verify(data, signature);
      expect(isValid, isTrue);
    });

    test('fromString and sign/verify', () async {
      // Use a known private key (32 bytes zeroed for simplicity in test, though not secure)
      final dummyPrivBytes = Uint8List(32)..fillRange(0, 32, 1);
      final privBase64 = base64Url.encode(dummyPrivBytes);

      final pk = IPFSPrivateKey.fromString(privBase64);
      expect(pk.algorithm, equals('ECDSA'));

      final data = Uint8List.fromList(utf8.encode('hello world'));
      final signature = pk.sign(data);
      final isValid = pk.verify(data, signature);
      expect(isValid, isTrue);
    });

    test('fromBytes - ECDSA', () {
      final keyBytes = Uint8List(32)..fillRange(0, 32, 2);
      final pk = IPFSPrivateKey.fromBytes(keyBytes);
      expect(pk.algorithm, equals('ECDSA'));
      expect(pk.privateKey.d, equals(BigInt.parse(hex.encode(keyBytes), radix: 16)));
    });

    test('fromBytes - Unsupported algorithm', () {
      expect(
        () => IPFSPrivateKey.fromBytes(Uint8List(32), algorithm: 'RSA'),
        throwsUnsupportedError,
      );
    });

    test('signature verification failure on wrong data', () async {
      final pk = await IPFSPrivateKey.generate();
      final data = Uint8List.fromList(utf8.encode('data 1'));
      final sig = pk.sign(data);

      final wrongData = Uint8List.fromList(utf8.encode('data 2'));
      expect(pk.verify(wrongData, sig), isFalse);
    });

    test('publicKeyBytes for non-ECDSA (theoretical)', () {
      // The current implementation returns Uint8List(0) for non-ECDSA in publicKeyBytes getter
      // but only ECDSA is currently supported in constructors.
      // If we had a way to inject a non-ECDSA key...
    });
  });
}
