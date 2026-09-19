import 'dart:async';
import 'dart:io';
import 'dart:mirrors' as mirrors;

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

/// Mimics the `HttpConnectionInfo` value `shelf_io` stores under the
/// `shelf.io.connection_info` request-context key; the production code
/// reads `remoteAddress.address` through `dynamic` so no shared interface
/// is required.
class _FakeConnectionInfo {
  _FakeConnectionInfo(String address)
    : remoteAddress = _FakeRemoteAddress(address);
  final _FakeRemoteAddress remoteAddress;
}

class _FakeRemoteAddress {
  _FakeRemoteAddress(this.address);
  final String address;
}

class MockHttpServerAdapter implements HttpServerAdapter {
  Handler? lastHandler;
  String? lastAddress;
  int? lastPort;
  Handler? lastSecureHandler;
  String? lastSecureAddress;
  int? lastSecurePort;
  SecurityContext? lastSecureContext;
  Completer<IpfsHttpServerInstance> completer = Completer();
  Completer<IpfsHttpServerInstance> secureCompleter = Completer();
  bool shouldFail = false;
  bool shouldFailSecure = false;

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

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    covariant SecurityContext context,
  ) async {
    lastSecureHandler = handler;
    lastSecureAddress = address;
    lastSecurePort = port;
    lastSecureContext = context;
    if (shouldFailSecure) throw Exception('Secure serve failed');
    if (!secureCompleter.isCompleted) {
      secureCompleter.complete(MockIpfsHttpServerInstance());
    }
    return secureCompleter.future;
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

    test(
      'Rate limiting keys on the transport connection info when present',
      () async {
        await server.start();
        final handler = mockAdapter.lastHandler!;
        final uri = Uri.parse('http://localhost/health');

        // shelf_io stores the real transport peer under this context key.
        // Forged headers must not change the rate-limit identity: three
        // requests from the same connection info with different spoofed
        // headers still hit the limit of 2.
        for (var i = 0; i < 2; i++) {
          final response = await handler(
            Request(
              'GET',
              uri,
              headers: {'x-forwarded-for': '198.51.100.$i'},
              context: {
                'shelf.io.connection_info': _FakeConnectionInfo('203.0.113.9'),
              },
            ),
          );
          expect(response.statusCode, equals(200));
        }
        final limited = await handler(
          Request(
            'GET',
            uri,
            headers: {'x-forwarded-for': '198.51.100.99'},
            context: {
              'shelf.io.connection_info': _FakeConnectionInfo('203.0.113.9'),
            },
          ),
        );
        expect(limited.statusCode, equals(429));
      },
    );

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

    test(
      'rate limiter sweeps expired entries on the periodic interval',
      () async {
        await server.start();
        final handler = mockAdapter.lastHandler!;

        final mirror = mirrors.reflect(server);
        Symbol sym(String name) => mirror.type.declarations.keys.firstWhere(
          (s) => mirrors.MirrorSystem.getName(s) == name,
        );
        final log =
            mirror.getField(sym('_requestLog')).reflectee
                as Map<String, List<DateTime>>;
        // A client whose only timestamps are outside the 1s window.
        log['10.9.9.9'] = [DateTime.now().subtract(const Duration(days: 1))];
        // Next request trips the sweep interval.
        mirror.setField(sym('_requestsSinceSweep'), 255);

        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/health'),
            headers: {'x-real-ip': '9.9.9.9'},
          ),
        );
        expect(response.statusCode, equals(200));
        // The sweep removed the fully-expired entry.
        expect(log.containsKey('10.9.9.9'), isFalse);
      },
    );

    test('rate limiter evicts the oldest client at capacity', () async {
      final capped = GatewayServer(
        blockStore: mockBlockStore,
        httpAdapter: mockAdapter,
        metricsCollector: metricsCollector,
        // A long window keeps seeded timestamps "live" through the sweep.
        rateLimitWindowSeconds: 3600,
      );
      await capped.start();
      final handler = mockAdapter.lastHandler!;
      try {
        final mirror = mirrors.reflect(capped);
        final logSym = mirror.type.declarations.keys.firstWhere(
          (s) => mirrors.MirrorSystem.getName(s) == '_requestLog',
        );
        final log =
            mirror.getField(logSym).reflectee as Map<String, List<DateTime>>;
        // Fill the 10000-client cap with live entries; the oldest is the
        // eviction candidate.
        final now = DateTime.now();
        for (var i = 0; i < 10000; i++) {
          log['10.${i ~/ 65536}.${(i ~/ 256) % 256}.${i % 256}'] = [
            now.subtract(Duration(milliseconds: i == 0 ? 500 : i % 400)),
          ];
        }

        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/health'),
            headers: {'x-real-ip': '192.0.2.1'},
          ),
        );
        expect(response.statusCode, equals(200));
        // The oldest client (index 0, 500 ms old) was evicted to make room.
        expect(log.containsKey('10.0.0.0'), isFalse);
        expect(log.containsKey('192.0.2.1'), isTrue);

        // The empty-timestamps skip inside _evictOldestClient is only
        // reachable directly: the request path always sweeps empty lists
        // away first.
        log['empty'] = <DateTime>[];
        log['older'] = [now.subtract(const Duration(minutes: 1))];
        final evictSym = mirror.type.declarations.keys.firstWhere(
          (s) => mirrors.MirrorSystem.getName(s) == '_evictOldestClient',
        );
        mirror.invoke(evictSym, const []);
        expect(log.containsKey('older'), isFalse);
        expect(log.containsKey('empty'), isTrue);
      } finally {
        await capped.stop();
      }
    });
  });
}
