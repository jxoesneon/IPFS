@Tags(['p0'])
library;

import 'dart:typed_data';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/cid_matcher.dart';
// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

const kKuboApiHost = 'kubo';
const kKuboApiPort = 5001;
const kDartIpfsApiHost = 'dart_ipfs';
const kDartIpfsApiPort = 5001;

void main() {
  group('P0 Bitswap fetch with Kubo', () {
    late KuboClient kubo;
    late DartIpfsClient dartIpfs;

    setUpAll(() async {
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
      dartIpfs = DartIpfsClient(host: kDartIpfsApiHost, port: kDartIpfsApiPort);

      // Ensure both nodes are ready
      await kubo.id();
      await dartIpfs.id();

      // Ensure connectivity
      final kuboId = await kubo.id();
      final dartIpfsId = await dartIpfs.id();
      final kuboPeerId = kuboId['ID'] as String;
      final dartIpfsPeerId = dartIpfsId['ID'] as String;

      try {
        await kubo.swarmConnect('/dns4/dart_ipfs/tcp/4001/p2p/$dartIpfsPeerId');
        await dartIpfs.swarmConnect('/dns4/kubo/tcp/4001/p2p/$kuboPeerId');
      } catch (e) {
        // Best effort - tests may still work
      }
    });

    test(
      'dart_ipfs can fetch a block from Kubo via Bitswap',
      () async {
        // Test data - a simple block
        final testData = Uint8List.fromList('Hello from Kubo!'.codeUnits);

        // Add block to Kubo
        final kuboCid = await kubo.blockPut(testData);
        print('Added block to Kubo with CID: $kuboCid');

        // Wait a moment for Bitswap to propagate
        await Future<void>.delayed(const Duration(seconds: 5));

        // Fetch the same block from dart_ipfs via Bitswap
        final fetchedData = await dartIpfs.blockGet(kuboCid);
        print('Fetched block from dart_ipfs');

        // Verify the content matches
        expect(
          bytesEqual(fetchedData, testData),
          isTrue,
          reason: 'Fetched data should match original data',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Kubo can fetch a block from dart_ipfs via Bitswap',
      () async {
        // Test data - a simple block
        final testData = Uint8List.fromList('Hello from dart_ipfs!'.codeUnits);

        // Add block to dart_ipfs
        final dartIpfsCid = await dartIpfs.blockPut(testData);
        print('Added block to dart_ipfs with CID: $dartIpfsCid');

        // Wait a moment for Bitswap to propagate
        await Future<void>.delayed(const Duration(seconds: 5));

        // Fetch the same block from Kubo via Bitswap
        final fetchedData = await kubo.blockGet(dartIpfsCid);
        print('Fetched block from Kubo');

        // Verify the content matches (convert Uint8List to List<int> for comparison)
        expect(
          bytesEqual(fetchedData, testData),
          isTrue,
          reason: 'Fetched data should match original data',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
