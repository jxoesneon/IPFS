// test/core/car_edge_cases_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:test/test.dart';

void main() {
  group('CarHeader edge cases', () {
    test('CarWriter rejects empty roots', () async {
      final writer = CarWriter(roots: []);
      expect(writer.close(), throwsA(isA<CarHeaderException>()));
    });

    test('CarHeader equals and hashCode are stable', () {
      final root = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final a = CarHeader(version: 1, roots: [root]);
      final b = CarHeader(version: 1, roots: [root]);
      final c = CarHeader(version: 2, roots: [root]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('CarSection edge cases', () {
    test('equals distinguishes bytes', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final a = CarSection(cid: cid, bytes: Uint8List.fromList([1, 2]));
      final b = CarSection(cid: cid, bytes: Uint8List.fromList([1, 2]));
      final c = CarSection(cid: cid, bytes: Uint8List.fromList([3, 4]));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.serializedSize, greaterThan(0));
    });
  });

  group('CarReader error cases', () {
    test('empty input throws CarHeaderException', () {
      final reader = CarReader.fromBytes(Uint8List(0));
      expect(() async => reader.header, throwsA(isA<CarHeaderException>()));
    });

    test('truncated header varint throws', () {
      final reader = CarReader.fromBytes(Uint8List.fromList([0x80]));
      expect(() async => reader.header, throwsA(isA<CarSectionException>()));
    });

    test('varint too long throws', () {
      final reader = CarReader.fromBytes(
        Uint8List.fromList(List.filled(11, 0x80)),
      );
      expect(() async => reader.header, throwsA(isA<CarSectionException>()));
    });

    test('truncated section throws CarSectionException', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'raw',
      );
      final writer = CarWriter(roots: [block.cid]);
      await writer.write(block.cid, block.data);
      final bytes = await writer.close();
      // Remove the last byte so the final section is truncated.
      final truncated = bytes.sublist(0, bytes.length - 1);
      final reader = CarReader.fromBytes(truncated);
      expect(
        () async => reader.sections().toList(),
        throwsA(isA<CarSectionException>()),
      );
    });

    test('section length smaller than CID throws', () async {
      final root = await Block.fromData(Uint8List.fromList([1]), format: 'raw');
      final writer = CarWriter(roots: [root.cid]);
      await writer.write(root.cid, root.data);
      final bytes = await writer.close();
      final headerBytes = bytes.sublist(0, _headerEndOffset(bytes));
      final bad = Uint8List.fromList([
        ...headerBytes,
        ..._encodeVarint(1),
        0x00,
      ]);
      final reader = CarReader.fromBytes(bad);
      expect(
        () async => reader.sections().toList(),
        throwsA(isA<CarSectionException>()),
      );
    });

    test('CAR v2 invalid pragma throws', () {
      final invalidPragma = Uint8List.fromList([
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
      final reader = CarReader.fromBytes(invalidPragma);
      expect(() async => reader.header, throwsA(isA<CarV2Exception>()));
    });

    test('CAR v2 header too short throws', () {
      final reader = CarReader.fromBytes(
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
      );
      expect(() async => reader.header, throwsA(isA<CarV2Exception>()));
    });

    test('CAR v2 characteristics must be zero', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final writer = CarWriter(roots: [block.cid], v2: true);
      await writer.write(block.cid, block.data);
      final bytes = await writer.close();
      // Set a non-zero characteristic byte inside the v2 header.
      bytes[11 + 5] = 0x01;
      final reader = CarReader.fromBytes(bytes);
      expect(() async => reader.header, throwsA(isA<CarV2Exception>()));
    });

    test('CAR v2 index unknown format throws', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final writer = CarWriter(roots: [block.cid], v2: true, index: true);
      await writer.write(block.cid, block.data);
      final bytes = await writer.close();
      // Locate the index payload using the v2 header fields.
      final dataOffset = _readUint64le(bytes, 11 + 16);
      final dataSize = _readUint64le(bytes, 11 + 24);
      final indexOffset = dataOffset + dataSize;
      bytes[indexOffset] = 0x05;
      final reader = CarReader.fromBytes(bytes);
      // Load the v1 payload first so that the corrupted index payload is cached.
      await reader.sections().toList();
      expect(
        () async => reader.findCID(block.cid),
        throwsA(isA<CarIndexException>()),
      );
    });
  });

  group('CarWriter error cases', () {
    test('block too large throws CarSectionException', () async {
      final root = await Block.fromData(Uint8List.fromList([1]), format: 'raw');
      final writer = CarWriter(roots: [root.cid], maxBlockSize: 2);
      final bigBlock = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        () => writer.write(root.cid, bigBlock),
        throwsA(isA<CarSectionException>()),
      );
    });

    test('missing root CID throws CarHeaderException', () async {
      final root = await Block.fromData(Uint8List.fromList([1]), format: 'raw');
      final other = await Block.fromData(
        Uint8List.fromList([2]),
        format: 'raw',
      );
      final writer = CarWriter(roots: [root.cid]);
      await writer.write(other.cid, other.data);
      expect(writer.close(), throwsA(isA<CarHeaderException>()));
    });

    test('rejects index without v2', () {
      expect(
        () => CarWriter(
          roots: [CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn')],
          index: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('IndexBuilder', () {
    test('builds sorted index with multihash sorting', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final builder = IndexBuilder(multihashSorted: true);
      builder.add(block.cid, 0);
      final index = builder.build();
      expect(index.length, greaterThan(4));
      expect(
        index[0] | (index[1] << 8) | (index[2] << 16) | (index[3] << 24),
        equals(0x0401),
      );
    });

    test('builds sorted index without multihash sorting', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final builder = IndexBuilder();
      builder.add(block.cid, 0);
      final index = builder.build();
      expect(
        index[0] | (index[1] << 8) | (index[2] << 16) | (index[3] << 24),
        equals(0x0400),
      );
    });
  });
}

int _headerEndOffset(Uint8List carBytes) {
  var offset = 0;
  var shift = 0;
  var value = 0;
  while (true) {
    final b = carBytes[offset];
    value |= (b & 0x7f) << shift;
    offset++;
    if ((b & 0x80) == 0) break;
    shift += 7;
  }
  return offset + value;
}

Uint8List _encodeVarint(int value) {
  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return Uint8List.fromList(bytes);
}

int _readUint64le(Uint8List bytes, int offset) {
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value |= bytes[offset + i] << (i * 8);
  }
  return value;
}
