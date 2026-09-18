import 'dart:typed_data';
import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:multibase/multibase.dart' as mb;
import 'package:test/test.dart';

void main() {
  group('MultibaseUtils RFC4648', () {
    final data = Uint8List.fromList([1, 85, 18, 32, 3, 144, 88, 198]);
    test('base32 matches standard CIDv1 encoding', () {
      expect(MultibaseUtils.encode(mb.Multibase.base32, data), startsWith('b'));
    });
    test('base32 round-trips and decodes standard strings', () {
      final cidBytes = Uint8List.fromList([
        1,
        85,
        18,
        32,
        3,
        144,
        88,
        198,
        242,
        192,
        203,
        73,
        44,
        83,
        59,
        10,
        77,
        20,
        239,
        119,
        204,
        15,
        120,
        171,
        204,
        206,
        213,
        40,
        125,
        132,
        161,
        162,
        1,
        28,
        251,
        129,
      ]);
      expect(
        MultibaseUtils.decode(
          'bafkreiadsbmmn4waznesyuz3bjgrj33xzqhxrk6mz3ksq7meugrachh3qe',
        ),
        equals(cidBytes),
      );
    });
    test('base16/base64/base64url round-trip', () {
      for (final base in [
        mb.Multibase.base16,
        mb.Multibase.base16upper,
        mb.Multibase.base64,
        mb.Multibase.base64url,
        mb.Multibase.base64urlpad,
        mb.Multibase.base32upper,
      ]) {
        expect(
          MultibaseUtils.decode(MultibaseUtils.encode(base, data)),
          equals(data),
          reason: '$base',
        );
      }
    });
    test('base58btc still round-trips via package', () {
      expect(
        MultibaseUtils.decode(
          MultibaseUtils.encode(mb.Multibase.base58btc, data),
        ),
        equals(data),
      );
    });
    test('rejects invalid input', () {
      expect(() => MultibaseUtils.decode(''), throwsFormatException);
      expect(() => MultibaseUtils.decode('b!nvalid'), throwsFormatException);
      expect(() => MultibaseUtils.decode('fzz'), throwsFormatException);
    });
    test('unsupported prefixes surface a clear error', () {
      // Prefixes outside the explicitly implemented bases fall through to
      // the package codec, which rejects bases it does not support.
      expect(
        () => MultibaseUtils.decode('k51qzi5uqu5dl'),
        throwsUnsupportedError,
      );
    });
    test('encodeWithName maps names', () {
      expect(MultibaseUtils.encodeWithName('base32', data), startsWith('b'));
      expect(MultibaseUtils.encodeWithName('base64url', data), startsWith('u'));
      expect(MultibaseUtils.encodeWithName('unknown', data), startsWith('b'));
    });
  });
}
