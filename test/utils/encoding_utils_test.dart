import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingUtils', () {
    group('Base58', () {
      test('toBase58 encodes correctly with z prefix', () {
        final data = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
        final encoded = EncodingUtils.toBase58(data);
        expect(encoded, startsWith('z'));
        // "Hello" in base58 is "9A87DPghAt" (approximately, depending on alphabet)
        // Verify with round trip
        expect(EncodingUtils.fromBase58(encoded), equals(data));
      });

      test('fromBase58 throws on empty string', () {
        expect(() => EncodingUtils.fromBase58(''), throwsArgumentError);
      });

      test('fromBase58 throws on invalid prefix', () {
        expect(
          () => EncodingUtils.fromBase58('xBadPrefix'),
          throwsArgumentError,
        );
      });

      test('fromBase58 throws on unsupported supported prefix', () {
        // 'f' is base16, which is supported in map but might not be implemented in fromBase58 if it only handles 'z'
        // Reviewing code: fromBase58 checks prefix == 'z', else throws UnsupportedError if prefix is valid but not 'z'
        expect(() => EncodingUtils.fromBase58('fabc'), throwsUnsupportedError);
      });
    });

    group('CID Validation', () {
      test('isValidCIDBytes returns true for valid CIDv0', () {
        // CIDv0: SHA2-256 (0x12 0x20) + 32 bytes
        final validCidV0 = Uint8List.fromList([
          0x12, 0x20,
          ...List.filled(32, 0), // 32 bytes of zeros
        ]);

        expect(EncodingUtils.isValidCIDBytes(validCidV0), isTrue);

        // Also test CIDv1
        final cid = CID.v0(Uint8List(32)); // Dummy hash
        final cidV1 = CID.v1('raw', cid.multihash);
        final bytes = cidV1.toBytes();

        expect(EncodingUtils.isValidCIDBytes(bytes), isTrue);
      });

      test('isValidCIDBytes handles invalid data gracefully', () {
        expect(EncodingUtils.isValidCIDBytes(Uint8List(0)), isFalse);
        // Identity byte 0x00 is not 0x12 or 0x01, so should be false
        expect(
          EncodingUtils.isValidCIDBytes(Uint8List.fromList([0x00])),
          isFalse,
        );
      });
    });

    group('Codecs', () {
      test('getCodecFromCode returns correct strings', () {
        expect(EncodingUtils.getCodecFromCode(0x55), 'raw');
        expect(EncodingUtils.getCodecFromCode(0x70), 'dag-pb');
        expect(EncodingUtils.getCodecFromCode(0x71), 'dag-cbor');
      });

      test('getCodeFromCodec returns correct codes', () {
        expect(EncodingUtils.getCodeFromCodec('raw'), 0x55);
        expect(EncodingUtils.getCodeFromCodec('dag-pb'), 0x70);
        expect(EncodingUtils.getCodeFromCodec('dag-cbor'), 0x71);
      });

      test('getCodecFromCode throws on unknown code', () {
        expect(
          () => EncodingUtils.getCodecFromCode(0xFFFFFF),
          throwsArgumentError,
        );
      });

      test('getCodeFromCodec throws on unknown codec', () {
        expect(
          () => EncodingUtils.getCodeFromCodec('unknown_codec'),
          throwsArgumentError,
        );
      });

      test('supportedCodecs list is not empty', () {
        expect(EncodingUtils.supportedCodecs, isNotEmpty);
        expect(EncodingUtils.supportedCodecs, contains('raw'));
      });
    });

    group('Multibase', () {
      test('isValidMultibasePrefix correctly identifies prefixes', () {
        expect(EncodingUtils.isValidMultibasePrefix('z'), isTrue);
        expect(EncodingUtils.isValidMultibasePrefix('b'), isTrue);
        expect(EncodingUtils.isValidMultibasePrefix('f'), isTrue);
        expect(EncodingUtils.isValidMultibasePrefix('x'), isFalse);
      });

      test('getEncodingFromPrefix returns correct encoding name', () {
        expect(EncodingUtils.getEncodingFromPrefix('z'), 'base58btc');
        expect(EncodingUtils.getEncodingFromPrefix('b'), 'base32');
        expect(EncodingUtils.getEncodingFromPrefix('f'), 'base16');
      });
    });
  });
}
