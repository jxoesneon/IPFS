import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSPrivateKey', () {
    test('generate creates valid key pair', () async {
      final key = await IPFSPrivateKey.generate();
      expect(key, isNotNull);
      expect(key.algorithm, equals('ECDSA'));
    });

    test('publicKeyBytes returns valid compressed SEC1 bytes', () async {
      final key = await IPFSPrivateKey.generate();
      final bytes = key.publicKeyBytes;

      // Secp256k1 compressed key should be 33 bytes
      expect(bytes.length, equals(33));

      // Prefix should be 0x02 or 0x03
      expect(bytes[0] == 0x02 || bytes[0] == 0x03, isTrue);
    });

    test('sign and verify works with generated key', () async {
      final key = await IPFSPrivateKey.generate();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final signature = key.sign(data);
      expect(signature, isNotNull);
      expect(signature, isNotEmpty);

      final isValid = key.verify(data, signature);
      expect(isValid, isTrue);
    });
  });
}
