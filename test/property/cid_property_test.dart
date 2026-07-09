// Property-based tests for CID encoding/decoding.
//
// These tests verify fundamental round-trip properties of CIDs using random
// generators with a fixed seed for reproducibility.
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block, IBlock, IBlockStore;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:multibase/multibase.dart';
import 'package:test/test.dart';

import '../fuzz/_fuzz_helpers.dart';

void main() {
  final rng = makeRandom();

  group('CID property-based tests', () {
    test(
      'for any valid bytes: encode as CIDv1 -> decode -> equals original bytes',
      () async {
        for (var i = 0; i < 500; i++) {
          final data = randomBytesRange(rng, 0, 1000);
          final cid = await CID.fromContent(data, codec: 'raw');
          final decoded = CID.fromBytes(cid.toBytes());
          // The multihash digest should match the SHA-256 of the original data.
          expect(decoded.version, equals(1));
          expect(decoded.multihash.digest, equals(cid.multihash.digest));
          expect(decoded.codec, equals('raw'));
        }
      },
    );

    test('for any CID: encode -> decode -> equals original CID', () async {
      final codecs = ['raw', 'dag-pb', 'dag-cbor', 'dag-json'];
      for (var i = 0; i < 500; i++) {
        final codec = codecs[rng.nextInt(codecs.length)];
        final data = randomBytesRange(rng, 1, 500);
        final cid = await CID.fromContent(data, codec: codec);
        final encoded = cid.encode();
        final decoded = CID.decode(encoded);
        expect(decoded, equals(cid));
        expect(decoded.version, equals(cid.version));
        expect(decoded.codec, equals(cid.codec));
      }
    });

    test(
      'for any CID: base32 encode -> decode -> equals original CID',
      () async {
        for (var i = 0; i < 500; i++) {
          final data = randomBytesRange(rng, 1, 500);
          final cid = await CID.fromContent(data, codec: 'raw');
          final base32Encoded = cid.encodeWithBase(Multibase.base32);
          final decoded = CID.decode(base32Encoded);
          expect(decoded, equals(cid));
        }
      },
    );

    test(
      'for any CID: base58btc encode -> decode -> equals original CID',
      () async {
        for (var i = 0; i < 500; i++) {
          final data = randomBytesRange(rng, 1, 500);
          final cid = await CID.fromContent(data, codec: 'raw');
          final base58Encoded = cid.encodeWithBase(Multibase.base58btc);
          final decoded = CID.decode(base58Encoded);
          expect(decoded, equals(cid));
        }
      },
    );

    test(
      'for any CID: base16 encode -> decode -> equals original CID',
      () async {
        for (var i = 0; i < 500; i++) {
          final data = randomBytesRange(rng, 1, 500);
          final cid = await CID.fromContent(data, codec: 'raw');
          final base16Encoded = cid.encodeWithBase(Multibase.base16);
          final decoded = CID.decode(base16Encoded);
          expect(decoded, equals(cid));
        }
      },
    );

    test('for any CID: toBytes -> fromBytes -> equals original CID', () async {
      final codecs = ['raw', 'dag-pb', 'dag-cbor'];
      for (var i = 0; i < 500; i++) {
        final codec = codecs[rng.nextInt(codecs.length)];
        final data = randomBytesRange(rng, 1, 500);
        final cid = await CID.fromContent(data, codec: codec);
        final bytes = cid.toBytes();
        final decoded = CID.fromBytes(bytes);
        expect(decoded, equals(cid));
      }
    });

    test('CIDv0 round-trip: v0 -> encode -> decode -> equals original', () {
      for (var i = 0; i < 500; i++) {
        final hash = randomBytes(rng, 32);
        final cid = CID.v0(hash);
        final encoded = cid.encode();
        final decoded = CID.decode(encoded);
        expect(decoded, equals(cid));
        expect(decoded.version, equals(0));
        expect(decoded.codec, equals('dag-pb'));
      }
    });

    test('CIDv0 toBytes -> fromBytes -> equals original', () {
      for (var i = 0; i < 500; i++) {
        final hash = randomBytes(rng, 32);
        final cid = CID.v0(hash);
        final bytes = cid.toBytes();
        final decoded = CID.fromBytes(bytes);
        expect(decoded, equals(cid));
      }
    });

    test(
      'for any CID: encode is deterministic (same CID always produces same string)',
      () async {
        for (var i = 0; i < 200; i++) {
          final data = randomBytesRange(rng, 1, 200);
          final cid = await CID.fromContent(data, codec: 'raw');
          expect(cid.encode(), equals(cid.encode()));
          expect(cid.toBytes(), equals(cid.toBytes()));
        }
      },
    );

    test('for any CID: validate() returns true', () async {
      for (var i = 0; i < 200; i++) {
        final data = randomBytesRange(rng, 1, 200);
        final cid = await CID.fromContent(data, codec: 'raw');
        expect(cid.validate(), isTrue);
      }
    });

    test('different content produces different CIDs (injectivity)', () async {
      for (var i = 0; i < 200; i++) {
        final data1 = randomBytesRange(rng, 1, 200);
        final data2 = randomBytesRange(rng, 1, 200);
        final cid1 = await CID.fromContent(data1, codec: 'raw');
        final cid2 = await CID.fromContent(data2, codec: 'raw');
        if (!_bytesEqual(data1, data2)) {
          expect(cid1, isNot(equals(cid2)));
        }
      }
    });

    test('same content produces same CID (determinism)', () async {
      for (var i = 0; i < 200; i++) {
        final data = randomBytesRange(rng, 1, 200);
        final cid1 = await CID.fromContent(data, codec: 'raw');
        final cid2 = await CID.fromContent(data, codec: 'raw');
        expect(cid1, equals(cid2));
      }
    });
  });
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
