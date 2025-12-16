import 'package:dart_ipfs/src/core/cbor/byte_reader.dart';
import 'package:test/test.dart';

void main() {
  group('ByteReader', () {
    test('readByte moves position', () {
      final reader = ByteReader([0x01, 0x02]);
      expect(reader.readByte(), 0x01);
      expect(reader.position, 1);
      expect(reader.readByte(), 0x02);
      expect(reader.position, 2);
    });

    test('readByte throws at end', () {
      final reader = ByteReader([0x01]);
      reader.readByte();
      expect(() => reader.readByte(), throwsStateError);
    });

    test('readBytes returns correct sublist', () {
      final reader = ByteReader([0x01, 0x02, 0x03, 0x04]);
      expect(reader.readBytes(2), [0x01, 0x02]);
      expect(reader.position, 2);
      expect(reader.readBytes(2), [0x03, 0x04]);
    });

    test('readBytes throws if not enough', () {
      final reader = ByteReader([0x01, 0x02]);
      expect(() => reader.readBytes(3), throwsStateError);
    });

    test('isBreak detects 0xFF', () {
      final reader = ByteReader([0x01, 0xFF, 0x02]);
      expect(reader.isBreak(), isFalse);
      reader.readByte();
      expect(reader.isBreak(), isTrue); // Should peak at current 0xFF
      reader.readByte();
      expect(reader.isBreak(), isFalse);
    });

    test('hasRemaining and remaining', () {
      final reader = ByteReader([1, 2, 3]);
      expect(reader.hasRemaining, isTrue);
      expect(reader.remaining, [1, 2, 3]);

      reader.readByte();
      expect(reader.hasRemaining, isTrue);
      expect(reader.remaining, [2, 3]);

      reader.readBytes(2);
      expect(reader.hasRemaining, isFalse);
      expect(reader.remaining, <int>[]);
    });
  });
}
