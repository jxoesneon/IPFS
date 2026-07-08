import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('EnhancedCBORHandler', () {
    group('cborTags', () {
      test('contains the standard IPLD CBOR tags', () {
        expect(EnhancedCBORHandler.cborTags[0x02], equals('positive-bignum'));
        expect(EnhancedCBORHandler.cborTags[0x03], equals('negative-bignum'));
        expect(EnhancedCBORHandler.cborTags[0x2a], equals('cid-link'));
        expect(EnhancedCBORHandler.cborTags.containsKey(45), isFalse);
      });
    });

    group('Encoding and decoding primitives', () {
      test('round-trips null, bool, int, float, string', () {
        final scenarios = [
          (Kind.NULL, _nullNode()),
          (Kind.BOOL, _boolNode(true)),
          (Kind.INTEGER, _intNode(42)),
          (
            Kind.FLOAT,
            IPLDNode()
              ..kind = Kind.FLOAT
              ..floatValue = 3.14,
          ),
          (Kind.STRING, _strNode('s')),
        ];

        for (final (expectedKind, node) in scenarios) {
          final bytes = EnhancedCBORHandler.encodeDagCbor(node);
          final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
          expect(decoded.kind, equals(expectedKind));
        }
      });

      test('round-trips int64 boundary values', () {
        final max = Int64(9223372036854775807);
        final min = Int64(-9223372036854775808);

        final maxNode = IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = max;
        final minNode = IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = min;

        expect(
          EnhancedCBORHandler.decodeDagCbor(
            EnhancedCBORHandler.encodeDagCbor(maxNode),
          ).intValue,
          equals(max),
        );
        expect(
          EnhancedCBORHandler.decodeDagCbor(
            EnhancedCBORHandler.encodeDagCbor(minNode),
          ).intValue,
          equals(min),
        );
      });
    });

    group('Bytes', () {
      test('round-trips raw bytes as plain CBOR byte strings', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final node = _bytesNode(data);

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        // Plain major type 2 byte string of length 3.
        expect(bytes, equals(Uint8List.fromList([0x43, 1, 2, 3])));

        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BYTES));
        expect(decoded.bytesValue, equals(data));
      });

      test('rejects non-standard tag 45 bytes', () {
        // Tag 45 (0xd8 0x2d) applied to a 1-byte byte string.
        final bytes = Uint8List.fromList([0xd8, 0x2d, 0x41, 0x00]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });
    });

    group('Links', () {
      test('round-trips CIDv0 as CBOR tag 42', () {
        final cid = CID.decode(
          'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        );
        final node = _linkNode(cid);

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        expect(bytes.sublist(0, 2), equals(Uint8List.fromList([0xd8, 0x2a])));

        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.LINK));
        expect(decoded.linkValue.version, equals(0));
        expect(decoded.linkValue.codec, equals('dag-pb'));
        expect(decoded.linkValue.multihash, equals(cid.multihash.toBytes()));
      });

      test('round-trips CIDv1 dag-pb as CBOR tag 42', () {
        final cid = CID.v1('dag-pb', _dummyMultihash());
        final node = _linkNode(cid);

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        expect(bytes.sublist(0, 2), equals(Uint8List.fromList([0xd8, 0x2a])));

        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.LINK));
        expect(decoded.linkValue.version, equals(1));
        expect(decoded.linkValue.codec, equals('dag-pb'));
      });

      test('round-trips CIDv1 dag-json as CBOR tag 42', () {
        final cid = CID.v1('dag-json', _dummyMultihash());
        final node = _linkNode(cid);

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.linkValue.version, equals(1));
        expect(decoded.linkValue.codec, equals('dag-json'));
      });

      test('round-trips CIDv1 raw as CBOR tag 42', () {
        final cid = CID.v1('raw', _dummyMultihash());
        final node = _linkNode(cid);

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.linkValue.codec, equals('raw'));
      });
    });

    group('Canonical map ordering', () {
      test('encoder sorts keys by length then lexicographic order', () {
        final node = _mapNode({
          'b': _intNode(2),
          'aa': _intNode(3),
          'a': _intNode(1),
        });

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        final expected = Uint8List.fromList([
          0xA3, // map of 3
          0x61, 0x61, 0x01, // "a": 1
          0x61, 0x62, 0x02, // "b": 2
          0x62, 0x61, 0x61, 0x03, // "aa": 3
        ]);
        expect(bytes, equals(expected));
      });

      test(
        'same logical map produces identical bytes regardless of insertion order',
        () {
          final node1 = _mapNode({'b': _intNode(2), 'a': _intNode(1)});
          final node2 = _mapNode({'a': _intNode(1), 'b': _intNode(2)});

          expect(
            EnhancedCBORHandler.encodeDagCbor(node1),
            equals(EnhancedCBORHandler.encodeDagCbor(node2)),
          );
        },
      );

      test('round-trips complex nested map and list', () {
        final node = _mapNode({
          'list': _listNode([_intNode(1), _strNode('two')]),
          'map': _mapNode({'inner': _boolNode(false)}),
        });

        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.MAP));
        expect(decoded.mapValue.entries.length, equals(2));
      });
    });

    group('Big integers', () {
      test('2^64 - 1 encodes as unsigned major type 0', () {
        final bytes = Uint8List.fromList([
          0x1b,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
        ]);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BIG_INT));
        expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
      });

      test('2^64 encodes as CBOR tag 2', () {
        final bytes = Uint8List.fromList([
          0xC2, // tag 2
          0x49, // byte string of length 9
          0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BIG_INT));
        expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
      });

      test('-2^64 encodes as CBOR negative major type 1, not tag 3', () {
        final bytes = Uint8List.fromList([
          0x3b,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
          0xff,
        ]);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BIG_INT));
        expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
        // The first byte must be major type 1 (0x3b), not tag 3 (0xC3).
        expect(bytes[0], equals(0x3b));
      });

      test('-2^64 - 1 encodes as CBOR tag 3', () {
        final bytes = Uint8List.fromList([
          0xC3, // tag 3
          0x49, // byte string of length 9
          0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);
        final decoded = EnhancedCBORHandler.decodeDagCbor(bytes);
        expect(decoded.kind, equals(Kind.BIG_INT));
        expect(EnhancedCBORHandler.encodeDagCbor(decoded), equals(bytes));
      });
    });

    group('Strict decoding', () {
      test('rejects unknown tags', () {
        // Tag 1 (date/time) is not allowed in DAG-CBOR.
        final bytes = Uint8List.fromList([0xC1, 0x00]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('rejects duplicate map keys', () {
        final bytes = Uint8List.fromList([
          0xA2, // map of 2
          0x61, 0x61, 0x01, // "a": 1
          0x61, 0x61, 0x02, // "a": 2
        ]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('rejects non-canonical map key order', () {
        // "b" should come after "a" in canonical order.
        final bytes = Uint8List.fromList([
          0xA2, // map of 2
          0x61, 0x62, 0x02, // "b": 2
          0x61, 0x61, 0x01, // "a": 1
        ]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('rejects non-canonical integer encodings', () {
        // Value 1 encoded with additional 24 instead of inline.
        final bytes = Uint8List.fromList([0x18, 0x01]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('rejects non-minimal big-integer byte strings', () {
        // Value 258 with a leading zero byte.
        final bytes = Uint8List.fromList([
          0xC2, // tag 2
          0x43, // byte string of length 3
          0x00, 0x01, 0x02,
        ]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('rejects indefinite-length items', () {
        // Indefinite-length map: 0xbf ... 0xff.
        final bytes = Uint8List.fromList([0xbf, 0x61, 0x61, 0x01, 0xff]);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes),
          throwsA(isA<IPLDDecodingError>()),
        );
      });
    });

    group('DagCborOptions limits', () {
      test('maxStringLength is enforced during decoding', () {
        // A string of 10 'a' characters with a 5-byte limit.
        final bytes = Uint8List.fromList([0x6a] + List.filled(10, 0x61));
        const options = DagCborOptions(maxStringLength: 5);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes, options: options),
          throwsA(isA<IPLDDecodingError>()),
        );
      });

      test('maxDepth is enforced during decoding', () {
        const options = DagCborOptions(maxDepth: 2);
        final node = _listNode([
          _listNode([
            _listNode([_intNode(1)]),
          ]),
        ]);
        final bytes = EnhancedCBORHandler.encodeDagCbor(node);
        expect(
          () => EnhancedCBORHandler.decodeDagCbor(bytes, options: options),
          throwsA(isA<IPLDDecodingError>()),
        );
      });
    });

    group('MerkleDAG conversion', () {
      test('convertFromMerkleDAGNode correctly shapes IPLDMap', () {
        final data = Uint8List.fromList([0xAA, 0xBB]);
        final link = Link(
          name: 'link1',
          cid: CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z'),
          size: 100,
        );
        final dagNode = MerkleDAGNode(data: data, links: [link]);

        final ipldNode = EnhancedCBORHandler.convertFromMerkleDAGNode(dagNode);
        expect(ipldNode.kind, equals(Kind.MAP));

        final mapEntries = ipldNode.mapValue.entries;
        expect(mapEntries.any((e) => e.key == 'Data'), isTrue);
        expect(mapEntries.any((e) => e.key == 'Links'), isTrue);

        final linksNode = mapEntries.firstWhere((e) => e.key == 'Links').value;
        expect(linksNode.kind, equals(Kind.LIST));
        expect(linksNode.listValue.values.length, equals(1));

        final linkMap = linksNode.listValue.values.first;
        expect(linkMap.kind, equals(Kind.MAP));
        final linkEntries = linkMap.mapValue.entries;
        expect(
          linkEntries.any(
            (e) => e.key == 'Name' && e.value.stringValue == 'link1',
          ),
          isTrue,
        );
        expect(
          linkEntries.any((e) => e.key == 'Hash' && e.value.kind == Kind.LINK),
          isTrue,
        );
        expect(
          linkEntries.any(
            (e) => e.key == 'Tsize' && e.value.intValue == Int64(100),
          ),
          isTrue,
        );
      });

      test('convertToMerkleLink converts IPLDNode map back to Link', () {
        final cid = CID.decode(
          'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        );
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.add(
              MapEntry()
                ..key = 'Name'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'linkName'),
            )
            ..entries.add(
              MapEntry()
                ..key = 'Tsize'
                ..value = (IPLDNode()
                  ..kind = Kind.INTEGER
                  ..intValue = Int64(50)),
            )
            ..entries.add(
              MapEntry()
                ..key = 'Hash'
                ..value = (IPLDNode()
                  ..kind = Kind.LINK
                  ..linkValue = (IPLDLink()
                    ..version = 0
                    ..codec = 'dag-pb'
                    ..multihash = cid.multihash.toBytes())),
            ));

        final link = EnhancedCBORHandler.convertToMerkleLink(node);
        expect(link.name, equals('linkName'));
        expect(link.size.toInt(), equals(50));
        expect(link.cid.multihash.digest, equals(cid.multihash.digest));
      });

      test('convertToMerkleLink handles BYTES Hash fallback', () {
        final cid = CID.decode(
          'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        );
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.add(
              MapEntry()
                ..key = 'Hash'
                ..value = (IPLDNode()
                  ..kind = Kind.BYTES
                  ..bytesValue = cid.multihash.toBytes()),
            ));

        final link = EnhancedCBORHandler.convertToMerkleLink(node);
        expect(link.name, isEmpty);
        expect(link.size.toInt(), equals(0));
        expect(link.cid.multihash.digest, equals(cid.multihash.digest));
      });

      test('convertToMerkleLink throws if not MAP', () {
        expect(
          () => EnhancedCBORHandler.convertToMerkleLink(
            IPLDNode()..kind = Kind.STRING,
          ),
          throwsA(isA<IPLDEncodingError>()),
        );
      });
    });
  });
}

IPLDNode _nullNode() => IPLDNode()..kind = Kind.NULL;

IPLDNode _boolNode(bool value) => IPLDNode()
  ..kind = Kind.BOOL
  ..boolValue = value;

IPLDNode _intNode(int value) => IPLDNode()
  ..kind = Kind.INTEGER
  ..intValue = Int64(value);

IPLDNode _strNode(String value) => IPLDNode()
  ..kind = Kind.STRING
  ..stringValue = value;

IPLDNode _bytesNode(List<int> value) => IPLDNode()
  ..kind = Kind.BYTES
  ..bytesValue = value;

IPLDNode _listNode(List<IPLDNode> values) {
  final list = IPLDList();
  for (final value in values) {
    list.values.add(value);
  }
  return IPLDNode()
    ..kind = Kind.LIST
    ..listValue = list;
}

IPLDNode _mapNode(Map<String, IPLDNode> entries) {
  final map = IPLDMap();
  entries.forEach((key, value) {
    map.entries.add(
      MapEntry()
        ..key = key
        ..value = value,
    );
  });
  return IPLDNode()
    ..kind = Kind.MAP
    ..mapValue = map;
}

IPLDNode _linkNode(CID cid) => IPLDNode()
  ..kind = Kind.LINK
  ..linkValue = (IPLDLink()
    ..version = cid.version
    ..codec = cid.codec ?? 'unknown'
    ..multihash = cid.multihash.toBytes());

MultihashInfo _dummyMultihash() {
  final bytes = Uint8List.fromList([0x12, 0x20] + List.filled(32, 0));
  return Multihash.decode(bytes);
}
