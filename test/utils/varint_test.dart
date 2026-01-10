import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/varint.dart';
import 'package:test/test.dart';

void main() {
  group('Varint', () {
    test('encode/decode small integers', () {
      for (var i = 0; i < 128; i++) {
        final encoded = encodeVarint(i);
        expect(encoded.length, equals(1));
        expect(encoded[0], equals(i));

        final (decoded, read) = decodeVarint(encoded);
        expect(decoded, equals(i));
        expect(read, equals(1));
      }
    });

    test('encode/decode multi-byte integers', () {
      final testValues = [
        128, // 0x80 0x01
        300, // 0xAC 0x02
        16383, // 0xFF 0x7F
        16384, // 0x80 0x80 0x01
        2097151, // 0xFF 0xFF 0x7F
      ];

      for (final val in testValues) {
        final encoded = encodeVarint(val);
        final (decoded, read) = decodeVarint(encoded);
        expect(decoded, equals(val));
        expect(read, equals(encoded.length));
      }
    });

    test('decode stops at MSB 0', () {
      final bytes = Uint8List.fromList([0x80, 0x80, 0x01, 0xFF]); // 16384 followed by noise
      final (decoded, read) = decodeVarint(bytes);
      expect(decoded, equals(16384));
      expect(read, equals(3));
    });

    test('encode large integers', () {
      final val = 0x7FFFFFFFFFFFFFFF; // Max safe int in Dart VM
      final encoded = encodeVarint(val);
      final (decoded, read) = decodeVarint(encoded);
      expect(decoded, equals(val));
    });
  });
}
