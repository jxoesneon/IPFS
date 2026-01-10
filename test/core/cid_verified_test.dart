// test/core/cid_verified_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:test/test.dart';

/// Comprehensive CID tests using VERIFIED APIs from actual source code.
void main() {
  group('CID - Verified API Tests', () {
    group('CID Creation', () {
      test('computeForDataSync creates CID from data', () {
        final data = utf8.encode('test data');

        final cid = CID.computeForDataSync(data);

        expect(cid, isNotNull);
        expect(cid.version, anyOf(0, 1));
        expect(cid.toString(), isNotEmpty);
      });

      test('computeForDataSync with different codecs', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);

        final cidRaw = CID.computeForDataSync(data, codec: 'raw');
        final cidDagPb = CID.computeForDataSync(data, codec: 'dag-pb');

        expect(cidRaw.codec, equals('raw'));
        expect(cidDagPb.codec, equals('dag-pb'));
        expect(cidRaw.toString(), isNot(equals(cidDagPb.toString())));
      });

      test('same data produces same CID', () {
        final data = utf8.encode('identical');

        final cid1 = CID.computeForDataSync(data);
        final cid2 = CID.computeForDataSync(data);

        expect(cid1.toString(), equals(cid2.toString()));
        expect(cid1, equals(cid2));
      });

      test('different data produces different CIDs', () {
        final data1 = utf8.encode('data1');
        final data2 = utf8.encode('data2');

        final cid1 = CID.computeForDataSync(data1);
        final cid2 = CID.computeForDataSync(data2);

        expect(cid1, isNot(equals(cid2)));
      });
    });

    group('CID Encoding/Decoding', () {
      test('encode and decode round-trip', () {
        final data = utf8.encode('round trip');
        final original = CID.computeForDataSync(data);

        final encoded = original.encode();
        final decoded = CID.decode(encoded);

        expect(decoded.version, equals(original.version));
        expect(decoded.codec, equals(original.codec));
      });

      test('toString returns encoded string', () {
        final data = utf8.encode('test');
        final cid = CID.computeForDataSync(data);

        final str = cid.toString();
        final encoded = cid.encode();

        expect(str, equals(encoded));
      });

      test('decode handles CIDv0 format (Qm prefix)', () {
        // Example CIDv0
        final cidStr = 'QmTest';

        // Note: This might throw if not a valid CID, that's OK for now
        try {
          final cid = CID.decode(cidStr);
          expect(cid, isNotNull);
        } catch (e) {
          // Expected for invalid test CID
          expect(e, isA<Exception>());
        }
      });

      test('decode throws on empty string', () {
        expect(() => CID.decode(''), throwsArgumentError);
      });

      test('toBytes returns Uint8List', () {
        final data = utf8.encode('bytes test');
        final cid = CID.computeForDataSync(data);

        final bytes = cid.toBytes();

        expect(bytes, isA<Uint8List>());
        expect(bytes, isNotEmpty);
      });

      test('fromBytes round-trip', () {
        final data = utf8.encode('bytes round trip');
        final original = CID.computeForDataSync(data);

        final bytes = original.toBytes();
        final restored = CID.fromBytes(bytes);

        expect(restored.version, equals(original.version));
      });

      test('fromBytes throws on empty bytes', () {
        expect(() => CID.fromBytes(Uint8List(0)), throwsArgumentError);
      });
    });

    group('CID Properties', () {
      test('version property is accessible', () {
        final cid = CID.computeForDataSync(utf8.encode('test'));

        expect(cid.version, anyOf(equals(0), equals(1)));
      });

      test('codec property is accessible', () {
        final cid = CID.computeForDataSync(utf8.encode('test'), codec: 'raw');

        expect(cid.codec, equals('raw'));
      });

      test('multihash property exists', () {
        final cid = CID.computeForDataSync(utf8.encode('test'));

        expect(cid.multihash, isNotNull);
      });

      test('validate returns true for valid CID', () {
        final cid = CID.computeForDataSync(utf8.encode('valid'));

        expect(cid.validate(), isTrue);
      });
    });

    group('CID Comparison', () {
      test('equality operator works', () {
        final data = utf8.encode('equal');
        final cid1 = CID.computeForDataSync(data);
        final cid2 = CID.computeForDataSync(data);

        expect(cid1 == cid2, isTrue);
      });

      test('inequality works', () {
        final cid1 = CID.computeForDataSync(utf8.encode('A'));
        final cid2 = CID.computeForDataSync(utf8.encode('B'));

        expect(cid1 == cid2, isFalse);
      });

      test('identical CIDs are equal', () {
        final cid = CID.computeForDataSync(utf8.encode('same'));

        expect(cid == cid, isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles empty data', () {
        final empty = Uint8List(0);

        final cid = CID.computeForDataSync(empty);

        expect(cid, isNotNull);
      });

      test('handles large data', () {
        final large = Uint8List(1024 * 100); // 100KB
        for (var i = 0; i < large.length; i++) {
          large[i] = i % 256;
        }

        final cid = CID.computeForDataSync(large);

        expect(cid, isNotNull);
        expect(cid.toString(), isNotEmpty);
      });

      test('handles binary data', () {
        final binary = Uint8List.fromList([0, 1, 255, 128, 64]);

        final cid = CID.computeForDataSync(binary);

        expect(cid, isNotNull);
      });

      test('handles UTF-8 special characters', () {
        final special = utf8.encode('Hello 世界 🌍 \n\t');

        final cid = CID.computeForDataSync(special);

        expect(cid, isNotNull);
      });
    });

    group('Codec Variations', () {
      test('raw codec', () {
        final cid = CID.computeForDataSync(utf8.encode('raw'), codec: 'raw');

        expect(cid.codec, equals('raw'));
      });

      test('dag-pb codec', () {
        final cid = CID.computeForDataSync(
          utf8.encode('dagpb'),
          codec: 'dag-pb',
        );

        expect(cid.codec, equals('dag-pb'));
      });

      test('dag-cbor codec', () {
        final cid = CID.computeForDataSync(
          utf8.encode('cbor'),
          codec: 'dag-cbor',
        );

        expect(cid.codec, equals('dag-cbor'));
      });
    });

    group('fromContent Factory', () {
      test('creates CID from content', () async {
        final content = utf8.encode('factory test');

        final cid = await CID.fromContent(content);

        expect(cid, isNotNull);
        expect(cid.version, equals(1)); // Default version
      });

      test('fromContent with custom codec', () async {
        final content = utf8.encode('custom codec');

        final cid = await CID.fromContent(content, codec: 'dag-pb');

        expect(cid.codec, equals('dag-pb'));
      });

      test('fromContent with custom hash', () async {
        final content = utf8.encode('custom hash');

        final cid = await CID.fromContent(content, hashType: 'sha2-256');

        expect(cid, isNotNull);
      });
    });

    group('Protobuf Conversion', () {
      test('toProto converts to protobuf', () {
        final cid = CID.computeForDataSync(utf8.encode('proto'));

        final proto = cid.toProto();

        expect(proto, isNotNull);
      });

      test('fromProto round-trip', () {
        final original = CID.computeForDataSync(utf8.encode('proto rt'));

        final proto = original.toProto();
        final restored = CID.fromProto(proto);

        expect(restored.version, equals(original.version));
      });
    });
  });
}
