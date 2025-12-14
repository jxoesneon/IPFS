import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/utils/varint.dart';

void main() {
  group('Varint Utils', () {
    test('encodeVarint single byte', () {
      expect(encodeVarint(0), equals([0x00]));
      expect(encodeVarint(127), equals([0x7F]));
    });

    test('encodeVarint multiple bytes', () {
      expect(encodeVarint(128),
          equals([0x80, 0x01])); // 1000 0000 0000 0001 (LE 7-bit chunks)
      // 128 = 1000 0000.
      // 1st byte: lower 7 bits (000 0000) | 0x80 -> 0x80.
      // Remaining: 1.
      // 2nd byte: 1 (000 0001) | 0 (MSB 0) -> 0x01.
      // Valid.

      expect(encodeVarint(300), equals([0xAC, 0x02]));
      // 300 = 1 0010 1100.
      // 1st byte: 010 1100 (0x2C) | 0x80 = 0xAC.
      // Remaining: 10 (0x02).
      // 2nd byte: 0x02.
    });

    test('decodeVarint single byte', () {
      final (value, bytesRead) = decodeVarint(Uint8List.fromList([0x7F]));
      expect(value, 127);
      expect(bytesRead, 1);
    });

    test('decodeVarint multiple bytes', () {
      final (value, bytesRead) = decodeVarint(Uint8List.fromList([0xAC, 0x02]));
      expect(value, 300);
      expect(bytesRead, 2);
    });

    test('Round trip', () {
      final values = [0, 1, 127, 128, 255, 300, 16384, 999999];
      for (final v in values) {
        final encoded = encodeVarint(v);
        final (decoded, len) = decodeVarint(encoded);
        expect(decoded, v, reason: 'Value $v failed round trip');
        expect(len, encoded.length);
      }
    });

    test('decodeVarint handles extra bytes', () {
      // Decode only first varint
      final (value, len) = decodeVarint(Uint8List.fromList([0x01, 0xFF]));
      expect(value, 1);
      expect(len, 1);
    });
  });
}
