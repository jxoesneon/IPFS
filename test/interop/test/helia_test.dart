@Tags(['helia'])
library;

import 'dart:convert';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/helia_client.dart';

void main() {
  final helia = HeliaClient(host: 'helia', port: 5001);
  final dartIpfs = DartIpfsClient(host: 'dart_ipfs', port: 5001);

  group('Helia basic connectivity', () {
    test('Helia server is reachable', () async {
      final id = await helia.id();
      expect(id, contains('ID'));
      expect(id, contains('Addresses'));
      expect(id, contains('AgentVersion'));
    });

    test('Helia version endpoint works', () async {
      final version = await helia.version();
      expect(version, contains('helia'));
    });

    test('Helia can add and retrieve data', () async {
      const testData = 'Hello from dart_ipfs interop test!';
      final addResult = await helia.add(testData);
      expect(addResult, contains('Hash'));
      expect(addResult, contains('Size'));

      final cid = addResult['Hash'] as String;
      final retrieved = await helia.cat(cid);
      expect(retrieved, equals(testData));
    });
  });

  group('Helia Bitswap/CAR interop', () {
    test(
      'dart_ipfs can exchange a CAR with Helia',
      () async {
        const testData = 'CAR exchange with Helia';
        final addResult = await helia.add(testData);
        final cid = addResult['Hash'] as String;

        // Export CAR from Helia and import into dart_ipfs.
        final carData = await helia.dagExport(cid);
        await dartIpfs.dagImport(carData);
        final fromDart = await dartIpfs.blockGet(cid);
        expect(fromDart, equals(utf8.encode(testData)));

        // Export CAR from dart_ipfs and import back into Helia.
        const roundtripData = 'CAR roundtrip from dart_ipfs';
        final dartCid = await dartIpfs.blockPut(utf8.encode(roundtripData));
        final dartCar = await dartIpfs.dagExport(dartCid);
        await helia.dagImport(dartCar);
        final fromHelia = await helia.cat(dartCid);
        expect(fromHelia, equals(roundtripData));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
