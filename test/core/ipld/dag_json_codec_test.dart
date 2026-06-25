// test/core/ipld/dag_json_codec_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:test/test.dart';

void main() {
  group('DagJsonCodec (unified IPLDCodec)', () {
    final codec = DagJsonCodec();

    test('reports the correct multicodec name and code', () {
      expect(codec.name, equals('dag-json'));
      expect(codec.code, equals(0x0129));
      expect(codec.identifier, equals('dag-json'));
    });

    test('encodes and decodes a simple map', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'hello'
          ..value = (IPLDNode()
            ..kind = Kind.STRING
            ..stringValue = 'world'),
      );

      final encoded = await codec.encode(node);
      final jsonStr = utf8.decode(encoded);
      expect(jsonStr, contains('hello'));
      expect(jsonStr, contains('world'));

      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
      expect(decoded.mapValue.entries.first.value.stringValue, equals('world'));
    });

    test('encodes and decodes a CID link', () async {
      final cid = CID.v0(Uint8List.fromList(List.filled(32, 1)));
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'link'
          ..value = (IPLDNode()
            ..kind = Kind.LINK
            ..linkValue = (IPLDLink()
              ..version = cid.version
              ..codec = cid.codec ?? 'dag-pb'
              ..multihash = cid.multihash.toBytes())),
      );

      final encoded = await codec.encode(node);
      final jsonStr = utf8.decode(encoded);
      expect(jsonStr, contains('{"/":"'));

      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
      expect(decoded.mapValue.entries.first.value.kind, equals(Kind.LINK));
    });

    test('encodes and decodes bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap();
      node.mapValue.entries.add(
        MapEntry()
          ..key = 'data'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = bytes),
      );

      final encoded = await codec.encode(node);
      final jsonStr = utf8.decode(encoded);
      expect(jsonStr, contains('"bytes"'));

      final decoded = await codec.decode(encoded);
      expect(decoded.kind, equals(Kind.MAP));
      expect(decoded.mapValue.entries.first.value.bytesValue, equals(bytes));
    });
  });
}
