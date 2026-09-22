@Tags(['p1'])
library;

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

const kKuboApiHost = 'kubo';
const kKuboApiPort = 5001;
const kDartIpfsApiHost = 'dart_ipfs';
const kDartIpfsApiPort = 5001;

void main() {
  group('P1 DHT provide/find with Kubo', () {
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

    test('dart_ipfs provides a CID and Kubo finds it as a provider', () async {
      // Use a well-known CID for testing
      final testCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      // dart_ipfs announces as provider
      final provideResponse = await dartIpfs.dhtProvide(testCid);
      expect(provideResponse, isNotEmpty);

      // Wait for DHT propagation
      await Future<void>.delayed(const Duration(seconds: 5));

      // Kubo finds providers
      final findResponse = await kubo.dhtFindProviders(testCid);
      expect(findResponse, isNotEmpty);

      // Verify the response contains provider information
      // Kubo returns NDJSON, so we check if the peer ID appears in the response
      final dartIpfsId = await dartIpfs.id();
      final peerId = dartIpfsId['ID'] as String;
      expect(findResponse, contains(peerId));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Kubo provides a CID and dart_ipfs finds it as a provider', () async {
      // Use a well-known CID for testing
      final testCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      // Kubo announces as provider (Kubo v0.42 returns an empty body on success)
      await kubo.dhtProvide(testCid);

      // Wait for DHT propagation
      await Future<void>.delayed(const Duration(seconds: 20));

      // dart_ipfs finds providers
      final findResponse = await dartIpfs.dhtFindProviders(testCid);
      expect(findResponse, isNotEmpty);

      // Verify the response contains provider information
      // dart_ipfs returns NDJSON, so we check if the peer ID appears in the response
      final kuboId = await kubo.id();
      final peerId = kuboId['ID'] as String;
      expect(findResponse, contains(peerId));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
