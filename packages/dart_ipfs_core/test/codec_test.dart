import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('RawCodec', () {
    test('encodes and decodes Uint8List', () async {
      final codec = RawCodec();
      final data = Uint8List.fromList([1, 2, 3]);
      final encoded = await codec.encode(data);
      expect(encoded, equals(data));
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(data));
    });

    test('rejects non-Uint8List input', () async {
      final codec = RawCodec();
      expect(() => codec.encode('hello'), throwsArgumentError);
    });
  });

  group('DagJsonCodec', () {
    test('encodes and decodes map', () async {
      final codec = DagJsonCodec();
      final value = <String, dynamic>{'name': 'test', 'value': 42};
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('encodes and decodes bytes', () async {
      final codec = DagJsonCodec();
      final data = Uint8List.fromList([1, 2, 3]);
      final encoded = await codec.encode(data);
      final decoded = await codec.decode(encoded);
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['/'], isA<Map<String, dynamic>>());
      expect(decoded['/']['bytes'], equals(base64Encode(data)));
    });

    test('round-trips a CID link', () async {
      final codec = DagJsonCodec();
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final value = {
        'link': {'/': cid.encode()},
      };
      final encoded = await codec.encode(value);
      expect(utf8.decode(encoded), contains('"${cid.encode()}"'));
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('rejects invalid CID strings in link form', () async {
      final codec = DagJsonCodec();
      expect(() => codec.encode({'/': 'not-a-cid'}), throwsArgumentError);
      expect(() => codec.encode({'/': ''}), throwsArgumentError);
      expect(
        () => codec.decode(Uint8List.fromList(utf8.encode('{"/":"nope"}'))),
        throwsFormatException,
      );
    });

    test('map with / key plus siblings is a regular map, not a link', () async {
      final codec = DagJsonCodec();
      final value = {'/': 'x', 'other': 1};
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      // Sibling keys must survive: '/' is not the sole key.
      expect(decoded, equals(value));
    });

    test('rejects non-string map keys', () async {
      final codec = DagJsonCodec();
      expect(
        () => codec.encode(<dynamic, dynamic>{1: 'x'}),
        throwsArgumentError,
      );
    });
  });

  group('DagCborCodec', () {
    test('encodes and decodes map', () async {
      final codec = DagCborCodec();
      final value = <String, dynamic>{'name': 'test', 'value': 42};
      final encoded = await codec.encode(value);
      expect(encoded, isNotEmpty);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('encodes and decodes list', () async {
      final codec = DagCborCodec();
      final value = [1, 2, 3];
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('encodes and decodes CID link', () async {
      final codec = DagCborCodec();
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final value = {
        'link': {'/': cid.encode()},
      };
      final encoded = await codec.encode(value);
      final decoded = await codec.decode(encoded);
      expect(decoded, equals(value));
    });

    test('declares correct name and code', () {
      final codec = DagCborCodec();
      expect(codec.name, equals('dag-cbor'));
      expect(codec.code, equals(0x71));
    });
  });
}
