// Tests for the dag-cbor IPLD codec registration and behavior.
//
// `DagCborCodec` (multicodec `dag-cbor` / `0x71`) is registered with
// `IPLDHandler` by default; these tests pin down the codec-level contract:
// canonical encoding on the way out and lenient-but-safe decoding of
// historical data on the way in.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' as core;
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('DagCborCodec registry identity', () {
    final codec = DagCborCodec();

    test('reports the dag-cbor multicodec name and code 0x71', () {
      expect(codec.name, equals('dag-cbor'));
      expect(codec.code, equals(0x71));
      // ignore: deprecated_member_use_from_same_package
      expect(codec.identifier, equals('dag-cbor'));
      // The code must match the multicodec table entry.
      expect(core.Multicodec.code('dag-cbor'), equals(0x71));
      expect(core.Multicodec.name(0x71), equals('dag-cbor'));
    });
  });

  group('DagCborCodec canonical encoding', () {
    final codec = DagCborCodec();

    test('encodes maps with length-first canonical key ordering', () async {
      final node = _map({'aa': _int(2), 'b': _int(1)});
      final encoded = await codec.encode(node);
      expect(
        encoded,
        equals(
          Uint8List.fromList([0xa2, 0x61, 0x62, 0x01, 0x62, 0x61, 0x61, 0x02]),
        ),
      );
    });

    test('encode is deterministic across insertion order', () async {
      final a = await codec.encode(_map({'x': _int(1), 'y': _int(2)}));
      final b = await codec.encode(_map({'y': _int(2), 'x': _int(1)}));
      expect(a, equals(b));
    });

    test('encodes CID links as tag 42 with the 0x00 prefix', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final encoded = await codec.encode(_link(cid));
      expect(encoded[0], equals(0xd8));
      expect(encoded[1], equals(0x2a));
      expect(encoded[4], equals(0x00));

      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.LINK));
      expect(decoded.linkValue.version, equals(0));
    });

    test('rejects non-finite floats on encode', () async {
      final node = IPLDNode()
        ..kind = Kind.FLOAT
        ..floatValue = double.nan;
      expect(() => codec.encode(node), throwsA(isA<IPLDEncodingError>()));
    });
  });

  group('DagCborCodec decoding', () {
    final codec = DagCborCodec();

    test(
      'decodes loosely-encoded historical data (lenient by default)',
      () async {
        // Out-of-order map keys and a non-shortest integer are accepted by the
        // registered codec, matching the spec's allowance for relaxed decoding.
        final data = Uint8List.fromList([
          0xa2,
          0x61,
          0x62,
          0x02,
          0x61,
          0x61,
          0x01,
        ]);
        final node = await codec.decode(data);
        expect(node.kind, equals(Kind.MAP));
        expect(node.mapValue.entries.length, equals(2));
      },
    );

    test('still rejects non-IPLD tags and non-finite floats', () async {
      // Tag 0 (date/time string).
      expect(
        () => codec.decode(Uint8List.fromList([0xc0, 0x60])),
        throwsA(isA<IPLDDecodingError>()),
      );
      // float64 NaN.
      expect(
        () => codec.decode(
          Uint8List.fromList([0xfb, 0x7f, 0xf8, 0, 0, 0, 0, 0, 0]),
        ),
        throwsA(isA<IPLDDecodingError>()),
      );
    });

    test('round-trips a CIDv1 link through encode/decode', () async {
      final mh = Multihash.decode(
        Uint8List.fromList([0x12, 0x20, ...List.filled(32, 0x7b)]),
      );
      final cid = CID.v1('dag-cbor', mh);
      final encoded = await codec.encode(_link(cid));
      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.LINK));
      expect(decoded.linkValue.version, equals(1));
      expect(decoded.linkValue.codec, equals('dag-cbor'));
      expect(
        Uint8List.fromList(decoded.linkValue.multihash),
        equals(cid.multihash.toBytes()),
      );
    });
  });
}

IPLDNode _int(int v) => IPLDNode()
  ..kind = Kind.INTEGER
  ..intValue = Int64(v);

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
