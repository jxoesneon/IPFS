// Validation tests for external dependencies
// Confirms all external packages work correctly

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('External Dependencies Validation', () {
    test('UUID package works', () {
      final uuid = const Uuid();
      final id = uuid.v4();

      expect(id, isNotNull);
      expect(id, isA<String>());
      expect(id.length, equals(36)); // UUID v4 format
    });

    test('Crypto package works', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final hash = sha256.convert(data);

      expect(hash, isNotNull);
      expect(hash.bytes, hasLength(32)); // SHA-256 is 32 bytes
    });

    test('Convert package works', () {
      final bytes = [1, 2, 3, 4];
      final hexString = hex.encode(bytes);
      final decoded = hex.decode(hexString);

      expect(hexString, equals('01020304'));
      expect(decoded, equals(bytes));
    });

    test('P2Plib PeerId works', () {
      final bytes = Uint8List.fromList(List.filled(64, 1));
      final peerId = p2p.PeerId(value: bytes);

      expect(peerId, isNotNull);
      expect(peerId.value, hasLength(64));
    });

    test('All external packages are accessible', () {
      // Verify all critical dependencies load
      expect(Uuid, isNotNull);
      expect(sha256, isNotNull);
      expect(hex, isNotNull);
      expect(p2p.PeerId, isNotNull);
    });

    test('Crypto algorithms work correctly', () {
      final input = 'test data';
      final bytes = Uint8List.fromList(input.codeUnits);

      final sha256Hash = sha256.convert(bytes);
      final md5Hash = md5.convert(bytes);

      expect(sha256Hash.bytes, hasLength(32));
      expect(md5Hash.bytes, hasLength(16));
    });

    test('UUID generates unique IDs', () {
      final uuid = const Uuid();
      final ids = List.generate(100, (_) => uuid.v4());
      final uniqueIds = ids.toSet();

      expect(uniqueIds.length, equals(100));
    });
  });
}
