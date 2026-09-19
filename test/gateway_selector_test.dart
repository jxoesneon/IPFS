import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/cid.dart' as ipfs_cid;
import 'package:test/test.dart';

void main() {
  group('Gateway Selector Integration', () {
    late HttpServer server;
    late String serverUrl;
    late IPFSNode node;
    late String testCid;
    bool serverHit = false;

    late Directory tempDir;

    setUp(() async {
      // Create a temp directory for this test run
      tempDir = await Directory.systemTemp.createTemp('ipfs_test_');

      // The node hash-verifies fetched blocks, so the CID must match the
      // served payload.
      testCid = (await ipfs_cid.CID.computeForData(
        Uint8List.fromList([1, 2, 3]),
      )).toString();

      // Start a mock HTTP Gateway
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.address}:${server.port}/ipfs';
      serverHit = false;

      server.listen((HttpRequest request) {
        serverHit = true;
        final cid = request.uri.path.split('/').last;
        if (cid == testCid) {
          request.response.statusCode = HttpStatus.ok;
          request.response.add([1, 2, 3]);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        request.response.close();
      });

      // Initialize IPFS Node with unique data path
      final config = IPFSConfig(
        offline: true,
        dataPath: tempDir.path,
        datastorePath: '${tempDir.path}/datastore',
      );
      node = await IPFSNode.create(config);
      await node.start(); // Ensure services (Datastore) are initialized
    });

    tearDown(() async {
      await node.stop(); // Release locks
      await server.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('GatewayMode.custom uses the provided URL', () async {
      node.setGatewayMode(GatewayMode.custom, customUrl: serverUrl);

      final result = await node.cat(testCid);

      expect(
        serverHit,
        isTrue,
        reason: 'Server should have been hit in custom mode',
      );
      expect(
        result,
        equals([1, 2, 3]),
        reason: 'Should return data from gateway',
      );
    });

    test(
      'GatewayMode.internal does NOT use the gateway (for non-existent local content)',
      () async {
        node.setGatewayMode(GatewayMode.internal);

        // Attempting to cat a random CID that definitely isn't in local store.
        // In offline mode with no peers, it should fail nicely or return null,
        // BUT importantly, it should NOT hit our HTTP server.
        final result = await node.cat('test_cid');

        expect(
          serverHit,
          isFalse,
          reason: 'Server should NOT be hit in internal mode',
        );
        expect(
          result,
          isNull,
          reason: 'Should return null for missing content in offline mode',
        );
      },
    );

    test('GatewayMode.public fetches via the configured gateway URL', () async {
      // The public-mode URL is configurable (BitswapConfig.publicGatewayUrl,
      // default https://ipfs.io/ipfs) — pointing it at the mock server makes
      // this hermetic while exercising the same code path.
      await node.stop();
      final config = IPFSConfig(
        offline: true,
        dataPath: tempDir.path,
        datastorePath: '${tempDir.path}/datastore',
        bitswap: BitswapConfig(publicGatewayUrl: serverUrl),
      );
      node = await IPFSNode.create(config);
      await node.start();
      node.setGatewayMode(GatewayMode.public);

      final result = await node.cat(testCid);

      expect(
        serverHit,
        isTrue,
        reason: 'Public mode should hit the configured gateway URL',
      );
      expect(result, equals([1, 2, 3]));
    });

    test('BitswapConfig.publicGatewayUrl defaults to ipfs.io', () {
      expect(
        const BitswapConfig().publicGatewayUrl,
        equals('https://ipfs.io/ipfs'),
      );
    });
  });
}
