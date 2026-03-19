// test/core/utils/utils_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:test/test.dart';

void main() {
  group('Base58', () {
    final base58 = Base58();

    test('encode encodes bytes correctly', () {
      final input = Uint8List.fromList([0, 1, 2, 3]);
      // 0x010203 = 66051
      // 58^2 = 3364, 58^3 = 195112
      // expected: leading zero (1) + something
      final encoded = base58.encode(input);
      expect(encoded, isNotEmpty);
      expect(encoded.startsWith('1'), isTrue); // Leading zero byte -> '1'
    });

    test('decode decodes string correctly', () {
      final input = '12345';
      final decoded = base58.base58Decode(input);
      final reEncoded = base58.encode(decoded);
      expect(reEncoded, equals(input));
    });

    test('encode/decode cycle preserves data', () {
      final input = Uint8List.fromList(List.generate(32, (i) => i));
      final encoded = base58.encode(input);
      final decoded = base58.base58Decode(encoded);
      expect(decoded, equals(input));
    });

    test('handles empty input', () {
      expect(base58.encode(Uint8List(0)), isEmpty);
    });
  });

  group('EncodingUtils', () {
    test('toBase58 adds z prefix', () {
      final input = Uint8List.fromList([1, 2, 3]);
      final encoded = EncodingUtils.toBase58(input);
      expect(encoded.startsWith('z'), isTrue);
    });

    test('fromBase58 handles z prefix', () {
      final input = Uint8List.fromList([1, 2, 3]);
      final encoded = EncodingUtils.toBase58(input);
      final decoded = EncodingUtils.fromBase58(encoded);
      expect(decoded, equals(input));
    });

    test('fromBase58 throws on invalid prefix', () {
      expect(
        () => EncodingUtils.fromBase58('x123'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('isValidCIDBytes validates CIDv0', () {
      // CIDv0: SHA2-256 (0x12 0x20) + 32 bytes
      final bytes = Uint8List(34);
      bytes[0] = 0x12;
      bytes[1] = 0x20;
      // fill rest
      for (int i = 2; i < 34; i++) bytes[i] = 1;

      expect(EncodingUtils.isValidCIDBytes(bytes), isTrue);
    });

    test('isValidCIDBytes fails invalid length CIDv0', () {
      final bytes = Uint8List(33);
      bytes[0] = 0x12;
      bytes[1] = 0x20;
      expect(EncodingUtils.isValidCIDBytes(bytes), isFalse);
    });

    test('supportedCodecs returns list', () {
      expect(EncodingUtils.supportedCodecs, contains('dag-pb'));
      expect(EncodingUtils.supportedCodecs, contains('raw'));
    });

    test('getCodecFromCode returns correct strings', () {
      expect(EncodingUtils.getCodecFromCode(0x70), equals('dag-pb'));
      expect(EncodingUtils.getCodecFromCode(0x55), equals('raw'));
    });
  });
}
