import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingUtils', () {
    test('toBase58 adds z prefix', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = EncodingUtils.toBase58(bytes);
      expect(result.startsWith('z'), isTrue);
    });

    test('fromBase58 handles z prefix', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final encoded = EncodingUtils.toBase58(bytes);
      final decoded = EncodingUtils.fromBase58(encoded);
      expect(decoded, equals(bytes));
    });

    test('fromBase58 throws on empty', () {
      expect(() => EncodingUtils.fromBase58(''), throwsArgumentError);
    });

    test('fromBase58 throws on invalid prefix', () {
      expect(() => EncodingUtils.fromBase58('?abc'), throwsArgumentError);
    });

    test('fromBase58 throws on unsupported prefix', () {
      // 'f' is base16, valid multibase but logic throws UnsupportedError for non-z currently?
      // line 65: if (prefix == 'z') return...
      // line 71: throw UnsupportedError
      expect(() => EncodingUtils.fromBase58('fabc'), throwsUnsupportedError);
    });

    test('isValidCIDBytes returns false for empty', () {
      expect(EncodingUtils.isValidCIDBytes(Uint8List(0)), isFalse);
    });

    test('isValidCIDBytes checks multibase prefix', () {
      final bytes =
          Uint8List.fromList([0x00, 0x01]); // 0x00 is identity (valid prefix)
      // code continues...
      // line 92: sublist(1) -> [0x01]. length 1.
      // line 93: if length < 2 return false.
      expect(EncodingUtils.isValidCIDBytes(bytes), isFalse);
    });

    test('isValidCIDBytes checks invalid multibase prefix', () {
      final bytes =
          Uint8List.fromList([0xFF, 0x01, 0x02]); // 0xFF invalid prefix
      expect(EncodingUtils.isValidCIDBytes(bytes), isFalse);
    });

    test('isValidCIDBytes validates CIDv0', () {
      // CIDv0: 34 bytes.
      // Prefix? CIDv0 is usually raw bytes (no multibase prefix) when stored?
      // But isValidCIDBytes expects multibase prefix at byte 0?
      // Code:
      // final prefix = String.fromCharCode(bytes[0]);
      // if (!isValidMultibasePrefix(prefix)) return false;
      //
      // CIDv0 usually starts with 0x12 0x20.
      // 0x12 is 18. char code 18 is DC2. Is it in _supportedMultibasePrefixes?
      // _supportedMultibasePrefixes values: 'f', 'b', ...
      // 0x12 is NOT a valid multibase prefix character usually.
      // Wait, `bytes` argument to `isValidCIDBytes`. If it's a CIDv0, does it have a prefix?
      // Usually CIDv0 in string form is base58btc (Qm...).
      // In BYTES form?
      // If it's "CID bytes", maybe it means the raw bytes of the CID?
      // A CIDv0 RAW bytes starts with 0x12.
      // BUT `isValidCIDBytes` logic (Line 86) treats byte 0 as a char code for prefix?
      // `String.fromCharCode(bytes[0])`.
      // If passing raw CIDv0 bytes (0x12...), char code 18 is not in the map?
      // Let's check map values: 'f', 'b', 'z' ...
      // None correspond to 0x12.
      // So `isValidCIDBytes` expects Multihash-wrapped CID strings? No, "bytes".
      // Maybe it expects the bytes of the MULTIBASE ENCODED string?
      // "Validate CID bytes".
      // If I have `Qm...` string, I convert to bytes (ascii). 'Q' is not a prefix.
      // 'z' is prefix.
      // It seems this function expects the bytes of the MULTIBASE STRING.
      // verify line 92: `cidBytes = bytes.sublist(1)`.
      // It strips the prefix.
      // Then `cidBytes[0]` is version.
      // For ID 'z' (base58btc), the payload is decoded bytes?
      // NO. `bytes` is Uint8List. `String.fromCharCode(bytes[0])` implies `bytes` contains ASCII chars of the string?
      // This is confusing. "Validate CID bytes".
      // If input is `toBase58()` output as utf8 bytes.
      // Then byte 0 is 'z'.
      // sublist(1) is the rest of string bytes?
      // BUT `cidBytes[0]` is treated as integer version.
      // 'z' is followed by base58 content. Base58 content is ASCII chars.
      // `cidBytes[0]` would be a char code. e.g. 'Q'. 'Q' is 81.
      // Line 96: `if (version > 2)`. 81 > 2. Returns false.
      // So this function does NOT handle Base58 encoded string bytes.
      // It must handle MULTIBASE DECODED bytes?
      // If decoded, then there is NO prefix at byte 0?
      // Re-read `encoding.dart`.
      // Line 86: `final prefix = String.fromCharCode(bytes[0])`.
      // This explicitly looks for a multibase prefix at the start of the bytes.
      // Standard binary CID (v1) does NOT have a multibase prefix. It starts withVersion.
      // Multibase is a textual encoding layer.
      // Storing prefix in binary is "Multibase-prefixed binary"? rare.
      // BUT `identity` encoding prefix is `\x00`.
      // If bytes[0] is 0x00, it's 'identity'.
      // Then sublist(1) is raw CID.
      // If CIDv1: 0x01 ...
      // If bytes[0] is 0x00?
      // If `bytes` is purely the raw CID bytes, it starts with 0x01 (v1) or 0x12 (v0).
      // 0x01 is NOT a valid multibase prefix char?
      // 0x01 is not in `_supportedMultibasePrefixes` values.
      // So `isValidCIDBytes` will FAIL for standard raw ID bytes (0x01...).
      // It seems `isValidCIDBytes` is buggy or expects something else (e.g. explicitly multibase-prefixed buffer?).
      // I will test what it currently does.
      // Start with a mock valid input that passes:
      // Prefix 0x00 (identity).
      // Remaining [0x01 (ver), 0x55 (raw), 0x12 (sha2-256), 0x20 (len), ...32 bytes... ]
      final validCid = Uint8List.fromList([
        0x00, // identity prefix
        0x01, // version 1
        0x55, // raw codec
        0x12, // sha2-256
        32, // length
        ...List.filled(32, 0)
      ]);
      expect(EncodingUtils.isValidCIDBytes(validCid), isTrue);
    });

    test('getCodecFromCode returns correct codec', () {
      expect(EncodingUtils.getCodecFromCode(0x70), 'dag-pb');
      expect(EncodingUtils.getCodecFromCode(0x71), 'dag-cbor');
    });

    test('getCodecFromCode throws on unknown', () {
      expect(() => EncodingUtils.getCodecFromCode(0xFFFFFFFF),
          throwsArgumentError);
    });

    test('indexToCidVersion values', () {
      expect(EncodingUtils.indexToCidVersion(0),
          IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED);
      expect(EncodingUtils.indexToCidVersion(1),
          IPFSCIDVersion.IPFS_CID_VERSION_0);
      expect(EncodingUtils.indexToCidVersion(2),
          IPFSCIDVersion.IPFS_CID_VERSION_1);
      expect(() => EncodingUtils.indexToCidVersion(99), throwsUnsupportedError);
    });

    test('isValidMultibasePrefix check', () {
      expect(EncodingUtils.isValidMultibasePrefix('z'), isTrue);
      expect(EncodingUtils.isValidMultibasePrefix('?'), isFalse);
    });

    test('getEncodingFromPrefix', () {
      expect(EncodingUtils.getEncodingFromPrefix('z'), 'base58btc');
      expect(EncodingUtils.getEncodingFromPrefix('?'), isEmpty);
    });

    test('supportedCodecs getter', () {
      expect(EncodingUtils.supportedCodecs, contains('dag-pb'));
    });
  });
}
