@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

/// E2E tests for the node's embedded HTTP RPC API (`enableRPC`).
///
/// The node builder binds the RPC server to localhost:5001, so this file
/// owns that port for its process — it must not run a second RPC node.
void main() {
  group('E2E RPC API', () {
    const apiKey = 'e2e-secret-key';
    const base = 'http://localhost:5001';

    late Directory repo;
    IPFSNode? node;
    HttpClient? client;

    setUp(() async {
      repo = await makeRepoDir('rpc');
      node = await IPFSNode.create(
        IPFSConfig(
          offline: true,
          enableRPC: true,
          rpcApiKey: apiKey,
          dataPath: '${repo.path}/repo',
          datastorePath: '${repo.path}/repo/datastore',
          keystorePath: '${repo.path}/repo/keystore',
          blockStorePath: '${repo.path}/repo/blocks',
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

    Future<HttpClientResponse> post(
      String path, {
      String? key,
      List<int>? body,
      String? contentType,
    }) async {
      final uri = Uri.parse('$base$path');
      final request = await client!.postUrl(uri);
      if (key != null) request.headers.set('x-api-key', key);
      if (contentType != null) {
        request.headers.set('content-type', contentType);
      }
      if (body != null) request.add(body);
      return request.close();
    }

    List<int> multipartFile(String boundary, String name, List<int> bytes) {
      final builder = BytesBuilder()
        ..add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="file"; '
            'filename="$name"\r\n'
            'Content-Type: application/octet-stream\r\n\r\n',
          ),
        )
        ..add(bytes)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      return builder.toBytes();
    }

    test('health endpoint is public', () async {
      final request = await client!.getUrl(Uri.parse('$base/health'));
      final response = await request.close();
      expect(response.statusCode, equals(200));
      await response.drain<void>();
    });

    test('version and id are public and report the node', () async {
      var response = await post('/api/v0/version');
      expect(response.statusCode, equals(200));
      final version = jsonDecode(await response.transform(utf8.decoder).join());
      expect(version['Version'], isA<String>());

      // /api/v0/id reports the node's libp2p peer ID, which only exists
      // on an online node — swap the offline node for an online one
      // (stopping it first keeps this file's single RPC port owner).
      await stopQuietly(node);
      node = await IPFSNode.create(
        IPFSConfig(
          offline: false,
          enableRPC: true,
          rpcApiKey: apiKey,
          dataPath: '${repo.path}/repo',
          datastorePath: '${repo.path}/repo/datastore',
          keystorePath: '${repo.path}/repo/keystore',
          blockStorePath: '${repo.path}/repo/blocks',
          network: NetworkConfig(
            listenAddresses: const ['/ip4/127.0.0.1/tcp/0'],
            bootstrapPeers: const [],
            enableMDNS: false,
            enableNatTraversal: false,
          ),
        ),
      );
      await node!.start();

      response = await post('/api/v0/id');
      expect(response.statusCode, equals(200));
      final id = jsonDecode(await response.transform(utf8.decoder).join());
      expect(id['ID'], equals(node!.peerID));
    });

    test('write endpoints reject missing or wrong API keys', () async {
      var response = await post('/api/v0/cat?arg=QmTest');
      expect(response.statusCode, equals(403));
      await response.drain<void>();

      response = await post('/api/v0/cat?arg=QmTest', key: 'wrong-key');
      expect(response.statusCode, equals(403));
      await response.drain<void>();
    });

    test('add then cat round-trips content over the API', () async {
      const boundary = '----e2eboundary';
      final data = utf8.encode('rpc file content');

      var response = await post(
        '/api/v0/add',
        key: apiKey,
        body: multipartFile(boundary, 'f.txt', data),
        contentType: 'multipart/form-data; boundary=$boundary',
      );
      expect(response.statusCode, equals(200));
      final addBody = await response.transform(utf8.decoder).join();
      final cid =
          (jsonDecode(addBody.trim().split('\n').first)
                  as Map<String, dynamic>)['Hash']
              as String;
      expect(cid, isNotEmpty);

      response = await post('/api/v0/cat?arg=$cid', key: apiKey);
      expect(response.statusCode, equals(200));
      final body = await response.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      expect(body, equals(data));
    });

    test('block/put then block/get and block/stat round-trip', () async {
      final data = utf8.encode('raw block');

      var response = await post('/api/v0/block/put', key: apiKey, body: data);
      expect(response.statusCode, equals(200));
      final put = jsonDecode(await response.transform(utf8.decoder).join());
      final cid = put['Key'] as String;
      expect(put['Size'], equals(data.length));

      response = await post('/api/v0/block/get?arg=$cid', key: apiKey);
      expect(response.statusCode, equals(200));
      final body = await response.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      expect(body, equals(data));

      response = await post('/api/v0/block/stat?arg=$cid', key: apiKey);
      expect(response.statusCode, equals(200));
      final stat = jsonDecode(await response.transform(utf8.decoder).join());
      expect(stat['Size'], equals(data.length));
    });

    test('swarm/peers returns an empty peer list on an offline node', () async {
      final response = await post('/api/v0/swarm/peers', key: apiKey);
      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      expect(body['Peers'], isA<List<dynamic>>());
    });

    test('ls lists a directory added through the node', () async {
      final rootCid = await node!.addDirectory({
        'listed.txt': Uint8List.fromList(utf8.encode('x')),
      });

      final response = await post('/api/v0/ls?arg=$rootCid', key: apiKey);
      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      final links = body['Objects'][0]['Links'] as List<dynamic>;
      expect(links.map((l) => l['Name']), contains('listed.txt'));
    });
  });
}
