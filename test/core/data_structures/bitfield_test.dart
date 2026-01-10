// test/core/data_structures/bitfield_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/bitfield.dart';
import 'package:test/test.dart';

void main() {
  group('BitField', () {
    test('creates bitfield of correct size', () {
      final bitfield = BitField(64);
      expect(bitfield.size, equals(64));
    });

    test('rounds up to byte boundary', () {
      final bitfield = BitField(10);
      expect(bitfield.size, equals(16)); // 10 bits -> 2 bytes = 16 bits
    });

    test('all bits are initially false', () {
      final bitfield = BitField(32);
      for (var i = 0; i < 32; i++) {
        expect(bitfield.getBit(i), isFalse);
      }
    });

    test('setBit sets bit to true', () {
      final bitfield = BitField(16);
      bitfield.setBit(5);
      expect(bitfield.getBit(5), isTrue);
    });

    test('clearBit sets bit to false', () {
      final bitfield = BitField(16);
      bitfield.setBit(7);
      expect(bitfield.getBit(7), isTrue);

      bitfield.clearBit(7);
      expect(bitfield.getBit(7), isFalse);
    });

    test('setBit only affects target bit', () {
      final bitfield = BitField(16);
      bitfield.setBit(3);

      expect(bitfield.getBit(2), isFalse);
      expect(bitfield.getBit(3), isTrue);
      expect(bitfield.getBit(4), isFalse);
    });

    test('multiple bits can be set', () {
      final bitfield = BitField(32);
      bitfield.setBit(0);
      bitfield.setBit(7);
      bitfield.setBit(15);
      bitfield.setBit(31);

      expect(bitfield.getBit(0), isTrue);
      expect(bitfield.getBit(7), isTrue);
      expect(bitfield.getBit(15), isTrue);
      expect(bitfield.getBit(31), isTrue);
    });

    test('throws RangeError for negative index', () {
      final bitfield = BitField(8);
      expect(() => bitfield.getBit(-1), throwsRangeError);
    });

    test('throws RangeError for index >= size', () {
      final bitfield = BitField(8);
      expect(() => bitfield.getBit(8), throwsRangeError);
    });
  });

  group('BitField Protobuf Serialization', () {
    test('toProto creates valid proto', () {
      final bitfield = BitField(16);
      bitfield.setBit(3);
      bitfield.setBit(10);

      final proto = bitfield.toProto();
      expect(proto.size, equals(16));
      expect(proto.bits.isNotEmpty, isTrue);
    });

    test('fromProto restores bitfield', () {
      final original = BitField(24);
      original.setBit(5);
      original.setBit(20);

      final proto = original.toProto();
      final restored = BitField.fromProto(proto);

      expect(restored.size, equals(original.size));
      expect(restored.getBit(5), isTrue);
      expect(restored.getBit(20), isTrue);
      expect(restored.getBit(0), isFalse);
    });

    test('roundtrip preserves all bits', () {
      final original = BitField(32);
      for (var i = 0; i < 32; i += 2) {
        original.setBit(i); // Set even bits
      }

      final proto = original.toProto();
      final restored = BitField.fromProto(proto);

      for (var i = 0; i < 32; i++) {
        expect(restored.getBit(i), equals(i % 2 == 0));
      }
    });
  });
}
