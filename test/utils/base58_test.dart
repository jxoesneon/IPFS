import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:test/test.dart';

void main() {
  group('Base58', () {
    late Base58 base58;

    setUp(() {
      base58 = Base58();
    });

    test('encode/decode empty bytes', () {
      expect(base58.encode(Uint8List(0)), equals(''));
    });

    test('encode/decode simple string', () {
      final bytes = Uint8List.fromList('hello'.codeUnits);
      final encoded = base58.encode(bytes);
      // 'hello' in base58 is 'Cn8Jmjm'
      expect(encoded, isNotEmpty);

      final decoded = base58.base58Decode(encoded);
      expect(String.fromCharCodes(decoded), equals('hello'));
    });

    test('encode/decode with leading zeros', () {
      final bytes = Uint8List.fromList([0, 0, 1, 2, 3]);
      final encoded = base58.encode(bytes);
      expect(encoded.startsWith('11'), isTrue);

      final decoded = base58.base58Decode(encoded);
      expect(decoded, equals(bytes));
    });

    test('decode invalid characters throws ArgumentError', () {
      expect(() => base58.base58Decode('0OIl'), throwsArgumentError);
    });

    test('bigIntToUint8List - zero', () {
      final result = base58.bigIntToUint8List(BigInt.zero);
      expect(result.length, equals(0));
    });

    test('encode/decode large value (multi-hash style)', () {
      // Common IPFS multihash prefix 0x1220...
      final bytes = Uint8List.fromList([0x12, 0x20] + List.generate(32, (i) => i));
      final encoded = base58.encode(bytes);
      expect(encoded.startsWith('Qm'), isTrue); // Should start with Qm

      final decoded = base58.base58Decode(encoded);
      expect(decoded, equals(bytes));
    });
  });
}
