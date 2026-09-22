// test/dag_cbor_strict_test.dart
//
// Byte-level strictness vectors for DagCborCodec, mirroring the canonical
// rules in https://ipld.io/specs/codecs/dag-cbor/spec/.
import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('DagCborCodec strict encode', () {
    final codec = DagCborCodec();

    test('rejects non-string map keys', () async {
      expect(
        () => codec.encode(<dynamic, dynamic>{1: 'x'}),
        throwsArgumentError,
      );
      expect(
        () => codec.encode(<String, dynamic>{
          'nested': <dynamic, dynamic>{true: 1},
        }),
        throwsArgumentError,
      );
    });

    test('rejects non-finite floats', () async {
      expect(() => codec.encode(double.nan), throwsArgumentError);
      expect(() => codec.encode(double.infinity), throwsArgumentError);
      expect(() => codec.encode(double.negativeInfinity), throwsArgumentError);
      expect(() => codec.encode({'n': double.nan}), throwsArgumentError);
    });

    test('normalizes -0.0 to canonical float64 0.0', () async {
      final encoded = await codec.encode(-0.0);
      expect(encoded, equals(bytes([0xfb, 0, 0, 0, 0, 0, 0, 0, 0])));
    });

    test('always encodes doubles as 64-bit floats', () async {
      final encoded = await codec.encode(1.0);
      expect(encoded, equals(bytes([0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0])));
    });

    test('rejects invalid CID strings in link form', () async {
      expect(() => codec.encode({'/': 'not-a-cid'}), throwsArgumentError);
      expect(() => codec.encode({'/': ''}), throwsArgumentError);
    });

    test('map with / key plus siblings encodes as a map, not a link', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final encoded = await codec.encode({'/': cid.encode(), 'x': 1});
      // a2 ... : map header, no tag 42 anywhere.
      expect(encoded[0], equals(0xa2));
      expect(encoded.contains(0xd8), isFalse);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals({'/': cid.encode(), 'x': 1}));
    });

    test('encodes smallest-form integers', () async {
      expect(await codec.encode(23), equals(bytes([0x17])));
      expect(await codec.encode(24), equals(bytes([0x18, 0x18])));
      expect(await codec.encode(256), equals(bytes([0x19, 0x01, 0x00])));
      expect(await codec.encode(-1), equals(bytes([0x20])));
      expect(await codec.encode(-24), equals(bytes([0x37])));
      expect(await codec.encode(-25), equals(bytes([0x38, 0x18])));
      // 2^64 - 1 as major type 0.
      expect(
        await codec.encode(BigInt.parse('18446744073709551615')),
        equals(bytes([0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])),
      );
      // -2^64 as major type 1.
      expect(
        await codec.encode(BigInt.parse('-18446744073709551616')),
        equals(bytes([0x3b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])),
      );
    });
  });

  group('DagCborCodec strict decode', () {
    final codec = DagCborCodec();

    Future<void> expectReject(List<int> input, String why) async {
      await expectLater(
        codec.decode(bytes(input)),
        throwsFormatException,
        reason: why,
      );
    }

    test('rejects empty input', () async => expectReject([], 'empty input'));

    test('rejects extraneous trailing bytes', () async {
      await expectReject([0x01, 0x02], 'uint 1 followed by a stray byte');
      await expectReject([
        0xa1,
        0x61,
        0x61,
        0x01,
        0x00,
      ], 'map followed by a stray byte');
    });

    test('rejects non-string map keys', () async {
      // {1: 2}
      await expectReject([0xa1, 0x01, 0x02], 'integer map key');
      // {[1]: 2}
      await expectReject([0xa1, 0x81, 0x01, 0x02], 'array map key');
      // nested: {'a': {1: 2}}
      await expectReject([
        0xa1,
        0x61,
        0x61,
        0xa1,
        0x01,
        0x02,
      ], 'nested integer map key');
    });

    test('rejects non-canonical map key ordering', () async {
      // {'b': 1, 'a': 2}: 'b' sorts after 'a' at equal length.
      await expectReject([
        0xa2,
        0x61,
        0x62,
        0x01,
        0x61,
        0x61,
        0x02,
      ], 'same-length keys out of lexicographic order');
      // {'aa': 1, 'a': 2}: 'aa' (len 2) must come after 'a' (len 1).
      await expectReject([
        0xa2,
        0x62,
        0x61,
        0x61,
        0x01,
        0x61,
        0x61,
        0x02,
      ], 'longer key before shorter key');
    });

    test('rejects duplicate map keys', () async {
      // {'a': 1, 'a': 2}
      await expectReject([
        0xa2,
        0x61,
        0x61,
        0x01,
        0x61,
        0x61,
        0x02,
      ], 'duplicate key');
    });

    test('rejects indefinite-length items and break tokens', () async {
      await expectReject([0x9f, 0x01, 0xff], 'indefinite array');
      await expectReject([0xbf, 0x61, 0x61, 0x01, 0xff], 'indefinite map');
      await expectReject([0x5f, 0x40, 0xff], 'indefinite bytes');
      await expectReject([0x7f, 0x60, 0xff], 'indefinite string');
      await expectReject([0xff], 'lone break token');
    });

    test('rejects non-canonical integer and length encodings', () async {
      await expectReject([0x18, 0x00], '0 encoded with 1-byte argument');
      await expectReject([0x18, 0x17], '23 encoded with 1-byte argument');
      await expectReject([
        0x19,
        0x00,
        0xff,
      ], '255 encoded with 2-byte argument');
      await expectReject([
        0x1a,
        0x00,
        0x00,
        0xff,
        0xff,
      ], '65535 encoded with 4-byte argument');
      await expectReject([
        0x1b,
        0x00,
        0x00,
        0x00,
        0x00,
        0xff,
        0xff,
        0xff,
        0xff,
      ], '2^32-1 encoded with 8-byte argument');
      // Same rule applied to negative ints, lengths, and tag arguments.
      await expectReject([0x38, 0x17], '-24 encoded with 1-byte argument');
      await expectReject([
        0x78,
        0x01,
        0x61,
      ], 'string length 1 with 1-byte argument');
      await expectReject([0x98, 0x01, 0x00], 'array length 1 non-canonical');
      // Tag 42 must be 0xd8 0x2a; a 2-byte tag argument is non-canonical.
      await expectReject([
        0xd9,
        0x00,
        0x2a,
        0x40,
      ], 'tag 42 with 2-byte argument');
    });

    test('rejects reserved additional info values', () async {
      await expectReject([0x1c], 'major 0 additional info 28');
      await expectReject([0x1d], 'major 0 additional info 29');
      await expectReject([0x1e], 'major 0 additional info 30');
      await expectReject([0xfc], 'major 7 additional info 28');
    });

    test('rejects undefined and unassigned simple values', () async {
      await expectReject([0xf7], 'undefined');
      await expectReject([0xf8, 0x20], 'unassigned simple value 32');
    });

    test('rejects non-64-bit float encodings', () async {
      await expectReject([0xf9, 0x3c, 0x00], 'half-precision 1.0');
      await expectReject([
        0xfa,
        0x3f,
        0x80,
        0x00,
        0x00,
      ], 'single-precision 1.0');
    });

    test('rejects -0.0', () async {
      await expectReject([
        0xfb,
        0x80,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ], 'float64 negative zero');
    });

    test('rejects non-finite floats and non-canonical NaN payloads', () async {
      await expectReject([0xfb, 0x7f, 0xf0, 0, 0, 0, 0, 0, 0], '+Infinity');
      await expectReject([0xfb, 0xff, 0xf0, 0, 0, 0, 0, 0, 0], '-Infinity');
      await expectReject([0xfb, 0x7f, 0xf8, 0, 0, 0, 0, 0, 0], 'canonical NaN');
      await expectReject([
        0xfb,
        0x7f,
        0xf0,
        0,
        0,
        0,
        0,
        0,
        0x01,
      ], 'NaN with non-canonical payload');
    });

    test('rejects non-IPLD tags', () async {
      await expectReject([0xc0, 0x00], 'tag 0 (date/time)');
      await expectReject([0xc1, 0x00], 'tag 1 (epoch time)');
      await expectReject([0xd8, 0x63, 0x40], 'tag 99');
      await expectReject([0xd8, 0x2d, 0x40], 'tag 45 (legacy non-standard)');
    });

    test('rejects superfluous and malformed bignum tags', () async {
      // Tag 2 over a small value representable as major type 0.
      await expectReject([0xc2, 0x41, 0x01], 'tag 2 applied to 1');
      // Tag 3 over n=0 => -1, representable as major type 1.
      await expectReject([0xc3, 0x41, 0x00], 'tag 3 applied to -1');
      // Leading zero byte: non-minimal bignum payload.
      await expectReject([
        0xc2,
        0x49,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ], 'tag 2 with leading zero byte');
      // Tag applied to a non-byte-string item.
      await expectReject([0xc2, 0x00], 'tag 2 applied to an integer');
      await expectReject([0xc3, 0x61, 0x61], 'tag 3 applied to a string');
    });

    test('accepts a valid bignum round-trip', () async {
      // Tag 2 over 2^64.
      final decoded = await codec.decode(
        bytes([
          0xc2,
          0x49,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
        ]),
      );
      expect(decoded, equals(BigInt.parse('18446744073709551616')));
    });

    test('rejects malformed tag 42 links', () async {
      await expectReject([0xd8, 0x2a, 0x00], 'tag 42 applied to an integer');
      await expectReject([0xd8, 0x2a, 0x40], 'empty byte string');
      await expectReject([
        0xd8,
        0x2a,
        0x41,
        0x01,
      ], 'byte string missing the 0x00 prefix');
      await expectReject([
        0xd8,
        0x2a,
        0x42,
        0x00,
        0xff,
      ], 'CID with unsupported version byte');
      await expectReject([
        0xd8,
        0x2a,
        0x42,
        0x00,
        0x12,
      ], 'truncated CIDv0 multihash');
      await expectReject([
        0xd8, 0x2a, 0x23, 0x00, //
        ...List.filled(34, 0x12), // starts 0x12 but wrong v0 length
      ], 'CIDv0-like bytes with wrong length');
    });

    test('rejects CIDv1 bytes with trailing garbage', () async {
      final cid = await CID.fromContent(Uint8List.fromList([9, 9, 9]));
      final cidBytes = cid.toBytes();
      final inner = bytes([0x00, ...cidBytes, 0xde, 0xad]);
      final encoded = bytes([0xd8, 0x2a, inner.length, ...inner]);
      await expectLater(codec.decode(encoded), throwsFormatException);
    });

    test('rejects invalid UTF-8 strings', () async {
      await expectReject([0x61, 0xff], 'single invalid byte');
      await expectReject([0xa1, 0x61, 0xff, 0x01], 'invalid UTF-8 in map key');
    });

    test('decodes valid canonical values', () async {
      expect(await codec.decode(bytes([0xf6])), isNull);
      expect(await codec.decode(bytes([0xf5])), isTrue);
      expect(await codec.decode(bytes([0xf4])), isFalse);
      expect(await codec.decode(bytes([0x00])), equals(0));
      expect(await codec.decode(bytes([0x20])), equals(-1));
      expect(
        await codec.decode(
          bytes([0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        ),
        equals(BigInt.parse('18446744073709551615')),
      );
      expect(
        await codec.decode(
          bytes([0x3b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        ),
        equals(BigInt.parse('-18446744073709551616')),
      );
      expect(
        await codec.decode(bytes([0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0])),
        equals(1.0),
      );
      expect(
        await codec.decode(bytes([0xa2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02])),
        equals({'a': 1, 'b': 2}),
      );
    });
  });

  group('DagCborCodec lenient decode', () {
    final codec = DagCborCodec(strict: false);

    test('accepts non-canonical integer encodings', () async {
      expect(await codec.decode(bytes([0x18, 0x2a])), equals(42));
      expect(await codec.decode(bytes([0x19, 0x00, 0xff])), equals(255));
    });

    test('accepts out-of-order map keys', () async {
      final decoded = await codec.decode(
        bytes([0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02]),
      );
      expect(decoded, equals({'b': 1, 'a': 2}));
    });

    test('accepts sub-64-bit floats', () async {
      expect(await codec.decode(bytes([0xf9, 0x3c, 0x00])), equals(1.0));
      expect(
        await codec.decode(bytes([0xfa, 0x3f, 0x80, 0x00, 0x00])),
        equals(1.0),
      );
    });

    test('normalizes -0.0 to 0.0', () async {
      final decoded = await codec.decode(
        bytes([0xfb, 0x80, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(decoded, equals(0.0));
      expect((decoded as double).isNegative, isFalse);
    });

    test('still rejects unsupported tags and indefinite lengths', () async {
      await expectLater(
        codec.decode(bytes([0xd8, 0x63, 0x40])),
        throwsFormatException,
      );
      await expectLater(
        codec.decode(bytes([0x9f, 0x01, 0xff])),
        throwsFormatException,
      );
      await expectLater(
        codec.decode(bytes([0xa1, 0x01, 0x02])),
        throwsFormatException,
      );
      await expectLater(
        codec.decode(bytes([0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02])),
        throwsFormatException,
      );
    });
  });
}
