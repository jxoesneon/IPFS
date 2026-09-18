// test/utils/car_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' as core;
import 'package:test/test.dart';

core.CID coreCid(CID cid) => core.CID.fromBytes(cid.toBytes());

void main() {
  group('CAR Format', () {
    test('CarWriter creates a valid CAR v1 archive', () async {
      final root = await Block.fromData(
        Uint8List.fromList(utf8.encode('root')),
      );
      final child = await Block.fromData(
        Uint8List.fromList(utf8.encode('child')),
      );

      final writer = CarWriter(roots: [coreCid(root.cid)]);
      await writer.write(coreCid(root.cid), root.data);
      await writer.write(coreCid(child.cid), child.data);
      final bytes = await writer.close();

      expect(bytes.isNotEmpty, isTrue);
      // CAR v1 starts with a varint length, not the CAR v2 pragma.
      expect(bytes[0], isNot(0x0a));

      final reader = CarReader.fromBytes(bytes);
      final header = await reader.header;
      expect(header.version, equals(1));
      expect(header.roots, equals([coreCid(root.cid)]));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(2));
      expect(
        sections.map((s) => s.cid).toSet(),
        equals({coreCid(root.cid), coreCid(child.cid)}),
      );
    });

    test('CarWriter creates a valid CAR v2 archive with index', () async {
      final root = await Block.fromData(
        Uint8List.fromList(utf8.encode('root')),
      );
      final child = await Block.fromData(
        Uint8List.fromList(utf8.encode('child')),
      );

      final writer = CarWriter(
        roots: [coreCid(root.cid)],
        v2: true,
        index: true,
      );
      await writer.write(coreCid(root.cid), root.data);
      await writer.write(coreCid(child.cid), child.data);
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
      expect(header.roots, equals([coreCid(root.cid)]));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(2));

      final rootOffset = await reader.findCID(coreCid(root.cid));
      expect(rootOffset, isNotNull);
      final childOffset = await reader.findCID(coreCid(child.cid));
      expect(childOffset, isNotNull);
      expect(childOffset, isNot(equals(rootOffset)));
    });

    test('CarReader reads from a stream', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('streamed')),
      );
      final writer = CarWriter(roots: [coreCid(block.cid)]);
      await writer.write(coreCid(block.cid), block.data);
      final bytes = await writer.close();

      final reader = CarReader.fromStream(
        Stream.fromIterable([
          bytes.sublist(0, bytes.length ~/ 2),
          bytes.sublist(bytes.length ~/ 2),
        ]),
      );
      final header = await reader.header;
      expect(header.roots, equals([coreCid(block.cid)]));
      final sections = await reader.sections().toList();
      expect(sections.length, equals(1));
      expect(sections.first.cid, equals(coreCid(block.cid)));
      expect(sections.first.bytes, equals(block.data));
    });

    test('CarHeader value equality and fields', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('header')),
      );
      final header1 = CarHeader(version: 1, roots: [coreCid(block.cid)]);
      final header2 = CarHeader(version: 1, roots: [coreCid(block.cid)]);
      final header3 = CarHeader(version: 2, roots: [coreCid(block.cid)]);

      expect(header1, equals(header2));
      expect(header1.hashCode, equals(header2.hashCode));
      expect(header1, isNot(equals(header3)));
      expect(header1.version, equals(1));
      expect(header1.roots, equals([coreCid(block.cid)]));
    });

    test('CarSection reports serialized size', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('block')),
      );
      final section = CarSection(cid: coreCid(block.cid), bytes: block.data);
      final cidBytes = coreCid(block.cid).toBytes();
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
      builder.add(coreCid(a.cid), 0);
      builder.add(coreCid(b.cid), 100);
      final index = builder.build();

      expect(
        index.sublist(0, 4),
        equals(Uint8List.fromList([0x00, 0x04, 0x00, 0x00])),
      );
    });

    test('IndexBuilder emits sorted MultihashIndexSorted index', () async {
      final a = await Block.fromData(Uint8List.fromList(utf8.encode('a')));
      final builder = IndexBuilder(multihashSorted: true);
      builder.add(coreCid(a.cid), 0);
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
      final writer = CarWriter(roots: [coreCid(block.cid)]);
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
