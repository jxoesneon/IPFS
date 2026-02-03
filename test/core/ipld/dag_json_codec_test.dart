// test/core/ipld/dag_json_codec_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/dag_json_codec.dart';
import 'package:test/test.dart';

void main() {
  group('DagJsonCodec', () {
    final codec = DagJsonCodec();

    test('encodes simple map', () {
      final data = {'hello': 'world', 'count': 123};
      final encoded = codec.encode(data);
      final decodedJson = jsonDecode(utf8.decode(encoded));

      expect(decodedJson, equals(data));
      expect(codec.decode(encoded), equals(data));
    });

    test('encodes and decodes CID', () {
      // Use a dummy CID
      final cid = CID.v0(Uint8List.fromList(List.filled(32, 1)));
      final data = {'link': cid};

      final encoded = codec.encode(data);
      final jsonStr = utf8.decode(encoded);

      // Verify raw JSON structure
      expect(jsonStr, contains('{"/":"${cid.encode()}"}'));

      // Verify decode restores CID
      final decoded = codec.decode(encoded);
      expect(decoded['link'], isA<CID>());
      expect((decoded['link'] as CID).encode(), equals(cid.encode()));
    });

    test('encodes and decodes Bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final data = {'data': bytes};

      final encoded = codec.encode(data);
      final jsonStr = utf8.decode(encoded);

      // Verify raw JSON structure {"/": {"bytes": "AQIDBA=="}}
      expect(jsonStr, contains('"bytes":"AQIDBA=="'));

      // Verify decode restores bytes
      final decoded = codec.decode(encoded);
      expect(decoded['data'], isA<List<int>>());
      expect(decoded['data'], equals(bytes));
    });

    test('handles nested structures', () {
      final cid = CID.v0(Uint8List.fromList(List.filled(32, 2)));
      final data = {
        'list': [
          {'nested_cid': cid},
          123,
        ],
        'map': {
          'deep': {'more': 'text'},
        },
      };

      final encoded = codec.encode(data);
      final decoded = codec.decode(encoded);

      final nestedCid = (decoded['list'][0] as Map)['nested_cid'];
      expect(nestedCid, isA<CID>());
      expect(nestedCid.encode(), equals(cid.encode()));
    });
  });
}

