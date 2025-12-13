// test/core/data_structures/block_verified_test.dart
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Verified Block class tests based on actual API investigation.
void main() {
  group('Block - Verified API Tests', () {
    group('Block Creation', () {
      test('creates block from CID and data', () {
        final data = utf8.encode('test data');
        final cid = CID.computeForDataSync(data);

        final block = Block(cid: cid, data: data);

        expect(block, isNotNull);
        expect(block.cid, equals(cid));
        expect(block.data, equals(data));
      });

      test('fromData creates block with computed CID', () async {
        final data = Uint8List.fromList([1, 2, 3, 4]);

        final block = await Block.fromData(data);

        expect(block, isNotNull);
        expect(block.data, equals(data));
        expect(block.cid, isNotNull);
      });

      test('fromData with different data creates different blocks', () async {
        final data1 = utf8.encode('data1');
        final data2 = utf8.encode('data2');

        final block1 = await Block.fromData(data1);
        final block2 = await Block.fromData(data2);

        expect(block1.cid, isNot(equals(block2.cid)));
        expect(block1.data, isNot(equals(block2.data)));
      });

      test('same data in fromData produces same CID', () async {
        final data = utf8.encode('identical');

        final block1 = await Block.fromData(data);
        final block2 = await Block.fromData(data);

        expect(block1.cid.toString(), equals(block2.cid.toString()));
      });
    });

    group('Block Properties', () {
      test('cid property is accessible', () async {
        final block = await Block.fromData(utf8.encode('test'));

        expect(block.cid, isA<CID>());
        expect(block.cid.toString(), isNotEmpty);
      });

      test('data property is accessible', () async {
        final originalData = utf8.encode('accessible data');
        final block = await Block.fromData(originalData);

        expect(block.data, equals(originalData));
      });

      test('data is stored as Uint8List', () async {
        final block = await Block.fromData(utf8.encode('test'));

        expect(block.data, isA<Uint8List>());
      });
    });

    group('Block Equality', () {
      test('blocks with same CID have matching CID strings', () {
        final data = utf8.encode('same');
        final cid = CID.computeForDataSync(data);

        final block1 = Block(cid: cid, data: data);
        final block2 = Block(cid: cid, data: data);

        expect(block1.cid.toString(), equals(block2.cid.toString()));
      });

      test('blocks with different CIDs have different CID strings', () async {
        final block1 = await Block.fromData(utf8.encode('A'));
        final block2 = await Block.fromData(utf8.encode('B'));

        expect(block1.cid.toString(), isNot(equals(block2.cid.toString())));
      });
    });

    group('Edge Cases', () {
      test('handles empty data', () async {
        final empty = Uint8List(0);

        final block = await Block.fromData(empty);

        expect(block, isNotNull);
        expect(block.data, isEmpty);
      });

      test('handles large data', () async {
        final large = Uint8List(1024 * 50); // 50KB
        for (var i = 0; i < large.length; i++) {
          large[i] = i % 256;
        }

        final block = await Block.fromData(large);

        expect(block, isNotNull);
        expect(block.data.length, equals(large.length));
      });

      test('handles binary data', () async {
        final binary = Uint8List.fromList([0, 1, 255, 128, 64, 32]);

        final block = await Block.fromData(binary);

        expect(block, isNotNull);
        expect(block.data, equals(binary));
      });

      test('handles UTF-8 data', () async {
        final utf8Data = utf8.encode('Hello 世界 🌍');

        final block = await Block.fromData(utf8Data);

        expect(block, isNotNull);
        final decoded = utf8.decode(block.data);
        expect(decoded, equals('Hello 世界 🌍'));
      });
    });

    group('Data Integrity', () {
      test('data stored matches data retrieved', () async {
        final testCases = [
          utf8.encode('simple text'),
          utf8.encode('{"json": "data"}'),
          Uint8List.fromList([0, 1, 2, 255]),
          utf8.encode('special\n\t\r chars'),
        ];

        for (final data in testCases) {
          final block = await Block.fromData(data);
          expect(block.data, equals(data));
        }
      });

      test('CID is derived from data content', () async {
        final data = utf8.encode('content');
        final expectedCID = await CID.fromContent(data);

        final block = await Block.fromData(data);

        expect(block.cid.toString(), equals(expectedCID.toString()));
      });

      test('block data is preserved as Uint8List', () async {
        final originalData = Uint8List.fromList([1, 2, 3]);
        final block = await Block.fromData(originalData);

        // Data should be accessible
        expect(block.data, isA<Uint8List>());
        expect(block.data.length, equals(3));
      });
    });

    group('Constructor Variations', () {
      test('direct constructor with CID and data', () {
        final data = utf8.encode('direct');
        final cid = CID.computeForDataSync(data);

        final block = Block(cid: cid, data: data);

        expect(block.cid, equals(cid));
        expect(block.data, equals(data));
      });

      test('fromData computes CID automatically', () async {
        final data = utf8.encode('auto CID');

        final block = await Block.fromData(data);
        final expectedCID = CID.computeForDataSync(data);

        expect(block.cid.toString(), equals(expectedCID.toString()));
      });
    });

    group('Concurrent Operations', () {
      test('concurrent block creation', () async {
        final futures = List.generate(
          10,
          (i) => Block.fromData(utf8.encode('concurrent $i')),
        );

        final blocks = await Future.wait(futures);

        expect(blocks.length, equals(10));
        expect(blocks.every((b) => b != null), isTrue);
      });

      test('concurrent blocks have unique CIDs', () async {
        final futures = List.generate(
          5,
          (i) => Block.fromData(utf8.encode('unique $i')),
        );

        final blocks = await Future.wait(futures);
        final cids = blocks.map((b) => b.cid.toString()).toSet();

        expect(cids.length, equals(5)); // All unique
      });
    });
  });
}
