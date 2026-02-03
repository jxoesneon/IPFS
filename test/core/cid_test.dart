import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:test/test.dart';

void main() {
  group('CID', () {
    test('v0 creates valid CIDv0', () {
      final hash = Uint8List(32); // SHA-256 length
      final cid = CID.v0(hash);

      expect(cid.version, 0);
      expect(cid.codec, 'dag-pb');
      expect(cid.multihash.digest, equals(hash));
    });

    test('v1 creates valid CIDv1 with different codecs', () {
      final hash = Multihash.encode('sha2-256', Uint8List(32));

      final cidRaw = CID.v1('raw', hash);
      expect(cidRaw.version, 1);
      expect(cidRaw.codec, 'raw');

      final cidDagPb = CID.v1('dag-pb', hash);
      expect(cidDagPb.version, 1);
      expect(cidDagPb.codec, 'dag-pb');

      final cidDagCbor = CID.v1('dag-cbor', hash);
      expect(cidDagCbor.version, 1);
      expect(cidDagCbor.codec, 'dag-cbor');
    });

    test('toBytes and fromBytes round trip', () {
      final hash = Multihash.encode('sha2-256', Uint8List(32));

      // Test with 'raw'
      final cid1 = CID.v1('raw', hash);
      final bytes1 = cid1.toBytes();
      final decoded1 = CID.fromBytes(bytes1);
      expect(decoded1, equals(cid1));
      expect(decoded1.codec, 'raw');

      // Test with 'dag-cbor'
      final cid2 = CID.v1('dag-cbor', hash);
      final bytes2 = cid2.toBytes();
      final decoded2 = CID.fromBytes(bytes2);
      expect(decoded2, equals(cid2));
      expect(decoded2.codec, 'dag-cbor');
    });

    test('toBytes throws on unsupported codec', () {
      // Current implementation of toBytes throws FormatException if codec unknown
      final hash = Multihash.encode('sha2-256', Uint8List(32));
      final cid = CID.v1('unsupported-codec-xyz', hash);

      expect(() => cid.toBytes(), throwsFormatException);
    });

    test('validate returns true for valid CIDs', () {
      final hash = Multihash.encode('sha2-256', Uint8List(32));
      final cid = CID.v1('raw', hash);
      expect(cid.validate(), isTrue);
    });
  });
}

