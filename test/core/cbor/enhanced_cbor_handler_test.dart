import 'dart:typed_data';

import 'package:cbor/cbor.dart';
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
    group('Tags', () {
      test('cborTags contains correct mappings', () {
        expect(EnhancedCBORHandler.cborTags[0x55], equals('raw'));
        expect(EnhancedCBORHandler.cborTags[0x70], equals('dag-pb'));
        expect(EnhancedCBORHandler.cborTags[6], equals('cid-link'));
      });
    });

    group('Encoding', () {
      test('encodes and decodes primitives', () async {
        final scenarios = [
          (IPLDNode()..kind = Kind.NULL, Kind.NULL),
          (
            IPLDNode()
              ..kind = Kind.BOOL
              ..boolValue = true,
            Kind.BOOL,
          ),
          (
            IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(42),
            Kind.INTEGER,
          ),
          (
            IPLDNode()
              ..kind = Kind.FLOAT
              ..floatValue = 3.14,
            Kind.FLOAT,
          ),
          (
            IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = 's',
            Kind.STRING,
          ),
        ];

        for (final (node, kind) in scenarios) {
          final bytes = await EnhancedCBORHandler.encodeCbor(node);
          final decoded = await EnhancedCBORHandler.decodeCborWithTags(bytes);
          expect(decoded.kind, equals(kind));
        }
      });

      test('encodes and decodes BYTES (Tag 45)', () async {
        final data = Uint8List.fromList([1, 2, 3]);
        final node = IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = data;

        final bytes = await EnhancedCBORHandler.encodeCbor(node);
        // Verify tag 45 is present? CborEncoder implementation detail.
        // But decoding should work.
        final decoded = await EnhancedCBORHandler.decodeCborWithTags(bytes);
        expect(decoded.kind, equals(Kind.BYTES));
        expect(decoded.bytesValue, equals(data));
      });

      test('encodes and decodes CID LINK (Tag 6)', () async {
        final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z'); // V0
        final node = IPLDNode()
          ..kind = Kind.LINK
          ..linkValue = (IPLDLink()
            ..version = cid.version
            ..codec = 'dag-pb'
            ..multihash = cid.multihash.toBytes());

        final bytes = await EnhancedCBORHandler.encodeCbor(node);
        final decoded = await EnhancedCBORHandler.decodeCborWithTags(bytes);

        expect(decoded.kind, equals(Kind.LINK));
        // Decoded CID might be V1 logic applied in handler
        expect(decoded.linkValue.codec, equals('dag-pb'));
      });

      test('encodes and decodes CID V1 LINK (Tag 6)', () async {
        // Manually construct CID V1
        final multihash = Uint8List.fromList(
          [0x12, 0x20] + List.filled(32, 0),
        ); // Valid dummy multihash (sha2-256)
        final mhInfo = Multihash.decode(multihash);
        final cid = CID.v1('dag-pb', mhInfo);

        final node = IPLDNode()
          ..kind = Kind.LINK
          ..linkValue = (IPLDLink()
            ..version = cid.version
            ..codec = 'dag-pb'
            ..multihash = cid.multihash.toBytes());

        final bytes = await EnhancedCBORHandler.encodeCbor(node);
        final decoded = await EnhancedCBORHandler.decodeCborWithTags(bytes);

        expect(decoded.kind, equals(Kind.LINK));
        expect(decoded.linkValue.codec, equals('dag-pb'));
        expect(decoded.linkValue.version, equals(1));
      });

      test('encodes and decodes LIST and MAP', () async {
        // Recursive complex structure
        final list = IPLDList();
        list.values.add(
          IPLDNode()
            ..kind = Kind.INTEGER
            ..intValue = Int64(1),
        );

        final map = IPLDMap();
        map.entries.add(
          MapEntry()
            ..key = 'key'
            ..value = (IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = 'val'),
        );

        final nodeMap = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = map;
        final nodeList = IPLDNode()
          ..kind = Kind.LIST
          ..listValue = list;

        final bytesMap = await EnhancedCBORHandler.encodeCbor(nodeMap);
        final decodedMap = await EnhancedCBORHandler.decodeCborWithTags(bytesMap);
        expect(decodedMap.kind, equals(Kind.MAP));

        final bytesList = await EnhancedCBORHandler.encodeCbor(nodeList);
        final decodedList = await EnhancedCBORHandler.decodeCborWithTags(bytesList);
        expect(decodedList.kind, equals(Kind.LIST));
      });
    });

    group('MerkleDAG Conversion', () {
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

        // Verify Data and Links entries
        final mapEntries = ipldNode.mapValue.entries;
        expect(mapEntries.any((e) => e.key == 'Data'), isTrue);
        expect(mapEntries.any((e) => e.key == 'Links'), isTrue);

        final linksNode = mapEntries.firstWhere((e) => e.key == 'Links').value;
        expect(linksNode.kind, equals(Kind.LIST));
        expect(linksNode.listValue.values.length, equals(1));

        final linkMap = linksNode.listValue.values.first;
        expect(linkMap.kind, equals(Kind.MAP));
        // Verify Link fields: Name, Hash, Tsize
        final linkEntries = linkMap.mapValue.entries;
        expect(linkEntries.any((e) => e.key == 'Name' && e.value.stringValue == 'link1'), isTrue);
        expect(linkEntries.any((e) => e.key == 'Hash' && e.value.kind == Kind.LINK), isTrue);
        expect(linkEntries.any((e) => e.key == 'Tsize' && e.value.intValue == Int64(100)), isTrue);
      });

      test('convertToMerkleLink converts IPLDNode map back to Link', () {
        // Construct IPLD map manually
        final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
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

      test('convertToMerkleLink handles hash as bytes (legacy)', () {
        final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z'); // V0 multihash
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
        // Default name is empty, size is 0
        expect(link.name, isEmpty);
        expect(link.size.toInt(), equals(0));
        expect(link.cid.multihash.digest, equals(cid.multihash.digest));
      });

      test('convertToMerkleLink throws if not MAP', () {
        expect(
          () => EnhancedCBORHandler.convertToMerkleLink(IPLDNode()..kind = Kind.STRING),
          throwsA(isA<IPLDEncodingError>()),
        );
      });
    });

    group('Error Handling', () {
      test('convertCborValueToIPLDNode throws on unsupported type', () {
        expect(
          () => EnhancedCBORHandler.convertCborValueToIPLDNode(CborUndefined()),
          throwsA(isA<IPLDDecodingError>()),
        );
      });
    });

    group('Tag 42 (DAG-PB) Decoding', () {
      test('decodes DAG-PB tag correctly', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final pb = MerkleDAGNode(data: Uint8List(0), links: []);
        final pbBytes = pb.toBytes();

        final cborVal = CborBytes(pbBytes, tags: [42]);
        final ipldNode = EnhancedCBORHandler.convertCborToIPLDNode(cborVal);

        expect(ipldNode.kind, equals(Kind.MAP));
        expect(ipldNode.mapValue.entries.any((e) => e.key == 'Data'), isTrue);
      });
    });
  });
}
