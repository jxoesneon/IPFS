@Tags(['p0'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';

const kKuboApiHost = String.fromEnvironment('KUBO_HOST', defaultValue: 'kubo');
const kKuboApiPort = int.fromEnvironment('KUBO_PORT', defaultValue: 5001);
const kDartIpfsApiHost = String.fromEnvironment('DART_IPFS_HOST', defaultValue: 'dart_ipfs');
const kDartIpfsApiPort = int.fromEnvironment('DART_IPFS_PORT', defaultValue: 5001);

void main() {
  group('P0 CAR exchange with Kubo', () {
    late KuboClient kubo;
    late DartIpfsClient dartIpfs;
    bool servicesAvailable = false;

    setUpAll(() async {
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
      dartIpfs = DartIpfsClient(
        host: kDartIpfsApiHost,
        port: kDartIpfsApiPort,
      );

      try {
        await kubo.id();
        await dartIpfs.id();
        servicesAvailable = true;
      } catch (_) {
        // Services not available, tests will return early.
      }
    });

    test(
      'dart_ipfs can export a CAR that Kubo can import',
      () async {
        if (!servicesAvailable) return;
        // 1. Create test data in dart_ipfs
        final testData = utf8.encode('Hello from dart_ipfs CAR test!');
        final cid = await dartIpfs.blockPut(testData);

        // 2. Export CAR from dart_ipfs
        final carData = await dartIpfs.dagExport(cid);
        expect(carData.isNotEmpty, isTrue);

        // 3. Import CAR into Kubo
        await kubo.dagImport(carData);

        // 4. Verify the block is accessible in Kubo
        final retrievedData = await kubo.blockGet(cid);
        expect(retrievedData, equals(testData));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Kubo can export a CAR that dart_ipfs can import',
      () async {
        if (!servicesAvailable) return;
        // 1. Create test data in Kubo
        final testData = utf8.encode('Hello from Kubo CAR test!');
        final cid = await kubo.blockPut(testData);

        // 2. Export CAR from Kubo
        final carData = await kubo.dagExport(cid);
        expect(carData.isNotEmpty, isTrue);

        // 3. Import CAR into dart_ipfs
        await dartIpfs.dagImport(carData);

        // 4. Verify the block is accessible in dart_ipfs
        final retrievedData = await dartIpfs.blockGet(cid);
        expect(retrievedData, equals(testData));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('CAR format validation', () {
    test('CAR export/import roundtrip preserves data', () async {
      // Create test data
      final testData = utf8.encode('CAR roundtrip test data');
      final block = await Block.fromData(Uint8List.fromList(testData));

      // Export to CAR
      final writer = CarWriter(roots: [block.cid]);
      await writer.write(block.cid, block.data);
      final carData = await writer.close();

      // Import from CAR
      final reader = CarReader.fromBytes(carData);
      final header = await reader.header;
      expect(header.version, equals(1));
      expect(header.roots.length, equals(1));
      expect(header.roots.first, equals(block.cid));

      final sections = await reader.sections().toList();
      expect(sections.length, equals(1));
      expect(sections.first.cid, equals(block.cid));
      expect(sections.first.bytes, equals(block.data));
    });

    test('CAR with multiple blocks exports and imports correctly', () async {
      // Create multiple blocks
      final block1 = await Block.fromData(Uint8List.fromList(utf8.encode('block1')));
      final block2 = await Block.fromData(Uint8List.fromList(utf8.encode('block2')));
      final block3 = await Block.fromData(Uint8List.fromList(utf8.encode('block3')));

      // Export to CAR with block1 as root
      final writer = CarWriter(roots: [block1.cid]);
      await writer.write(block1.cid, block1.data);
      await writer.write(block2.cid, block2.data);
      await writer.write(block3.cid, block3.data);
      final carData = await writer.close();

      // Import from CAR
      final reader = CarReader.fromBytes(carData);
      final sections = await reader.sections().toList();
      expect(sections.length, equals(3));

      // Verify all blocks are present
      final cids = sections.map((s) => s.cid).toSet();
      expect(cids, contains(block1.cid));
      expect(cids, contains(block2.cid));
      expect(cids, contains(block3.cid));

      // Verify data integrity
      for (final section in sections) {
        if (section.cid == block1.cid) {
          expect(section.bytes, equals(block1.data));
        } else if (section.cid == block2.cid) {
          expect(section.bytes, equals(block2.data));
        } else if (section.cid == block3.cid) {
          expect(section.bytes, equals(block3.data));
        }
      }
    });
  });
}
