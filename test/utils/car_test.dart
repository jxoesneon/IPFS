// test/utils/car_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:test/test.dart';

void main() {
  group('CAR Format', () {
    test('CAR.v2WithIndex creates valid archive', () async {
      final block1 = await Block.fromData(
        Uint8List.fromList(utf8.encode('block1')),
      );
      final block2 = await Block.fromData(
        Uint8List.fromList(utf8.encode('block2')),
      );

      final car = CAR.v2WithIndex([block1, block2]);

      expect(car.header.roots.length, equals(1)); // First block is root
      expect(car.blocks.length, equals(2));
      expect(car.index, isNotNull);
    });

    test('CAR serialization produces bytes', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('test data')),
      );

      final car = CAR.v2WithIndex([block]);
      final bytes = car.toBytes();

      expect(bytes.isNotEmpty, isTrue);
    });

    test('CAR deserialization restores structure', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('test data')),
      );

      final car = CAR.v2WithIndex([block]);
      final bytes = car.toBytes();
      final restored = CAR.fromBytes(bytes);

      expect(restored.blocks.length, equals(car.blocks.length));
      expect(restored.version, equals(car.version));
    });

    test('CAR version is 2 by default', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('data')),
      );
      final car = CAR.v2WithIndex([block]);

      expect(car.version, equals(2));
    });
  });

  group('CarHeader', () {
    test('CarHeader stores version', () {
      final header = CarHeader(version: 1);
      expect(header.version, equals(1));
    });

    test('CarHeader stores characteristics', () {
      final header = CarHeader(
        version: 2,
        characteristics: ['index-sorted', 'content-addressed'],
      );
      expect(header.characteristics.length, equals(2));
      expect(header.characteristics, contains('index-sorted'));
    });

    test('CarHeader stores roots', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('root')),
      );
      final header = CarHeader(version: 2, roots: [block.cid]);

      expect(header.roots.length, equals(1));
      expect(header.roots.first.encode(), equals(block.cid.encode()));
    });
  });

  group('CarIndex', () {
    test('CarIndex.generate creates index from blocks', () async {
      final block1 = await Block.fromData(Uint8List.fromList(utf8.encode('a')));
      final block2 = await Block.fromData(
        Uint8List.fromList(utf8.encode('bb')),
      );

      final index = CarIndex.generate([block1, block2]);

      expect(index.getOffset(block1.cid.toString()), equals(0));
      expect(index.getLength(block1.cid.toString()), equals(block1.size));
    });

    test('CarIndex.addEntry stores offset and length', () {
      final index = CarIndex();
      index.addEntry('QmCid1', 100, 50);

      expect(index.getOffset('QmCid1'), equals(100));
      expect(index.getLength('QmCid1'), equals(50));
    });

    test('CarIndex returns null for unknown CID', () {
      final index = CarIndex();

      expect(index.getOffset('QmUnknown'), isNull);
      expect(index.getLength('QmUnknown'), isNull);
    });
  });

  group('CAR Selective Loading', () {
    test('loadSelected throws without index', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('data')),
      );
      final car = CAR(
        blocks: [block],
        header: CarHeader(version: 2, roots: [block.cid]),
        index: null, // No index
      );

      expect(
        () => car.loadSelected(['QmCid']),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('getBlockOffset uses index', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('data')),
      );
      final car = CAR.v2WithIndex([block]);

      final offset = car.getBlockOffset(block.cid.toString());
      expect(offset, equals(0)); // First block at offset 0
    });
  });
}

