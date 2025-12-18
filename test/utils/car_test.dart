import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:test/test.dart';

void main() {
  group('CAR Reader/Writer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('car_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('CarWriter writes CAR to bytes', () async {
      // Create sample blocks
      final block1 = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final block2 = await Block.fromData(Uint8List.fromList([4, 5, 6]));
      final blocks = [block1, block2];

      // Create CAR
      final car = CAR.v2WithIndex(blocks);

      // Write to bytes
      final bytes = await CarWriter.writeCar(car);

      expect(bytes, isNotEmpty);
      expect(bytes, isA<Uint8List>());
    });

    test('CarReader reads CAR from bytes', () async {
      // Create and write CAR
      final block1 = await Block.fromData(Uint8List.fromList([10, 20, 30]));
      final car = CAR.v2WithIndex([block1]);
      final bytes = await CarWriter.writeCar(car);

      // Read it back
      final readCar = await CarReader.readCar(bytes);

      expect(readCar, isNotNull);
      expect(readCar.blocks, isNotEmpty);
      expect(readCar.version, equals(2));
    });

    test('CAR roundtrip preserves blocks', () async {
      // Create blocks with known data
      final data1 = Uint8List.fromList([100, 101, 102]);
      final data2 = Uint8List.fromList([200, 201, 202]);
      final block1 = await Block.fromData(data1);
      final block2 = await Block.fromData(data2);

      // Create CAR
      final originalCar = CAR.v2WithIndex([block1, block2]);

      // Roundtrip
      final bytes = await CarWriter.writeCar(originalCar);
      final readCar = await CarReader.readCar(bytes);

      // Verify
      expect(readCar.blocks.length, equals(2));
      expect(readCar.blocks[0].data, equals(block1.data));
      expect(readCar.blocks[1].data, equals(block2.data));
    });

    test('CarReader.extractBlocks returns all blocks', () async {
      final block1 = await Block.fromData(Uint8List.fromList([1]));
      final block2 = await Block.fromData(Uint8List.fromList([2]));
      final block3 = await Block.fromData(Uint8List.fromList([3]));

      final car = CAR.v2WithIndex([block1, block2, block3]);
      final bytes = await CarWriter.writeCar(car);

      final blocks = await CarReader.extractBlocks(bytes);

      expect(blocks.length, equals(3));
      expect(blocks[0].data, equals(Uint8List.fromList([1])));
      expect(blocks[1].data, equals(Uint8List.fromList([2])));
      expect(blocks[2].data, equals(Uint8List.fromList([3])));
    });

    test('CarWriter.writeCarToFile creates file', () async {
      final block = await Block.fromData(Uint8List.fromList([42]));
      final car = CAR.v2WithIndex([block]);

      final filePath = '${tempDir.path}/test.car';
      await CarWriter.writeCarToFile(car, filePath);

      expect(File(filePath).existsSync(), isTrue);

      // Verify file content
      final fileBytes = await File(filePath).readAsBytes();
      expect(fileBytes, isNotEmpty);
    });

    test('CAR file roundtrip via filesystem', () async {
      final data = Uint8List.fromList([255, 254, 253]);
      final block = await Block.fromData(data);
      final originalCar = CAR.v2WithIndex([block]);

      // Write to file
      final filePath = '${tempDir.path}/roundtrip.car';
      await CarWriter.writeCarToFile(originalCar, filePath);

      // Read from file
      final fileBytes = await File(filePath).readAsBytes();
      final readCar = await CarReader.readCar(fileBytes);

      // Verify
      expect(readCar.blocks.length, equals(1));
      expect(readCar.blocks[0].data, equals(data));
    });

    test('CAR with empty blocks list', () async {
      final car = CAR.v2WithIndex([]);

      final bytes = await CarWriter.writeCar(car);
      final readCar = await CarReader.readCar(bytes);

      expect(readCar.blocks, isEmpty);
      expect(readCar.version, equals(2));
    });

    test('CAR header includes characteristics', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final car = CAR.v2WithIndex([block]);

      expect(car.header.characteristics, contains('index-sorted'));
      expect(car.header.characteristics, contains('content-addressed'));
    });

    test('CAR index provides block offsets', () async {
      final block1 = await Block.fromData(Uint8List.fromList([1, 2]));
      final block2 = await Block.fromData(Uint8List.fromList([3, 4, 5]));
      final car = CAR.v2WithIndex([block1, block2]);

      expect(car.index, isNotNull);

      final cid1 = block1.cid.toString();
      final offset1 = car.getBlockOffset(cid1);

      expect(offset1, isNotNull);
      expect(offset1, greaterThanOrEqualTo(0));
    });

    test('CAR index tracks block lengths', () async {
      final smallData = Uint8List.fromList([1]);
      final largeData = Uint8List.fromList(List.filled(100, 42));

      final block1 = await Block.fromData(smallData);
      final block2 = await Block.fromData(largeData);

      final car = CAR.v2WithIndex([block1, block2]);

      final cid1 = block1.cid.toString();
      final cid2 = block2.cid.toString();

      final length1 = car.index?.getLength(cid1);
      final length2 = car.index?.getLength(cid2);

      expect(length1, isNotNull);
      expect(length2, isNotNull);
      expect(length2! > length1!, isTrue);
    });

    test('CAR roundtrip with multiple blocks preserves CIDs', () async {
      final block1 = await Block.fromData(Uint8List.fromList([10]));
      final block2 = await Block.fromData(Uint8List.fromList([20]));
      final block3 = await Block.fromData(Uint8List.fromList([30]));

      final originalCar = CAR.v2WithIndex([block1, block2, block3]);
      final bytes = await CarWriter.writeCar(originalCar);
      final readCar = await CarReader.readCar(bytes);

      expect(readCar.blocks[0].cid.toString(), equals(block1.cid.toString()));
      expect(readCar.blocks[1].cid.toString(), equals(block2.cid.toString()));
      expect(readCar.blocks[2].cid.toString(), equals(block3.cid.toString()));
    });

    test('CAR version is preserved in roundtrip', () async {
      final block = await Block.fromData(Uint8List.fromList([99]));
      final car = CAR.v2WithIndex([block]);

      expect(car.version, equals(2));

      final bytes = await CarWriter.writeCar(car);
      final readCar = await CarReader.readCar(bytes);

      expect(readCar.version, equals(2));
    });

    test('CarIndex.generate creates valid index', () async {
      final blocks = [
        await Block.fromData(Uint8List.fromList([1])),
        await Block.fromData(Uint8List.fromList([2, 3])),
        await Block.fromData(Uint8List.fromList([4, 5, 6])),
      ];

      final index = CarIndex.generate(blocks);

      // Each block should have an entry
      for (var block in blocks) {
        final cid = block.cid.toString();
        expect(index.getOffset(cid), isNotNull);
        expect(index.getLength(cid), isNotNull);
      }
    });

    test('CarIndex offsets are sequential', () async {
      final blocks = [
        await Block.fromData(Uint8List.fromList([1])),
        await Block.fromData(Uint8List.fromList([2])),
      ];

      final index = CarIndex.generate(blocks);

      final offset1 = index.getOffset(blocks[0].cid.toString())!;
      final length1 = index.getLength(blocks[0].cid.toString())!;
      final offset2 = index.getOffset(blocks[1].cid.toString())!;

      // Second block offset should be after first block
      expect(offset2, equals(offset1 + length1));
    });
  });
}
