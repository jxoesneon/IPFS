import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('CID', () {
    test('creates CID v0 from 32-byte SHA2-256 hash', () {
      final hash = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        hash[i] = i;
      }
      final cid = CID.v0(hash);
      expect(cid.version, equals(0));
      expect(cid.codec, equals('dag-pb'));
      expect(cid.encode(), startsWith('Qm'));
    });

    test('creates CID v1 from content', () async {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final cid = await CID.fromContent(data);
      expect(cid.version, equals(1));
      expect(cid.codec, equals('raw'));
      expect(cid.encode(), startsWith('b'));
    });

    test('round-trips CID through string encoding', () async {
      final data = Uint8List.fromList(utf8.encode('round-trip'));
      final cid = await CID.fromContent(data);
      final decoded = CID.decode(cid.encode());
      expect(decoded, equals(cid));
      expect(decoded.multihash.toBytes(), equals(cid.multihash.toBytes()));
    });

    test('round-trips CID v1 through bytes', () async {
      final data = Uint8List.fromList(utf8.encode('byte-trip'));
      final cid = await CID.fromContent(data, codec: 'dag-cbor');
      final bytes = cid.toBytes();
      final decoded = CID.fromBytes(bytes);
      expect(decoded, equals(cid));
    });

    test('returns CIDv0 bytes from toBytes', () {
      final hash = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        hash[i] = i;
      }
      final cid = CID.v0(hash);
      final bytes = cid.toBytes();
      expect(bytes.length, equals(34));
      expect(bytes[0], equals(0x12));
      expect(bytes[1], equals(0x20));
    });

    test('toPrefixBytes omits digest', () async {
      final data = Uint8List.fromList(utf8.encode('prefix-test'));
      final cid = await CID.fromContent(data);
      final prefix = cid.toPrefixBytes();
      final bytes = cid.toBytes();
      expect(prefix.length, lessThan(bytes.length));
      expect(bytes.sublist(0, prefix.length), equals(prefix));
    });

    test('CID v1 encodes with different bases', () async {
      final data = Uint8List.fromList(utf8.encode('base-test'));
      final cid = await CID.fromContent(data);
      final base32 = cid.encodeWithBaseName('base32');
      final base64 = cid.encodeWithBaseName('base64');
      expect(base32, isNot(equals(base64)));
      expect(CID.decode(base32), equals(cid));
      expect(CID.decode(base64), equals(cid));
    });

    test(' CID v0 rejects non-32-byte hash', () {
      expect(() => CID.v0(Uint8List(16)), throwsArgumentError);
    });
  });

  group('Multicodec', () {
    test('looks up codec codes', () {
      expect(Multicodec.code('raw'), equals(0x55));
      expect(Multicodec.code('dag-pb'), equals(0x70));
      expect(Multicodec.code('dag-cbor'), equals(0x71));
    });

    test('looks up codec names', () {
      expect(Multicodec.name(0x55), equals('raw'));
      expect(Multicodec.name(0x70), equals('dag-pb'));
    });

    test('rejects unsupported codec', () {
      expect(() => Multicodec.code('unsupported'), throwsArgumentError);
      expect(() => Multicodec.name(0xffff), throwsArgumentError);
    });
  });

  group('MultihashUtils', () {
    test('encodes SHA2-256 digest', () {
      final digest = Uint8List(32);
      final mh = MultihashUtils.sha256(digest);
      final bytes = mh.toBytes();
      expect(bytes.length, greaterThan(32));
      expect(bytes[0], equals(0x12));
      expect(bytes[1], equals(0x20));
    });

    test('decodes multihash', () {
      final digest = Uint8List(32);
      final mh = MultihashUtils.sha256(digest);
      final info = MultihashUtils.decode(mh.toBytes());
      expect(info.name, equals('sha2-256'));
      expect(info.size, equals(32));
    });
  });
}
