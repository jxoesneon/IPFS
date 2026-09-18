@TestOn('vm')
import 'dart:io';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E gateway retrieval', () {
    late Directory repo;
    IPFSNode? node;
    HttpServer? gateway;

    setUp(() async {
      repo = await makeRepoDir('gateway');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await gateway?.close(force: true);
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    /// Starts a mock HTTP gateway that serves [body] for any CID path.
    Future<String> startMockGateway(List<int> body) async {
      gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      gateway!.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..add(body)
          ..close();
      });
      return 'http://127.0.0.1:${gateway!.port}/ipfs';
    }

    test('custom gateway mode fetches and hash-verifies a raw block', () async {
      final data = utf8Bytes('gateway content');
      final cid = CID.computeForDataSync(data).encode();
      final url = await startMockGateway(data);

      node!.setGatewayMode(GatewayMode.custom, customUrl: url);
      final fetched = await node!.cat(cid);

      expect(fetched, equals(data));
    });

    test(
      'custom gateway rejects content that fails hash verification',
      () async {
        // The CID addresses 'expected' but the gateway serves different bytes.
        final cid = CID.computeForDataSync(utf8Bytes('expected')).encode();
        final url = await startMockGateway(utf8Bytes('evil substitute'));

        node!.setGatewayMode(GatewayMode.custom, customUrl: url);
        final fetched = await node!.cat(cid);

        expect(fetched, isNull);
      },
    );

    test('local gateway mode fetches from 127.0.0.1:8080', () async {
      // GatewayMode.local is hardcoded to http://127.0.0.1:8080/ipfs —
      // bind the mock there if the port is free, otherwise this
      // environment cannot exercise the journey.
      HttpServer? local;
      try {
        local = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      } on SocketException {
        return;
      }
      gateway = local;
      final data = utf8Bytes('local gateway content');
      local.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..add(data)
          ..close();
      });

      final cid = CID.computeForDataSync(data).encode();
      node!.setGatewayMode(GatewayMode.local);
      final fetched = await node!.cat(cid);

      expect(fetched, equals(data));
    });
  });

  group('E2E gateway server', () {
    late Directory repo;
    IPFSNode? node;
    int port = 0;
    HttpClient? client;

    setUp(() async {
      repo = await makeRepoDir('gw_server');
      port = await freePort();
      node = await IPFSNode.create(
        IPFSConfig(
          offline: true,
          dataPath: '${repo.path}/repo',
          datastorePath: '${repo.path}/repo/datastore',
          keystorePath: '${repo.path}/repo/keystore',
          blockStorePath: '${repo.path}/repo/blocks',
          gateway: GatewayConfig(
            enabled: true,
            address: '127.0.0.1',
            port: port,
          ),
        ),
      );
      await node!.start();
      client = HttpClient();
    });

    tearDown(() async {
      client?.close(force: true);
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    Future<HttpClientResponse> get(String path) async {
      final request = await client!.get('127.0.0.1', port, path);
      return request.close();
    }

    test('serves locally stored content at /ipfs/<cid>', () async {
      final data = utf8Bytes('served by gateway');
      final cid = await node!.addFile(data);

      final response = await get('/ipfs/$cid');
      expect(response.statusCode, equals(200));
      final body = await response.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      expect(body, equals(data));
    });

    test('returns an error status for a missing CID', () async {
      final absent = CID.computeForDataSync(utf8Bytes('absent')).encode();
      final response = await get('/ipfs/$absent');

      expect(response.statusCode, isNot(equals(200)));
      await response.drain<void>();
    });
  });
}
