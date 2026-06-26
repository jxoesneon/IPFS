import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/platform/http_server.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MockIpfsHttpServerInstance implements IpfsHttpServerInstance {
  bool closed = false;
  @override
  Future<void> close({bool force = false}) async {
    closed = true;
  }

  @override
  String get host => 'localhost';

  @override
  int get port => 8080;
}

class MockHttpServerAdapter implements HttpServerAdapter {
  Handler? lastHandler;
  String? lastAddress;
  int? lastPort;
  Completer<IpfsHttpServerInstance> completer = Completer();
  bool shouldFail = false;

  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    lastHandler = handler;
    lastAddress = address;
    lastPort = port;
    if (shouldFail) throw Exception('Serve failed');
    if (!completer.isCompleted) {
      completer.complete(MockIpfsHttpServerInstance());
    }
    return completer.future;
  }
}

class MockBlockStore implements BlockStore {
  @override
  PinManager get pinManager => throw UnimplementedError();

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    return BlockResponseFactory.notFound();
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    return BlockResponseFactory.successAdd('OK');
  }

  @override
  Future<bool> hasBlock(String cid) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GatewayServer', () {
    late MockHttpServerAdapter mockAdapter;
    late MockBlockStore mockBlockStore;
    late MetricsCollector metricsCollector;
    late GatewayServer server;

    setUp(() {
      mockAdapter = MockHttpServerAdapter();
      mockBlockStore = MockBlockStore();
      metricsCollector = MetricsCollector(
        IPFSConfig(
          metrics: const MetricsConfig(
            enabled: true,
            enablePrometheusExport: true,
            collectionIntervalSeconds: 60,
          ),
        ),
      );
      server = GatewayServer(
        blockStore: mockBlockStore,
        httpAdapter: mockAdapter,
        metricsCollector: metricsCollector,
        metricsConfig: const MetricsConfig(
          enabled: true,
          enablePrometheusExport: true,
        ),
        maxRequestsPerIp: 2,
        rateLimitWindowSeconds: 1,
      );
    });

    tearDown(() async {
      try {
        if (server.isRunning) {
          await server.stop();
        }
      } catch (_) {}
      await metricsCollector.stop();
    });

    test('initial state', () {
      expect(server.isRunning, isFalse);
      expect(server.url, contains('not started'));
    });

    test('start and stop success', () async {
      final startFuture = server.start();

      expect(mockAdapter.lastAddress, equals('localhost'));
      expect(mockAdapter.lastPort, equals(8080));

      await startFuture;

      expect(server.isRunning, isTrue);
      expect(server.url, equals('http://localhost:8080'));

      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('cannot start twice', () async {
      mockAdapter.completer.complete(MockIpfsHttpServerInstance());
      await server.start();
      expect(() => server.start(), throwsStateError);
    });

    test('handles start failure', () async {
      mockAdapter.shouldFail = true;
      expect(() => server.start(), throwsA(isException));
      expect(server.isRunning, isFalse);
    });

    test('routing - health check', () async {
      // Get the handler without fully starting the server
      await server.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(await response.readAsString(), equals('OK'));
    });

    test('routing - version endpoint', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v0/version'),
      );
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));
      final body = await response.readAsString();
      expect(body, contains('dart_ipfs'));
    });

    test('CORS middleware - OPTIONS request', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request('OPTIONS', Uri.parse('http://localhost/health'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['Access-Control-Allow-Origin'], isNotNull);
      expect(response.headers['Access-Control-Allow-Methods'], contains('GET'));
    });

    test('CORS middleware - regular request headers', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'], isNotNull);
    });

    test('Rate limiting middleware', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;
      final uri = Uri.parse('http://localhost/health');

      // First request - OK
      var response = await handler(
        Request('GET', uri, headers: {'x-real-ip': '1.2.3.4'}),
      );
      expect(response.statusCode, equals(200));

      // Second request - OK (limit is 2)
      response = await handler(
        Request('GET', uri, headers: {'x-real-ip': '1.2.3.4'}),
      );
      expect(response.statusCode, equals(200));

      // Third request - 429
      response = await handler(
        Request('GET', uri, headers: {'x-real-ip': '1.2.3.4'}),
      );
      expect(response.statusCode, equals(429));
      expect(await response.readAsString(), contains('Rate limit exceeded'));

      // Different IP - OK
      response = await handler(
        Request('GET', uri, headers: {'x-real-ip': '1.2.3.5'}),
      );
      expect(response.statusCode, equals(200));
    });

    test('HEAD request returns headers only', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;

      // Note: /ipfs/ paths will call GatewayHandler which might fail if not mocked properly,
      // but GatewayServer logic should still handle the HEAD wrap.
      // We can use a path that returns 404 or something from handler.

      final request = Request(
        'HEAD',
        Uri.parse(
          'http://localhost/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
        ),
      );
      final response = await handler(request);

      // GatewayHandler will likely return 404 or 500 because BlockStore is not mocked for 'handlePath'.
      // But HEAD logic in GatewayServer should still work.
      expect(response.statusCode, isNotNull);
      // Shelf response body for HEAD might be empty.
      expect(await response.readAsString(), isEmpty);
    });

    test('Rate limiting middleware with X-Forwarded-For', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;
      final uri = Uri.parse('http://localhost/health');

      final response = await handler(
        Request('GET', uri, headers: {'x-forwarded-for': '2.2.2.2, 3.3.3.3'}),
      );
      expect(response.statusCode, equals(200));
      // The rate limiter should have recorded '2.2.2.2'
    });

    test('routing - ipns support', () async {
      final ipnsServer = GatewayServer(
        blockStore: mockBlockStore,
        httpAdapter: mockAdapter,
        ipnsResolver: (name) async =>
            'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      await ipnsServer.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipns/test.eth'),
      );
      final response = await handler(request);
      expect(response.statusCode, isNotNull);
      // The resolver is mocked to return a valid CID, so it should attempt to serve content.
      // Since the blockstore is not mocked for that CID, it may return 404, but the request
      // should not crash.
      await ipnsServer.stop();
    });

    test('routing - /metrics returns Prometheus text when enabled', () async {
      await server.start();
      final handler = mockAdapter.lastHandler!;

      // Make a request so the metrics middleware records something.
      final healthRequest = Request(
        'GET',
        Uri.parse('http://localhost/health'),
      );
      await handler(healthRequest);

      final request = Request('GET', Uri.parse('http://localhost/metrics'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('text/plain'));
      final body = await response.readAsString();
      expect(body, contains('# HELP ipfs_gateway_requests_total'));
      expect(body, contains('ipfs_gateway_requests_total'));
      expect(body, contains('namespace="other"'));
    });

    test('routing - /metrics returns 404 when disabled', () async {
      final disabledServer = GatewayServer(
        blockStore: mockBlockStore,
        httpAdapter: mockAdapter,
        metricsCollector: metricsCollector,
        metricsConfig: const MetricsConfig(
          enabled: false,
          enablePrometheusExport: false,
        ),
      );
      await disabledServer.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request('GET', Uri.parse('http://localhost/metrics'));
      final response = await handler(request);

      expect(response.statusCode, equals(404));
      await disabledServer.stop();
    });
  });
}
