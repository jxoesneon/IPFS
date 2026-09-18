import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

/// Minimal [DatastoreHandler] fake: every read misses and writes are recorded.
class _FakeDatastoreHandler implements DatastoreHandler {
  final Map<String, Block> storedBlocks = {};

  @override
  Future<Block?> getBlock(String cid) async => null;

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

    test('get throws StateError for blocked CID', () async {
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
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Content blocked by operator policy',
          ),
        ),
      );
      expect(metrics.securityEvents, contains('denylist_blocked'));
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
