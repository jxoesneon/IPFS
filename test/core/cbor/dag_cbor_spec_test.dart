// Spec-compliance tests for DAG-CBOR per
// https://ipld.io/specs/codecs/dag-cbor/spec/
//
// Covers the strictness rules (canonical integer/length/tag encodings,
// length-first map key ordering, tag-42 CID links, float rules) using
// byte-level vectors.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('DAG-CBOR spec vectors', () {
    test('primitive scalars encode to canonical CBOR', () {
      final cases = <IPLDNode Function(), List<int>>{
        () => IPLDNode()..kind = Kind.NULL: [0xf6],
        () => _bool(false): [0xf4],
        () => _bool(true): [0xf5],
        () => _int(0): [0x00],
        () => _int(23): [0x17],
        () => _int(24): [0x18, 0x18],
        () => _int(255): [0x18, 0xff],
        () => _int(256): [0x19, 0x01, 0x00],
        () => _int(-1): [0x20],
        () => _int(-24): [0x37],
        () => _int(-25): [0x38, 0x18],
        () => _str(''): [0x60],
        () => _str('a'): [0x61, 0x61],
        () => _str('hello'): [0x65, 0x68, 0x65, 0x6c, 0x6c, 0x6f],
        () => _bytes([]): [0x40],
        () => _bytes([0x01, 0x02]): [0x42, 0x01, 0x02],
      };
      for (final entry in cases.entries) {
        expect(
          EnhancedCBORHandler.encodeDagCbor(entry.key()),
          equals(Uint8List.fromList(entry.value)),
          reason: 'unexpected canonical bytes for ${entry.value}',
        );
      }
    });

    test('floats always encode as 64-bit', () {
      final bytes = EnhancedCBORHandler.encodeDagCbor(_float(1.5));
      expect(
        bytes,
        equals(Uint8List.fromList([0xfb, 0x3f, 0xf8, 0, 0, 0, 0, 0, 0])),
      );
      // Even a value representable in half precision stays 64-bit.
      final one = EnhancedCBORHandler.encodeDagCbor(_float(1.0));
      expect(one.length, equals(9));
      expect(one[0], equals(0xfb));
    });

    test('-0.0 encodes as positive zero', () {
      final bytes = EnhancedCBORHandler.encodeDagCbor(_float(-0.0));
      expect(bytes, equals(Uint8List.fromList([0xfb, 0, 0, 0, 0, 0, 0, 0, 0])));
    });

    test('encoding NaN or Infinity throws', () {
      expect(
        () => EnhancedCBORHandler.encodeDagCbor(_float(double.nan)),
        throwsA(isA<IPLDEncodingError>()),
      );
      expect(
        () => EnhancedCBORHandler.encodeDagCbor(_float(double.infinity)),
        throwsA(isA<IPLDEncodingError>()),
      );
      expect(
        () =>
            EnhancedCBORHandler.encodeDagCbor(_float(double.negativeInfinity)),
        throwsA(isA<IPLDEncodingError>()),
      );
    });

    test('lists and maps encode canonically', () {
      expect(
        EnhancedCBORHandler.encodeDagCbor(_list([_int(1), _int(2), _int(3)])),
        equals(Uint8List.fromList([0x83, 0x01, 0x02, 0x03])),
      );
      expect(
        EnhancedCBORHandler.encodeDagCbor(_map({'a': _int(1)})),
        equals(Uint8List.fromList([0xa1, 0x61, 0x61, 0x01])),
      );
      // Length-first ordering: "b" before "aa" even though "aa" < "b"
      // lexicographically.
      expect(
        EnhancedCBORHandler.encodeDagCbor(_map({'aa': _int(2), 'b': _int(1)})),
        equals(
          Uint8List.fromList([0xa2, 0x61, 0x62, 0x01, 0x62, 0x61, 0x61, 0x02]),
        ),
      );
    });
  });

  group('CID links (tag 42)', () {
    test('CIDv0 encodes as d82a + bytes(0x00 || multihash)', () {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final bytes = EnhancedCBORHandler.encodeDagCbor(_link(cid));
      // 0xd8 0x2a, byte string of length 35 (0x58 0x23), 0x00 prefix,
      // then the 34-byte sha2-256 multihash.
      expect(bytes[0], equals(0xd8));
      expect(bytes[1], equals(0x2a));
      expect(bytes[2], equals(0x58));
      expect(bytes[3], equals(0x23));
      expect(bytes[4], equals(0x00));
      expect(bytes.length, equals(39));
      expect(bytes.sublist(5), equals(cid.multihash.toBytes()));
    });

    test('CIDv1 dag-pb encodes as d82a + bytes(0x00 || cidv1)', () {
      final mh = Multihash.decode(
        Uint8List.fromList([0x12, 0x20, ...List.filled(32, 0xab)]),
      );
      final cid = CID.v1('dag-pb', mh);
      final bytes = EnhancedCBORHandler.encodeDagCbor(_link(cid));
      // 0x00 || 0x01 0x70 0x12 0x20 <32B> = 37 bytes -> 0x58 0x25.
      expect(
        bytes.sublist(0, 5),
        equals(Uint8List.fromList([0xd8, 0x2a, 0x58, 0x25, 0x00])),
      );
      expect(
        bytes.sublist(5, 9),
        equals(Uint8List.fromList([0x01, 0x70, 0x12, 0x20])),
      );
    });

    test('decoding tag 42 requires the 0x00 identity prefix', () {
      // Valid framing, but the byte string does not start with 0x00.
      final bad = Uint8List.fromList([0xd8, 0x2a, 0x41, 0x01]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(bad),
        throwsA(isA<IPLDDecodingError>()),
      );
      // Empty byte string.
      final empty = Uint8List.fromList([0xd8, 0x2a, 0x40]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(empty),
        throwsA(isA<IPLDDecodingError>()),
      );
      // Tag 42 applied to a non-byte-string.
      final notBytes = Uint8List.fromList([0xd8, 0x2a, 0x01]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(notBytes),
        throwsA(isA<IPLDDecodingError>()),
      );
    });

    test('strict mode requires the 0xd82a tag token', () {
      // Tag 42 encoded in its longest (8-byte) form is non-canonical.
      final nonCanonical = Uint8List.fromList([
        0xdb,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x2a,
        0x41,
        0x00,
      ]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(nonCanonical),
        throwsA(isA<IPLDDecodingError>()),
      );
      // Lenient mode accepts it; the inner CID is still invalid though, so
      // use a valid CID payload to prove the tag itself was accepted.
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final lenientOk = Uint8List.fromList([
        0xdb,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x2a,
        0x58,
        0x23,
        0x00,
        ...cid.multihash.toBytes(),
      ]);
      final node = EnhancedCBORHandler.decodeDagCbor(lenientOk, strict: false);
      expect(node.kind, equals(Kind.LINK));
    });

    test('strict mode rejects non-canonical inner byte-string length', () {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      // Length 35 expressed with a 4-byte argument (0x5a) is non-canonical.
      final bytes = Uint8List.fromList([
        0xd8,
        0x2a,
        0x5a,
        0,
        0,
        0,
        0x23,
        0x00,
        ...cid.multihash.toBytes(),
      ]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(bytes),
        throwsA(isA<IPLDDecodingError>()),
      );
      final node = EnhancedCBORHandler.decodeDagCbor(bytes, strict: false);
      expect(node.kind, equals(Kind.LINK));
    });

    test('encoder rejects malformed links', () {
      // CIDv0 link whose multihash is not a 34-byte sha2-256.
      final badV0 = IPLDNode()
        ..kind = Kind.LINK
        ..linkValue = (IPLDLink()
          ..version = 0
          ..codec = 'dag-pb'
          ..multihash = [0x12, 0x20, 0x01]);
      expect(
        () => EnhancedCBORHandler.encodeDagCbor(badV0),
        throwsA(isA<IPLDEncodingError>()),
      );
      // Unknown CID version.
      final badVersion = IPLDNode()
        ..kind = Kind.LINK
        ..linkValue = (IPLDLink()
          ..version = 2
          ..codec = 'dag-pb'
          ..multihash = [0x12, 0x20, ...List.filled(32, 0)]);
      expect(
        () => EnhancedCBORHandler.encodeDagCbor(badVersion),
        throwsA(isA<IPLDEncodingError>()),
      );
    });
  });

  group('Strictness', () {
    test('rejects all non-IPLD tags', () {
      final tagged = <Uint8List>[
        // Tag 0 (standard date/time string).
        Uint8List.fromList([0xc0, 0x60]),
        // Tag 1 (epoch-based date).
        Uint8List.fromList([0xc1, 0x00]),
        // Tag 32 (URI).
        Uint8List.fromList([0xd8, 0x20, 0x60]),
        // Tag 55799 (self-described CBOR).
        Uint8List.fromList([0xd9, 0xd9, 0xf7, 0x00]),
      ];
      for (final bytes in tagged) {
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
          reason: 'tagged item $bytes must be rejected',
        );
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes, strict: false),
          throwsA(isA<IPLDDecodingError>()),
          reason: 'tagged item $bytes must be rejected even when lenient',
        );
      }
    });

    test('rejects non-string map keys', () {
      // {1: 2}
      final bytes = Uint8List.fromList([0xa1, 0x01, 0x02]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(bytes),
        throwsA(isA<IPLDDecodingError>()),
      );
    });

    test('rejects indefinite-length items and break', () {
      final inputs = <Uint8List>[
        Uint8List.fromList([0x9f, 0x01, 0xff]), // indefinite array
        Uint8List.fromList([0x5f, 0x41, 0x00, 0xff]), // indefinite bytes
        Uint8List.fromList([0x7f, 0x61, 0x61, 0xff]), // indefinite text
        Uint8List.fromList([0xff]), // stray break
      ];
      for (final bytes in inputs) {
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes, strict: false),
          throwsA(isA<IPLDDecodingError>()),
        );
      }
    });

    test('rejects unsupported simple values', () {
      // undefined
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(Uint8List.fromList([0xf7])),
        throwsA(isA<IPLDDecodingError>()),
      );
      // simple(32) via two-byte form
      expect(
        () =>
            EnhancedCBORHandler.decodeDagCbor(Uint8List.fromList([0xf8, 0x20])),
        throwsA(isA<IPLDDecodingError>()),
      );
      // simple(0) unassigned
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(Uint8List.fromList([0xe0])),
        throwsA(isA<IPLDDecodingError>()),
      );
    });

    test('rejects non-finite floats in every mode', () {
      final nonFinite = <Uint8List>[
        // float64 NaN (canonical quiet NaN payload)
        Uint8List.fromList([0xfb, 0x7f, 0xf8, 0, 0, 0, 0, 0, 0]),
        // float64 NaN with a non-canonical payload
        Uint8List.fromList([0xfb, 0x7f, 0xf8, 0, 0, 0, 0, 0, 1]),
        // float64 +Infinity
        Uint8List.fromList([0xfb, 0x7f, 0xf0, 0, 0, 0, 0, 0, 0]),
        // float64 -Infinity
        Uint8List.fromList([0xfb, 0xff, 0xf0, 0, 0, 0, 0, 0, 0]),
        // float32 Infinity
        Uint8List.fromList([0xfa, 0x7f, 0x80, 0, 0]),
        // float16 NaN
        Uint8List.fromList([0xf9, 0x7e, 0x00]),
      ];
      for (final bytes in nonFinite) {
        for (final strict in [true, false]) {
          expect(
            () => EnhancedCBORHandler.decodeDagCbor(bytes, strict: strict),
            throwsA(isA<IPLDDecodingError>()),
            reason: '$bytes (strict=$strict) must be rejected',
          );
        }
      }
    });

    test('rejects 16/32-bit floats in strict mode, accepts when lenient', () {
      // float16 1.0
      final f16 = Uint8List.fromList([0xf9, 0x3c, 0x00]);
      // float32 1.5
      final f32 = Uint8List.fromList([0xfa, 0x3f, 0xc0, 0x00, 0x00]);
      for (final bytes in [f16, f32]) {
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
        final node = EnhancedCBORHandler.decodeDagCbor(bytes, strict: false);
        expect(node.kind, equals(Kind.FLOAT));
      }
      // Regression: half-precision decode must scale the mantissa by 2^-10 —
      // f16 0x3c00 is exactly 1.0, f32 0x3fc00000 is exactly 1.5.
      expect(
        EnhancedCBORHandler.decodeDagCbor(f16, strict: false).floatValue,
        equals(1.0),
      );
      expect(
        EnhancedCBORHandler.decodeDagCbor(f32, strict: false).floatValue,
        equals(1.5),
      );
    });

    test('rejects -0.0 in strict mode, normalizes when lenient', () {
      final negZero = Uint8List.fromList([0xfb, 0x80, 0, 0, 0, 0, 0, 0, 0]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(negZero),
        throwsA(isA<IPLDDecodingError>()),
      );
      final node = EnhancedCBORHandler.decodeDagCbor(negZero, strict: false);
      expect(node.kind, equals(Kind.FLOAT));
      expect(node.floatValue, equals(0.0));
      expect(node.floatValue.isNegative, isFalse);
    });

    test('rejects extraneous bytes after the top-level item', () {
      final bytes = Uint8List.fromList([0x01, 0x02]);
      expect(
        () => EnhancedCBORHandler.decodeDagCbor(bytes, strict: false),
        throwsA(isA<IPLDDecodingError>()),
      );
    });

    test('lenient mode accepts non-canonical ints and unordered maps', () {
      // Non-shortest integer encoding.
      final laxInt = EnhancedCBORHandler.decodeDagCbor(
        Uint8List.fromList([0x18, 0x01]),
        strict: false,
      );
      expect(laxInt.intValue, equals(Int64(1)));
      // Out-of-order map keys.
      final laxMap = EnhancedCBORHandler.decodeDagCbor(
        Uint8List.fromList([0xa2, 0x61, 0x62, 0x02, 0x61, 0x61, 0x01]),
        strict: false,
      );
      expect(laxMap.kind, equals(Kind.MAP));
      expect(laxMap.mapValue.entries.length, equals(2));
    });

    test('duplicate map keys are rejected in every mode', () {
      final bytes = Uint8List.fromList([
        0xa2,
        0x61,
        0x61,
        0x01,
        0x61,
        0x61,
        0x02,
      ]);
      for (final strict in [true, false]) {
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes, strict: strict),
          throwsA(isA<IPLDDecodingError>()),
        );
      }
    });

    test('encoder rejects duplicate map keys', () {
      final map = IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'a'
            ..value = _int(1),
          MapEntry()
            ..key = 'a'
            ..value = _int(2),
        ]);
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = map;
      expect(
        () => EnhancedCBORHandler.encodeDagCbor(node),
        throwsA(isA<IPLDEncodingError>()),
      );
    });
  });

  group('Big integers (tags 2 and 3)', () {
    test('2^100 round-trips via tag 2', () {
      // 2^100 = 0x10 followed by 12 zero bytes (13 bytes total).
      final payload = [0x10, ...List.filled(12, 0x00)];
      final bytes = Uint8List.fromList([0xc2, 0x4d, ...payload]);
      final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
      expect(decoded.kind, equals(Kind.BIG_INT));
      expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
    });

    test('-(2^100) round-trips via tag 3', () {
      // Tag 3 stores n where value = -(1 + n); for -(2^100), n = 2^100 - 1
      // = 0x0f followed by 12 0xff bytes.
      final payload = [0x0f, ...List.filled(12, 0xff)];
      final bytes = Uint8List.fromList([0xc3, 0x4d, ...payload]);
      final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
      expect(decoded.kind, equals(Kind.BIG_INT));
      expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
    });

    test('strict mode rejects tags 2/3 for in-range values', () {
      // Tag 2 of h'01' is just 1; must be plain major type 0.
      final smallPos = Uint8List.fromList([0xc2, 0x41, 0x01]);
      // Tag 3 of h'00' is -1; must be plain major type 1.
      final smallNeg = Uint8List.fromList([0xc3, 0x41, 0x00]);
      // Tag 2 of 2^64 - 1 (8 bytes) fits in major type 0.
      final maxU64 = Uint8List.fromList([0xc2, 0x48, ...List.filled(8, 0xff)]);
      for (final bytes in [smallPos, smallNeg, maxU64]) {
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
          reason: '$bytes must be rejected in strict mode',
        );
      }
      // Lenient decoding still yields the right values.
      expect(
        EnhancedCBORHandler.decodeDagCbor(smallPos, strict: false).intValue,
        equals(Int64(1)),
      );
      expect(
        EnhancedCBORHandler.decodeDagCbor(smallNeg, strict: false).intValue,
        equals(Int64(-1)),
      );
    });

    test('tag 2/3 applied to a non-byte-string is rejected', () {
      expect(
        () =>
            EnhancedCBORHandler.decodeDagCbor(Uint8List.fromList([0xc2, 0x01])),
        throwsA(isA<IPLDDecodingError>()),
      );
      expect(
        () =>
            EnhancedCBORHandler.decodeDagCbor(Uint8List.fromList([0xc3, 0x60])),
        throwsA(isA<IPLDDecodingError>()),
      );
    });
  });
}

IPLDNode _bool(bool v) => IPLDNode()
  ..kind = Kind.BOOL
  ..boolValue = v;

IPLDNode _int(int v) => IPLDNode()
  ..kind = Kind.INTEGER
  ..intValue = Int64(v);

IPLDNode _float(double v) => IPLDNode()
  ..kind = Kind.FLOAT
  ..floatValue = v;

IPLDNode _str(String v) => IPLDNode()
  ..kind = Kind.STRING
  ..stringValue = v;

IPLDNode _bytes(List<int> v) => IPLDNode()
  ..kind = Kind.BYTES
  ..bytesValue = v;

IPLDNode _list(List<IPLDNode> values) => IPLDNode()
  ..kind = Kind.LIST
  ..listValue = (IPLDList()..values.addAll(values));

IPLDNode _map(Map<String, IPLDNode> entries) {
  final map = IPLDMap();
  entries.forEach((k, v) {
    map.entries.add(
      MapEntry()
        ..key = k
        ..value = v,
    );
  });
  return IPLDNode()
    ..kind = Kind.MAP
    ..mapValue = map;
}

IPLDNode _link(CID cid) => IPLDNode()
  ..kind = Kind.LINK
  ..linkValue = (IPLDLink()
    ..version = cid.version
    ..codec = cid.codec ?? 'unknown'
    ..multihash = cid.multihash.toBytes());
