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
  group('P1 IPNS resolution with Kubo', () {
    late KuboClient kubo;
    late DartIpfsClient dartIpfs;

    setUpAll(() async {
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
      dartIpfs = DartIpfsClient(
        host: kDartIpfsApiHost,
        port: kDartIpfsApiPort,
      );

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
      'dart_ipfs publishes a signed IPNS record and Kubo resolves it',
      () async {
        // Use a well-known CID for testing
        final testPath = '/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

        // dart_ipfs publishes IPNS record
        final publishResponse = await dartIpfs.namePublish(testPath);
        expect(publishResponse, isNotEmpty);
        expect(publishResponse['Name'], isNotNull);
        expect(publishResponse['Value'], equals(testPath));

        final ipnsName = publishResponse['Name'] as String;

        // Wait for IPNS propagation
        await Future<void>.delayed(const Duration(seconds: 5));

        // Kubo resolves the IPNS record
        final resolveResponse = await kubo.nameResolve(ipnsName);
        expect(resolveResponse, isNotEmpty);
        expect(resolveResponse['Path'], isNotNull);

        // Verify the resolved path matches the published path
        final resolvedPath = resolveResponse['Path'] as String;
        expect(resolvedPath, contains(testPath));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Kubo publishes a signed IPNS record and dart_ipfs resolves it',
      () async {
        // Use a well-known CID for testing
        final testPath = '/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

        // Kubo publishes IPNS record
        final publishResponse = await kubo.namePublish(testPath);
        expect(publishResponse, isNotEmpty);
        expect(publishResponse['Name'], isNotNull);
        expect(publishResponse['Value'], equals(testPath));

        final ipnsName = publishResponse['Name'] as String;

        // Wait for IPNS propagation
        await Future<void>.delayed(const Duration(seconds: 5));

        // dart_ipfs resolves the IPNS record
        final resolveResponse = await dartIpfs.nameResolve(ipnsName);
        expect(resolveResponse, isNotEmpty);
        expect(resolveResponse['Path'], isNotNull);

        // Verify the resolved path matches the published path
        final resolvedPath = resolveResponse['Path'] as String;
        expect(resolvedPath, contains(testPath));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
