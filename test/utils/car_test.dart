// test/utils/car_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:test/test.dart';

void main() {
  group('CAR Format', () {
    test('CarWriter creates a valid CAR v1 archive', () async {
      final root = await Block.fromData(
        Uint8List.fromList(utf8.encode('root')),
      );
      final child = await Block.fromData(
        Uint8List.fromList(utf8.encode('child')),
      );

      final writer = CarWriter(roots: [root.cid]);
      await writer.write(root.cid, root.data);
      await writer.write(child.cid, child.data);
      final bytes = await writer.close();

      expect(bytes.isNotEmpty, isTrue);
      // CAR v1 starts with a varint length, not the CAR v2 pragma.
      expect(bytes[0], isNot(0x0a));

      final reader = CarReader.fromBytes(bytes);
      final header = await reader.header;
      expect(header.version, equals(1));
      expect(header.roots, equals([root.cid]));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(2));
      expect(sections.map((s) => s.cid).toSet(), equals({root.cid, child.cid}));
    });

    test('CarWriter creates a valid CAR v2 archive with index', () async {
      final root = await Block.fromData(
        Uint8List.fromList(utf8.encode('root')),
      );
      final child = await Block.fromData(
        Uint8List.fromList(utf8.encode('child')),
      );

      final writer = CarWriter(roots: [root.cid], v2: true, index: true);
      await writer.write(root.cid, root.data);
      await writer.write(child.cid, child.data);
      final bytes = await writer.close();

      expect(bytes.isNotEmpty, isTrue);
      // CAR v2 pragma.
      expect(
        bytes.sublist(0, 11),
        equals(
          Uint8List.fromList([
            0x0a,
            0xa1,
            0x67,
            0x76,
            0x65,
            0x72,
            0x73,
            0x69,
            0x6f,
            0x6e,
            0x02,
          ]),
        ),
      );

      final reader = CarReader.fromBytes(bytes);
      final header = await reader.header;
      expect(header.version, equals(1));
      expect(header.roots, equals([root.cid]));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(2));

      final rootOffset = await reader.findCID(root.cid);
      expect(rootOffset, isNotNull);
      final childOffset = await reader.findCID(child.cid);
      expect(childOffset, isNotNull);
      expect(childOffset, isNot(equals(rootOffset)));
    });

    test('CarReader reads from a stream', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('streamed')),
      );
      final writer = CarWriter(roots: [block.cid]);
      await writer.write(block.cid, block.data);
      final bytes = await writer.close();

      final reader = CarReader.fromStream(
        Stream.fromIterable([
          bytes.sublist(0, bytes.length ~/ 2),
          bytes.sublist(bytes.length ~/ 2),
        ]),
      );
      final header = await reader.header;
      expect(header.roots, equals([block.cid]));
      final sections = await reader.sections().toList();
      expect(sections.length, equals(1));
      expect(sections.first.cid, equals(block.cid));
      expect(sections.first.bytes, equals(block.data));
    });

    test('CarHeader value equality and fields', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('header')),
      );
      final header1 = CarHeader(version: 1, roots: [block.cid]);
      final header2 = CarHeader(version: 1, roots: [block.cid]);
      final header3 = CarHeader(version: 2, roots: [block.cid]);

      expect(header1, equals(header2));
      expect(header1.hashCode, equals(header2.hashCode));
      expect(header1, isNot(equals(header3)));
      expect(header1.version, equals(1));
      expect(header1.roots, equals([block.cid]));
    });

    test('CarSection reports serialized size', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('block')),
      );
      final section = CarSection(cid: block.cid, bytes: block.data);
      final cidBytes = block.cid.toBytes();
      final payloadLength = cidBytes.length + block.data.length;

      var varintLength = 0;
      var v = payloadLength;
      do {
        varintLength++;
        v >>= 7;
      } while (v > 0);

      expect(section.serializedSize, equals(varintLength + payloadLength));
    });

    test('IndexBuilder emits sorted IndexSorted index', () async {
      final a = await Block.fromData(Uint8List.fromList(utf8.encode('a')));
      final b = await Block.fromData(Uint8List.fromList(utf8.encode('bb')));
      final builder = IndexBuilder();
      builder.add(a.cid, 0);
      builder.add(b.cid, 100);
      final index = builder.build();

      expect(
        index.sublist(0, 4),
        equals(Uint8List.fromList([0x00, 0x04, 0x00, 0x00])),
      );
    });

    test('IndexBuilder emits sorted MultihashIndexSorted index', () async {
      final a = await Block.fromData(Uint8List.fromList(utf8.encode('a')));
      final builder = IndexBuilder(multihashSorted: true);
      builder.add(a.cid, 0);
      final index = builder.build();

      expect(
        index.sublist(0, 4),
        equals(Uint8List.fromList([0x01, 0x04, 0x00, 0x00])),
      );
    });

    test('CarWriter rejects missing roots', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('orphan')),
      );
      final writer = CarWriter(roots: [block.cid]);
      // The root block is never written, so close() should fail validation.
      expect(writer.close(), throwsA(isA<CarHeaderException>()));
    });

    test('CarReader rejects CAR v2 with invalid pragma', () async {
      final badPragma = Uint8List.fromList([
        0x0a,
        0xa1,
        0x67,
        0x76,
        0x65,
        0x72,
        0x73,
        0x69,
        0x6f,
        0x6e,
        0x03,
      ]);
      final bytes = Uint8List.fromList(badPragma + List.filled(40, 0));
      final reader = CarReader.fromBytes(bytes);
      expect(reader.sections().toList(), throwsA(isA<CarV2Exception>()));
    });
  });
}
