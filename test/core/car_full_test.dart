import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:test/test.dart';

void main() {
  group('CAR Utilities Deep Coverage', () {
    late List<Block> testBlocks;

    setUp(() async {
      testBlocks = [
        await Block.fromData(Uint8List.fromList([1, 2, 3]), format: 'raw'),
        await Block.fromData(Uint8List.fromList([4, 5, 6]), format: 'raw'),
      ];
    });

    test('CarWriter constructor and basic properties', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      expect(writer.roots, equals([testBlocks.first.cid]));
      expect(writer.v2, isFalse);
      expect(writer.index, isFalse);
    });

    test('CarWriter v2 with index', () async {
      final writer = CarWriter(
        roots: [testBlocks.first.cid],
        v2: true,
        index: true,
      );
      expect(writer.v2, isTrue);
      expect(writer.index, isTrue);
    });

    test('CarWriter rejects index without v2', () {
      expect(
        () => CarWriter(roots: [testBlocks.first.cid], index: true),
        throwsArgumentError,
      );
    });

    test('CarWriter rejects empty roots', () async {
      final writer = CarWriter(roots: []);
      expect(writer.close(), throwsA(isA<CarHeaderException>()));
    });

    test('CarReader/Writer roundtrip v1', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      for (final block in testBlocks) {
        await writer.write(block.cid, block.data);
      }
      final bytes = await writer.close();

      final reader = CarReader.fromBytes(bytes);
      expect((await reader.header).version, equals(1));
      expect((await reader.header).roots, equals([testBlocks.first.cid]));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(testBlocks.length));
      for (var i = 0; i < testBlocks.length; i++) {
        expect(sections[i].cid, equals(testBlocks[i].cid));
        expect(sections[i].bytes, equals(testBlocks[i].data));
      }
    });

    test('CarReader/Writer roundtrip v2 with index', () async {
      final writer = CarWriter(
        roots: [testBlocks.first.cid],
        v2: true,
        index: true,
      );
      for (final block in testBlocks) {
        await writer.write(block.cid, block.data);
      }
      final bytes = await writer.close();

      final reader = CarReader.fromBytes(bytes);
      expect((await reader.header).version, equals(1));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(testBlocks.length));

      final firstOffset = await reader.findCID(testBlocks.first.cid);
      final secondOffset = await reader.findCID(testBlocks.last.cid);
      expect(firstOffset, isNotNull);
      expect(secondOffset, isNotNull);
      expect(secondOffset, greaterThan(firstOffset!));
    });

    test('CarReader findCID falls back to linear scan for CAR v1', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      for (final block in testBlocks) {
        await writer.write(block.cid, block.data);
      }
      final bytes = await writer.close();

      final reader = CarReader.fromBytes(bytes);
      final offset = await reader.findCID(testBlocks.last.cid);
      expect(offset, isNotNull);
    });

    test('CarWriter closeStream yields equivalent bytes', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      for (final block in testBlocks) {
        await writer.write(block.cid, block.data);
      }
      final streamedBytes = await writer.closeStream().fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      );
      final bytes = await writer.close();

      expect(streamedBytes.toBytes(), equals(bytes));
    });

    test('CarWriter file roundtrip', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      for (final block in testBlocks) {
        await writer.write(block.cid, block.data);
      }
      final carData = await writer.close();

      final tempDir = await Directory.systemTemp.createTemp('car_io_test');
      final path = '${tempDir.path}/test.car';
      try {
        await File(path).writeAsBytes(carData);
        final readData = await File(path).readAsBytes();
        expect(readData, equals(carData));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('CarReader/Writer preserve cid and block bytes', () async {
      final writer = CarWriter(roots: [testBlocks.first.cid]);
      await writer.write(testBlocks.first.cid, testBlocks.first.data);
      final bytes = await writer.close();

      final reader = CarReader.fromBytes(bytes);
      final section = await reader.sections().first;
      expect(section.cid, equals(testBlocks.first.cid));
      expect(section.bytes, equals(testBlocks.first.data));
    });

    test('CarHeader toString is descriptive', () {
      final header = CarHeader(version: 1, roots: [testBlocks.first.cid]);
      expect(header.toString(), contains('version: 1'));
    });
  });
}
