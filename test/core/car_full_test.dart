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

    test('CAR constructor and basic properties', () {
      final header = CarHeader(version: 1);
      final car = CAR(blocks: testBlocks, header: header, version: 1);
      expect(car.version, equals(1));
      expect(car.blocks, equals(testBlocks));
      expect(car.index, isNull);
    });

    test('CAR.v2WithIndex with empty blocks', () {
      final car = CAR.v2WithIndex([]);
      expect(car.version, equals(2));
      expect(car.blocks, isEmpty);
      expect(car.header.roots, isEmpty);
    });

    test('loadSelected full verification', () async {
      final car = CAR.v2WithIndex(testBlocks);

      // Select first block
      final selected1 = await car.loadSelected([
        testBlocks.first.cid.toString(),
      ]);
      expect(selected1.blocks.length, equals(1));
      expect(selected1.blocks.first.cid, equals(testBlocks.first.cid));

      // Select non-existent CID
      final selectedNone = await car.loadSelected(['non-existent']);
      expect(selectedNone.blocks, isEmpty);

      // Without index throws
      final carNoIndex = CAR(blocks: testBlocks, header: CarHeader(version: 1));
      expect(() => carNoIndex.loadSelected([]), throwsUnsupportedError);
    });

    test('CarHeader toProto verification', () {
      final header = CarHeader(
        version: 1,
        roots: [testBlocks.first.cid],
        characteristics: ['test-char'],
        pragma: {'foo': 'bar'},
      );
      final proto = header.toProto();
      expect(proto.version, equals(1));
      expect(proto.characteristics, contains('test-char'));
      expect(proto.roots.length, equals(1));
      expect(proto.pragma.containsKey('foo'), isTrue);
    });

    test('CarIndex manual entries and methods', () {
      final index = CarIndex();
      index.addEntry('cid1', 10, 20);
      index.addEntry('cid2', 30, 40);

      expect(index.getOffset('cid1'), equals(10));
      expect(index.getLength('cid1'), equals(20));
      expect(index.getOffset('undefined'), isNull);

      final proto = index.toProto();
      expect(proto.entries.length, equals(2));
    });

    test('CAR fromBytes/toBytes roundtrip with index and pragma', () {
      final header = CarHeader(version: 2, pragma: {'meta': 'data'});
      final car = CAR(
        blocks: testBlocks,
        header: header,
        index: CarIndex.generate(testBlocks),
        version: 2,
      );

      final bytes = car.toBytes();
      final decoded = CAR.fromBytes(bytes);

      expect(decoded.version, equals(2));
      expect(decoded.blocks.length, equals(2));
      expect(decoded.header.pragma['meta'], equals('data'));
      expect(decoded.index, isNotNull);
      expect(
        decoded.getBlockOffset(testBlocks.first.cid.toString()),
        equals(0),
      );
    });

    test('CarReader/Writer edge cases', () async {
      final car = CAR.v2WithIndex(testBlocks);
      final carData = await CarWriter.writeCar(car);

      final blocks = await CarReader.extractBlocks(carData);
      expect(blocks.length, equals(2));

      final tempDir = await Directory.systemTemp.createTemp('car_io_test');
      final path = '${tempDir.path}/test.car';
      try {
        await CarWriter.writeCarToFile(car, path);
        final file = File(path);
        expect(await file.exists(), isTrue);
        final readData = await file.readAsBytes();
        expect(readData, equals(carData));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('CarIndex.generate loop coverage', () {
      final car = CAR.v2WithIndex(testBlocks);
      expect(car.index, isNotNull);
      // Ensure second block has a non-zero offset
      final offset2 = car.getBlockOffset(testBlocks.last.cid.toString());
      expect(offset2, equals(testBlocks.first.size));
    });
  });
}
