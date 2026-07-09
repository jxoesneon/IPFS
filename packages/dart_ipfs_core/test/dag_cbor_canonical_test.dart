// test/core/codec/dag_cbor_canonical_test.dart
import 'dart:typed_data';

import 'package:cbor/cbor.dart' as cbor;
import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('DagCborCodec canonical encoding', () {
    final codec = DagCborCodec();

    test('sorts map keys in byte-wise lexicographic order', () async {
      // Keys that would be in different order if sorted alphabetically
      // vs byte-wise. 'a' (0x61) < 'b' (0x62) < 'aa' (0x61,0x61).
      // Byte-wise: 'a' (length 1) < 'aa' (length 2) < 'b' (length 1)?
      // No: 'a' (0x61) and 'b' (0x62) are both length 1.
      // 'a' < 'b' by byte value. 'aa' is length 2, so it comes after 'a'
      // but before 'b' by length? No - by CBOR encoding:
      // 'a' = 0x61 0x61, 'b' = 0x61 0x62, 'aa' = 0x62 0x61 0x61
      // Wait, CBOR string encoding: 0x60|len for short strings.
      // 'a' = 0x61 0x61, 'b' = 0x62 0x62, 'aa' = 0x62 0x61 0x61
      // So: 0x61 < 0x62, meaning 'a' < 'b' and 'a' < 'aa'.
      // 'b' (0x62) vs 'aa' (0x62): same first byte, then 0x62 vs 0x61.
      // So 'aa' < 'b' because 0x61 < 0x62 at the second byte.
      // Wait no: 'b' = 0x62 (one byte string content), 'aa' = 0x62 (two byte
      // string content). The CBOR encoding is:
      // 'b' = [0x62, 0x62] (header byte 0x62 = major 3 | len 2, content 'b')
      // 'aa' = [0x62, 0x61, 0x61] (header 0x62 = major 3 | len 2, content 'aa')
      // Comparing byte-wise: first byte same (0x62), second byte: 0x62 vs 0x61.
      // 0x61 < 0x62, so 'aa' < 'b'.
      // Actually wait: 'b' has length 1, so header = 0x61 (major 3 | len 1).
      // 'b' = [0x61, 0x62]
      // 'aa' has length 2, so header = 0x62 (major 3 | len 2).
      // 'aa' = [0x62, 0x61, 0x61]
      // 0x61 < 0x62, so 'b' < 'aa'.
      // And 'a' = [0x61, 0x61], so 'a' < 'b' < 'aa'.
      // This is length-first ordering.
      final value = <String, dynamic>{'aa': 1, 'a': 2, 'b': 3};
      final encoded = await codec.encode(value);

      // Decode with raw CBOR to inspect key order.
      final decoded = cbor.cborDecode(encoded) as cbor.CborMap;
      final keys = decoded.entries
          .map((e) => (e.key as cbor.CborString).toString())
          .toList();
      // Expected order: 'a' (len 1), 'b' (len 1), 'aa' (len 2)
      // 'a' < 'b' by byte value, both length 1.
      // 'aa' is length 2, comes after both.
      expect(keys, equals(['a', 'b', 'aa']));
    });

    test(
      'canonical encoding is deterministic regardless of input order',
      () async {
        final map1 = <String, dynamic>{'z': 1, 'a': 2, 'm': 3};
        final map2 = <String, dynamic>{'a': 2, 'm': 3, 'z': 1};
        final encoded1 = await codec.encode(map1);
        final encoded2 = await codec.encode(map2);
        expect(
          encoded1,
          equals(encoded2),
          reason: 'Canonical encoding must be deterministic',
        );
      },
    );

    test(
      'encodes and decodes BigInt within int64 range as regular int',
      () async {
        final value = <String, dynamic>{
          'big': BigInt.from(9223372036854775807), // max int64
        };
        final encoded = await codec.encode(value);
        final decoded = await codec.decode(encoded);
        expect(decoded['big'], equals(9223372036854775807));
      },
    );

    test('encodes positive BigInt beyond int64 with tag 2', () async {
      final bigValue = BigInt.parse('9223372036854775808'); // 2^63
      final value = <String, dynamic>{'huge': bigValue};
      final encoded = await codec.encode(value);
      expect(encoded, isNotEmpty);

      // Verify the raw encoding contains tag 2 (0xc2 prefix for tag 2).
      // Tag 2 in CBOR is encoded as 0xc2.
      final hasTag2 = encoded.any((b) => b == 0xc2);
      expect(hasTag2, isTrue, reason: 'Positive bignum should use tag 2');

      final decoded = await codec.decode(encoded);
      expect(decoded['huge'], equals(bigValue));
    });

    test('encodes negative BigInt beyond int64 with tag 3', () async {
      final bigValue = BigInt.parse('-9223372036854775809'); // -(2^63 + 1)
      final value = <String, dynamic>{'huge_neg': bigValue};
      final encoded = await codec.encode(value);
      expect(encoded, isNotEmpty);

      // Verify the raw encoding contains tag 3 (0xc3 prefix for tag 3).
      final hasTag3 = encoded.any((b) => b == 0xc3);
      expect(hasTag3, isTrue, reason: 'Negative bignum should use tag 3');

      final decoded = await codec.decode(encoded);
      expect(decoded['huge_neg'], equals(bigValue));
    });

    test('round-trips large positive BigInt', () async {
      final bigValue = BigInt.parse('123456789012345678901234567890');
      final value = <String, dynamic>{'value': bigValue};
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded['value'], equals(bigValue));
    });

    test('round-trips large negative BigInt', () async {
      final bigValue = BigInt.parse('-123456789012345678901234567890');
      final value = <String, dynamic>{'value': bigValue};
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded['value'], equals(bigValue));
    });

    test('round-trips BigInt zero', () async {
      final value = <String, dynamic>{'value': BigInt.zero};
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded['value'], equals(0));
    });

    test('encodes CID link with tag 42', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final value = <String, dynamic>{
        'link': {'/': cid.encode()},
      };
      final encoded = await codec.encode(value);
      expect(encoded, isNotEmpty);

      // Verify tag 42 is present (0xd8 0x2a in CBOR).
      for (var i = 0; i < encoded.length - 1; i++) {
        if (encoded[i] == 0xd8 && encoded[i + 1] == 0x2a) {
          return; // Found tag 42
        }
      }
      fail('Tag 42 (CID) not found in encoded DAG-CBOR');
    });

    test('round-trips CID link', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final value = <String, dynamic>{
        'link': {'/': cid.encode()},
      };
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('round-trips nested map with mixed types', () async {
      final cid = await CID.fromContent(Uint8List.fromList([4, 5, 6]));
      final value = <String, dynamic>{
        'name': 'test',
        'value': 42,
        'flag': true,
        'data': Uint8List.fromList([1, 2, 3]),
        'nested': <String, dynamic>{
          'inner': 'value',
          'link': {'/': cid.encode()},
        },
        'list': [1, 'two', false, null],
      };
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded['name'], equals('test'));
      expect(decoded['value'], equals(42));
      expect(decoded['flag'], equals(true));
      expect(decoded['data'], equals(Uint8List.fromList([1, 2, 3])));
      expect(decoded['nested']['inner'], equals('value'));
      expect(decoded['nested']['link'], equals({'/': cid.encode()}));
      expect(decoded['list'], equals([1, 'two', false, null]));
    });

    test('encodes double as 64-bit float', () async {
      final value = <String, dynamic>{'pi': 3.141592653589793};
      final encoded = await codec.encode(value);
      // 64-bit float in CBOR: major type 7, additional info 27 (0xfb).
      final hasDoubleFloat = encoded.any((b) => b == 0xfb);
      expect(
        hasDoubleFloat,
        isTrue,
        reason: 'DAG-CBOR must encode floats as 64-bit',
      );
    });

    test(
      'canonical encoding produces consistent bytes for same data',
      () async {
        final value = <String, dynamic>{
          'a': 1,
          'b': 'hello',
          'c': [1, 2, 3],
        };
        final encoded1 = await codec.encode(value);
        final encoded2 = await codec.encode(value);
        expect(encoded1, equals(encoded2));
      },
    );

    test('rejects unsupported types', () async {
      expect(() => codec.encode(Object()), throwsArgumentError);
    });

    test('handles empty map', () async {
      final encoded = await codec.encode(<String, dynamic>{});
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(<String, dynamic>{}));
    });

    test('handles empty list', () async {
      final encoded = await codec.encode(<dynamic>[]);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(<dynamic>[]));
    });

    test('handles null value', () async {
      final encoded = await codec.encode(null);
      final decoded = await codec.decode(encoded);
      expect(decoded, isNull);
    });
  });
}
