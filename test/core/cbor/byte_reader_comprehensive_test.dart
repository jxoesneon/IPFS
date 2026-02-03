// test/core/cbor/byte_reader_comprehensive_test.dart
import 'package:dart_ipfs/src/core/cbor/byte_reader.dart';
import 'package:test/test.dart';

/// Comprehensive verified tests for ByteReader utility.
void main() {
  group('ByteReader - Comprehensive Tests', () {
    group('Initialization', () {
      test('creates reader with byte list', () {
        final reader = ByteReader([1, 2, 3]);

        expect(reader, isNotNull);
        expect(reader.position, equals(0));
        expect(reader.hasRemaining, isTrue);
      });

      test('creates reader with empty list', () {
        final reader = ByteReader([]);

        expect(reader.position, equals(0));
        expect(reader.hasRemaining, isFalse);
      });

      test('initial position is zero', () {
        final reader = ByteReader([1, 2, 3, 4, 5]);

        expect(reader.position, equals(0));
      });
    });

    group('readByte', () {
      test('reads single byte and advances position', () {
        final reader = ByteReader([10, 20, 30]);

        final byte = reader.readByte();

        expect(byte, equals(10));
        expect(reader.position, equals(1));
      });

      test('reads bytes sequentially', () {
        final reader = ByteReader([1, 2, 3, 4]);

        expect(reader.readByte(), equals(1));
        expect(reader.readByte(), equals(2));
        expect(reader.readByte(), equals(3));
        expect(reader.readByte(), equals(4));
      });

      test('throws StateError when no bytes remain', () {
        final reader = ByteReader([1]);
        reader.readByte(); // Consume the byte

        expect(() => reader.readByte(), throwsStateError);
      });

      test('throws StateError on empty reader', () {
        final reader = ByteReader([]);

        expect(() => reader.readByte(), throwsStateError);
      });

      test('handles binary values correctly', () {
        final reader = ByteReader([0, 255, 128]);

        expect(reader.readByte(), equals(0));
        expect(reader.readByte(), equals(255));
        expect(reader.readByte(), equals(128));
      });
    });

    group('readBytes', () {
      test('reads multiple bytes at once', () {
        final reader = ByteReader([1, 2, 3, 4, 5]);

        final bytes = reader.readBytes(3);

        expect(bytes, equals([1, 2, 3]));
        expect(reader.position, equals(3));
      });

      test('reads all remaining bytes', () {
        final reader = ByteReader([1, 2, 3]);

        final bytes = reader.readBytes(3);

        expect(bytes, equals([1, 2, 3]));
        expect(reader.hasRemaining, isFalse);
      });

      test('reads zero bytes', () {
        final reader = ByteReader([1, 2, 3]);

        final bytes = reader.readBytes(0);

        expect(bytes, isEmpty);
        expect(reader.position, equals(0));
      });

      test('throws StateError when insufficient bytes', () {
        final reader = ByteReader([1, 2]);

        expect(() => reader.readBytes(3), throwsStateError);
      });

      test('sequential readBytes calls', () {
        final reader = ByteReader([1, 2, 3, 4, 5, 6]);

        expect(reader.readBytes(2), equals([1, 2]));
        expect(reader.readBytes(2), equals([3, 4]));
        expect(reader.readBytes(2), equals([5, 6]));
      });

      test('mixed readByte and readBytes', () {
        final reader = ByteReader([1, 2, 3, 4, 5]);

        expect(reader.readByte(), equals(1));
        expect(reader.readBytes(2), equals([2, 3]));
        expect(reader.readByte(), equals(4));
        expect(reader.readBytes(1), equals([5]));
      });
    });

    group('isBreak', () {
      test('returns true when next byte is 0xFF', () {
        final reader = ByteReader([0xFF, 1, 2]);

        expect(reader.isBreak(), isTrue);
      });

      test('returns false when next byte is not 0xFF', () {
        final reader = ByteReader([0xFE, 1, 2]);

        expect(reader.isBreak(), isFalse);
      });

      test('returns false when no bytes remaining', () {
        final reader = ByteReader([]);

        expect(reader.isBreak(), isFalse);
      });

      test('isBreak after consuming bytes', () {
        final reader = ByteReader([1, 0xFF, 3]);

        reader.readByte(); // Consume first byte
        expect(reader.isBreak(), isTrue);
      });

      test('isBreak does not consume byte', () {
        final reader = ByteReader([0xFF, 1]);

        expect(reader.isBreak(), isTrue);
        expect(reader.position, equals(0)); // Position unchanged
      });
    });

    group('remaining', () {
      test('returns all bytes initially', () {
        final reader = ByteReader([1, 2, 3, 4]);

        expect(reader.remaining, equals([1, 2, 3, 4]));
      });

      test('returns remaining after reading', () {
        final reader = ByteReader([1, 2, 3, 4, 5]);
        reader.readBytes(2);

        expect(reader.remaining, equals([3, 4, 5]));
      });

      test('returns empty list when all consumed', () {
        final reader = ByteReader([1, 2]);
        reader.readBytes(2);

        expect(reader.remaining, isEmpty);
      });
    });

    group('hasRemaining', () {
      test('returns true when bytes available', () {
        final reader = ByteReader([1, 2, 3]);

        expect(reader.hasRemaining, isTrue);
      });

      test('returns false when all bytes consumed', () {
        final reader = ByteReader([1]);
        reader.readByte();

        expect(reader.hasRemaining, isFalse);
      });

      test('returns false for empty reader', () {
        final reader = ByteReader([]);

        expect(reader.hasRemaining, isFalse);
      });

      test('updates after each read', () {
        final reader = ByteReader([1, 2]);

        expect(reader.hasRemaining, isTrue);
        reader.readByte();
        expect(reader.hasRemaining, isTrue);
        reader.readByte();
        expect(reader.hasRemaining, isFalse);
      });
    });

    group('position', () {
      test('tracks read position accurately', () {
        final reader = ByteReader([1, 2, 3, 4, 5]);

        expect(reader.position, equals(0));
        reader.readByte();
        expect(reader.position, equals(1));
        reader.readBytes(2);
        expect(reader.position, equals(3));
      });

      test('position equals length when all consumed', () {
        final reader = ByteReader([1, 2, 3]);
        reader.readBytes(3);

        expect(reader.position, equals(3));
      });
    });

    group('Edge Cases', () {
      test('handles large byte arrays', () {
        final largeArray = List.generate(1000, (i) => i % 256);
        final reader = ByteReader(largeArray);

        final firstHundred = reader.readBytes(100);
        expect(firstHundred.length, equals(100));
        expect(reader.position, equals(100));
      });

      test('handles all-zero bytes', () {
        final reader = ByteReader([0, 0, 0, 0]);

        expect(reader.readByte(), equals(0));
        expect(reader.readByte(), equals(0));
      });

      test('handles all-max bytes', () {
        final reader = ByteReader([255, 255, 255]);

        expect(reader.readByte(), equals(255));
        expect(reader.readBytes(2), equals([255, 255]));
      });

      test('single byte reader', () {
        final reader = ByteReader([42]);

        expect(reader.hasRemaining, isTrue);
        expect(reader.readByte(), equals(42));
        expect(reader.hasRemaining, isFalse);
      });
    });

    group('Error Conditions', () {
      test('readBytes with negative count throws', () {
        final reader = ByteReader([1, 2, 3]);

        expect(() => reader.readBytes(-1), throwsA(anything));
      });

      test('multiple reads past end all throw', () {
        final reader = ByteReader([1]);
        reader.readByte();

        expect(() => reader.readByte(), throwsStateError);
        expect(() => reader.readByte(), throwsStateError);
      });
    });
  });
}

