import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart' show GatewayMode;
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

/// Minimal [DatastoreHandler] fake: every read misses and writes are recorded.
class _FakeDatastoreHandler implements DatastoreHandler {
  final Map<String, Block> storedBlocks = {};

  /// When set, [getBlock] throws this error instead of returning null.
  Object? getBlockError;

  @override
  Future<Block?> getBlock(String cid) async {
    final error = getBlockError;
    if (error != null) throw error;
    return null;
  }

  @override
  Future<void> putBlock(Block block) async {
    storedBlocks[block.cid.encode()] = block;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Minimal [MetricsCollector] fake for [DenylistService].
class _FakeMetricsCollector implements MetricsCollector {
  final List<String> securityEvents = [];

  @override
  void recordSecurityEvent(String type) {
    securityEvents.add(type);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Router whose connect/disconnect always fail, exercising the catch blocks
/// in [NetworkHandler.connectToPeer] and [NetworkHandler.disconnectFromPeer].
class _ThrowingRouter extends FakeRouter {
  @override
  Future<void> connect(String multiaddress) async {
    throw StateError('connect failed');
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    throw StateError('disconnect failed');
  }
}

/// Concrete subclass that inherits [RouterInterface]'s default members
/// (e.g. [RouterInterface.supportedProtocols]) instead of overriding them.
class _DefaultMembersRouter extends RouterInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  Logger.root.level = Level.OFF;

  group('ContentManager denylist', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;
    late _FakeMetricsCollector metrics;
    late DenylistService denylist;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
      metrics = _FakeMetricsCollector();
      denylist = DenylistService(
        const SecurityConfig(
          enableDenylist: true,
          denylistDefaultAction: 'block',
        ),
        metrics,
      );
    });

    tearDown(() async {
      await denylist.stop();
      await contentController.close();
    });

    test('get throws DenylistBlockedException for blocked CID', () async {
      final cid = (await CID.fromContent(
        Uint8List.fromList([9, 9, 9]),
        codec: 'raw',
      )).encode();
      denylist.blockCidString(cid);

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        denylistService: denylist,
      );

      await expectLater(
        manager.get(cid),
        throwsA(isA<DenylistBlockedException>()),
      );
      expect(metrics.securityEvents, contains('denylist_blocked'));
    });

    test(
      'get returns null when the datastore read raises StateError',
      () async {
        final manager = ContentManager(
          datastoreHandler: datastore,
          newContentController: contentController,
          denylistService: denylist,
        );
        datastore.getBlockError = StateError('corrupt index');
        final cid = (await CID.fromContent(
          Uint8List.fromList([4, 5, 6]),
          codec: 'raw',
        )).encode();

        expect(await manager.get(cid), isNull);
      },
    );
  });

  group('ContentManager ls', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await contentController.close();
    });

    test('falls back to the blockstore when the datastore misses', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_ls_test_');
      addTearDown(() => repoDir.delete(recursive: true));

      final child = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final dirNode = MerkleDAGNode(
        links: [
          Link(name: 'child.txt', cid: child.cid, size: child.data.length),
        ],
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.Directory,
        ).writeToBuffer(),
      );
      final dirBlock = Block(cid: dirNode.cid, data: dirNode.toBytes());

      final store = BlockStore(path: repoDir.path);
      await store.putBlock(dirBlock);

      // Datastore misses and no bitswap handler is registered, so ls must
      // consult the blockstore and decode the directory links from there.
      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );
      final links = await manager.ls(dirBlock.cid.encode());
      expect(links.single.name, equals('child.txt'));
    });

    test('enumerates logical entries for a HAMT-sharded root', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_ls_hamt_');
      addTearDown(() => repoDir.delete(recursive: true));

      final store = BlockStore(path: repoDir.path);
      final entries = <UnixFSDirectoryEntry>[];
      for (var i = 0; i < 8; i++) {
        final data = Uint8List.fromList([i]);
        final cid = await CID.fromContent(data, codec: 'raw');
        await store.putBlock(Block(cid: cid, data: data));
        entries.add(
          UnixFSDirectoryEntry(name: 'file-$i.txt', cid: cid, tsize: 0),
        );
      }
      final root = await createDirectory(store, entries, shardThreshold: 2);
      expect(root.isHAMTShard, isTrue);

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );
      final links = await manager.ls(root.cid.encode());
      expect(
        links.map((l) => l.name).toSet(),
        equals({for (var i = 0; i < 8; i++) 'file-$i.txt'}),
      );
    });
  });

  group('ContentManager path resolution', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await contentController.close();
    });

    test('get resolves a path inside a plain directory', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_getpath_');
      addTearDown(() => repoDir.delete(recursive: true));

      final store = BlockStore(path: repoDir.path);
      final payload = Uint8List.fromList(utf8.encode('hello path'));
      final fileCid = await CID.fromContent(payload, codec: 'raw');
      await store.putBlock(Block(cid: fileCid, data: payload));
      final root = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'a.txt', cid: fileCid, tsize: 0),
      ]);

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );
      final data = await manager.get(root.cid.encode(), path: 'a.txt');
      expect(data, equals(payload));
    });

    test('get resolves a path inside a HAMT-sharded directory', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_gethamt_');
      addTearDown(() => repoDir.delete(recursive: true));

      final store = BlockStore(path: repoDir.path);
      final payload = Uint8List.fromList(utf8.encode('sharded content'));
      final fileCid = await CID.fromContent(payload, codec: 'raw');
      await store.putBlock(Block(cid: fileCid, data: payload));
      final entries = <UnixFSDirectoryEntry>[
        UnixFSDirectoryEntry(name: 'target.txt', cid: fileCid, tsize: 0),
      ];
      for (var i = 0; i < 10; i++) {
        final filler = Uint8List.fromList([i, i]);
        final fillerCid = await CID.fromContent(filler, codec: 'raw');
        await store.putBlock(Block(cid: fillerCid, data: filler));
        entries.add(
          UnixFSDirectoryEntry(name: 'filler-$i', cid: fillerCid, tsize: 0),
        );
      }
      final root = await createDirectory(store, entries, shardThreshold: 2);
      expect(root.isHAMTShard, isTrue);

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );
      final data = await manager.get(root.cid.encode(), path: 'target.txt');
      expect(data, equals(payload));
    });

    test('get returns null when the path does not resolve', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_getmiss_');
      addTearDown(() => repoDir.delete(recursive: true));

      final store = BlockStore(path: repoDir.path);
      final payload = Uint8List.fromList([1, 2, 3]);
      final fileCid = await CID.fromContent(payload, codec: 'raw');
      await store.putBlock(Block(cid: fileCid, data: payload));
      final root = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'exists.txt', cid: fileCid, tsize: 0),
      ]);

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );
      final data = await manager.get(root.cid.encode(), path: 'missing.txt');
      expect(data, isNull);
    });

    test(
      'denylisted child block propagates a policy error during traversal',
      () async {
        final repoDir = await Directory.systemTemp.createTemp('ipfs_denypath_');
        addTearDown(() => repoDir.delete(recursive: true));

        final store = BlockStore(path: repoDir.path);
        final payload = Uint8List.fromList(utf8.encode('blocked child'));
        final fileCid = await CID.fromContent(payload, codec: 'raw');
        await store.putBlock(Block(cid: fileCid, data: payload));
        final root = await createDirectory(store, [
          UnixFSDirectoryEntry(name: 'bad.txt', cid: fileCid, tsize: 0),
        ]);

        final metrics = _FakeMetricsCollector();
        final denylist = DenylistService(
          const SecurityConfig(
            enableDenylist: true,
            denylistDefaultAction: 'block',
          ),
          metrics,
        );
        addTearDown(() => denylist.stop());
        denylist.blockCidString(fileCid.encode());

        final manager = ContentManager(
          datastoreHandler: datastore,
          newContentController: contentController,
          blockStore: store,
          denylistService: denylist,
        );

        await expectLater(
          manager.get(root.cid.encode(), path: 'bad.txt'),
          throwsA(isA<DenylistBlockedException>()),
        );
      },
    );
  });

  group('ContentManager addDirectory sharding', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await contentController.close();
    });

    test('shardThreshold produces a HAMT root resolvable via get', () async {
      final repoDir = await Directory.systemTemp.createTemp('ipfs_addhamt_');
      addTearDown(() => repoDir.delete(recursive: true));

      final store = BlockStore(path: repoDir.path);
      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        blockStore: store,
      );

      final rootCid = await manager.addDirectory({
        for (var i = 0; i < 12; i++)
          'entry-$i.bin': Uint8List.fromList([i, i, i]),
      }, shardThreshold: 2);

      // The root block must be a HAMT shard, and path resolution must reach
      // a leaf through the shard links.
      final rootResp = await store.getBlock(rootCid);
      expect(rootResp.found, isTrue);
      final data = await manager.get(rootCid, path: 'entry-3.bin');
      expect(data, equals(Uint8List.fromList([3, 3, 3])));
    });
  });

  group('ContentManager HTTP fallback', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await contentController.close();
    });

    ContentManager managerWithFallback(
      List<String> gateways, {
      bool allowPrivate = false,
    }) {
      return ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
        bitswapConfig: BitswapConfig(
          enableHttpFallback: true,
          httpFallbackGateways: gateways,
          allowPrivateGateways: allowPrivate,
          httpTimeout: const Duration(seconds: 5),
        ),
      );
    }

    Future<HttpServer> serveWith(
      void Function(HttpRequest request) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(handler);
      return server;
    }

    test('fetches, verifies, and caches block from gateway', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('fallback content')),
      );
      final server = await serveWith((request) {
        request.response.add(block.data);
        request.response.close();
      });
      addTearDown(() => server.close());
      final gateway = 'http://127.0.0.1:${server.port}';

      final manager = managerWithFallback([gateway], allowPrivate: true);
      final result = await manager.get(block.cid.encode());

      expect(result, equals(block.data));
      expect(datastore.storedBlocks[block.cid.encode()], isNotNull);
    });

    test('skips invalid and private gateway URLs', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));

      final manager = managerWithFallback([
        'ftp://not-http.example',
        'http://127.0.0.1:1',
        'http://172.16.0.1:1',
      ]);

      final result = await manager.get(block.cid.encode());
      expect(result, isNull);
      expect(datastore.storedBlocks, isEmpty);
    });

    test('continues to next gateway when block fails verification', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('expected bytes')),
      );
      final server = await serveWith((request) {
        request.response.add(utf8.encode('tampered bytes'));
        request.response.close();
      });
      addTearDown(() => server.close());
      final badGateway = 'http://127.0.0.1:${server.port}';

      final manager = managerWithFallback([
        'ftp://skipped.example',
        badGateway,
      ], allowPrivate: true);

      final result = await manager.get(block.cid.encode());
      expect(result, isNull);
      expect(datastore.storedBlocks, isEmpty);
    });

    test('returns null when gateway responds 404', () async {
      final block = await Block.fromData(Uint8List.fromList([4, 5, 6]));
      final server = await serveWith((request) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      });
      addTearDown(() => server.close());
      final gateway = 'http://127.0.0.1:${server.port}';

      final manager = managerWithFallback([gateway], allowPrivate: true);
      final result = await manager.get(block.cid.encode());

      expect(result, isNull);
      expect(datastore.storedBlocks, isEmpty);
    });
  });

  group('ContentManager gateway retrieval', () {
    late _FakeDatastoreHandler datastore;
    late StreamController<String> contentController;

    setUp(() {
      datastore = _FakeDatastoreHandler();
      contentController = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await contentController.close();
    });

    Future<HttpServer> serveWith(
      void Function(HttpRequest request) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(handler);
      return server;
    }

    test(
      'returns hash-verified bytes for a raw-codec CID via custom gateway',
      () async {
        final block = await Block.fromData(
          Uint8List.fromList(utf8.encode('gateway content')),
        );
        expect(block.cid.codec, equals('raw'));

        final server = await serveWith((request) {
          request.response.add(block.data);
          request.response.close();
        });
        addTearDown(() => server.close());

        final manager = ContentManager(
          datastoreHandler: datastore,
          newContentController: contentController,
        );
        final result = await manager.get(
          block.cid.encode(),
          gatewayMode: GatewayMode.custom,
          customGatewayUrl: 'http://127.0.0.1:${server.port}/ipfs',
        );

        expect(result, equals(block.data));
      },
    );

    test('rejects a raw-codec block that fails hash verification', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('expected content')),
      );
      expect(block.cid.codec, equals('raw'));

      // The gateway returns bytes that do not hash to the requested CID:
      // the raw-codec guard must reject them rather than trust the gateway.
      final server = await serveWith((request) {
        request.response.add(utf8.encode('forged content'));
        request.response.close();
      });
      addTearDown(() => server.close());

      final manager = ContentManager(
        datastoreHandler: datastore,
        newContentController: contentController,
      );
      final result = await manager.get(
        block.cid.encode(),
        gatewayMode: GatewayMode.custom,
        customGatewayUrl: 'http://127.0.0.1:${server.port}/ipfs',
      );

      expect(result, isNull);
      expect(datastore.storedBlocks, isEmpty);
    });
  });

  group('HttpGatewayClient.isPrivateOrLoopbackHost', () {
    test('detects 172.16.0.0/12 private range', () {
      expect(HttpGatewayClient.isPrivateOrLoopbackHost('172.16.0.1'), isTrue);
      expect(HttpGatewayClient.isPrivateOrLoopbackHost('172.31.255.1'), isTrue);
      expect(HttpGatewayClient.isPrivateOrLoopbackHost('172.15.0.1'), isFalse);
      expect(HttpGatewayClient.isPrivateOrLoopbackHost('172.32.0.1'), isFalse);
      expect(HttpGatewayClient.isPrivateOrLoopbackHost('172.x.0.1'), isFalse);
    });
  });

  group('RouterInterface defaults', () {
    test('supportedProtocols defaults to empty set', () {
      final router = _DefaultMembersRouter();
      expect(router.supportedProtocols, isEmpty);
    });
  });

  group('NetworkHandler connect/disconnect errors', () {
    test(
      'connectToPeer and disconnectFromPeer propagate router errors',
      () async {
        final handler = NetworkHandler(
          IPFSConfig(network: NetworkConfig(bootstrapPeers: [])),
          router: _ThrowingRouter(),
        );

        await expectLater(
          handler.connectToPeer('/ip4/127.0.0.1/tcp/4001'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          handler.disconnectFromPeer('peer1'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
