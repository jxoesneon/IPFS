import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/bitfield.dart'; // Adjust the import path as necessary

void main() {
  group('BitField', () {
    test('Constructor initializes all bits to false', () {
      final bitField = BitField(16);

      for (int i = 0; i < bitField.size; i++) {
        expect(bitField.getBit(i), isFalse);
      }
    });

    test('setBit sets the specified bit to true', () {
      final bitField = BitField(16);
      bitField.setBit(3);

      expect(bitField.getBit(3), isTrue);
    });

    test('clearBit sets the specified bit to false', () {
      final bitField = BitField(16);
      bitField.setBit(3);
      expect(bitField.getBit(3), isTrue);

      bitField.clearBit(3);
      expect(bitField.getBit(3), isFalse);
    });

    test('getBit returns correct state of a bit', () {
      final bitField = BitField(16);
      
      expect(bitField.getBit(5), isFalse);

      bitField.setBit(5);
      expect(bitField.getBit(5), isTrue);

      bitField.clearBit(5);
      expect(bitField.getBit(5), isFalse);
    });

    test('Throws RangeError for out-of-bounds index', () {
      final bitField = BitField(16);

      expect(() => bitField.setBit(-1), throwsRangeError);
      expect(() => bitField.setBit(16), throwsRangeError);

      expect(() => bitField.clearBit(-1), throwsRangeError);
      expect(() => bitField.clearBit(16), throwsRangeError);

      expect(() => bitField.getBit(-1), throwsRangeError);
      expect(() => bitField.getBit(16), throwsRangeError);
    });

    test('Serialization and deserialization with protobuf', () {
      final original = BitField(16);
      original.setBit(2);
      original.setBit(7);

      final proto = original.toProto();
      
      final deserialized = BitField.fromProto(proto);

      for (int i = 0; i < original.size; i++) {
        expect(deserialized.getBit(i), original.getBit(i));
      }
    });
  });
}