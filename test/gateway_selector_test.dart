import 'dart:io';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:test/test.dart';

@Timeout(Duration(minutes: 2))
void main() {
  group('Gateway Selector Integration', () {
    late HttpServer server;
    late String serverUrl;
    late IPFSNode node;
    bool serverHit = false;

    late Directory tempDir;

    setUp(() async {
      // Create a temp directory for this test run
      tempDir = await Directory.systemTemp.createTemp('ipfs_test_');

      // Start a mock HTTP Gateway
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.address}:${server.port}/ipfs';
      serverHit = false;

      server.listen((HttpRequest request) {
        serverHit = true;
        final cid = request.uri.path.split('/').last;
        if (cid == 'test_cid') {
          request.response.statusCode = HttpStatus.ok;
          request.response.add([1, 2, 3]);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        request.response.close();
      });

      // Initialize IPFS Node with unique data path
      final config = IPFSConfig(offline: true, dataPath: tempDir.path);
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

      final result = await node.cat('test_cid');

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

    test(
      'GatewayMode.public uses default ipfs.io logic (Integration Check)',
      () async {
        // We can't easily mock the HARDCODED ipfs.io url in HttpGatewayClient without DI.
        // But we can verify it *tries* to use HttpGatewayClient logic.
        // Since we can't observe the private internal client URL easily, we will rely on
        // the fact that it DOESN'T hit our local mock server.
        node.setGatewayMode(GatewayMode.public);

        // This will try to hit the real internet/ipfs.io.
        // To prevent test flakiness/slowness, we might strict timeout or expect failure?
        // Actually, unmocked network tests are bad.
        // But we CAN verify it acts differently than 'custom'.

        // Let's just verify it definitely doesn't hit our local server.
        await node.cat(
          'test_cid',
        ); // This might hang or return null if offline/internet issues

        expect(
          serverHit,
          isFalse,
          reason: 'Public mode should not hit the local custom mock server',
        );
      },
    );
  });
}
