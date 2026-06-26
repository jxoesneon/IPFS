// lib/src/services/gateway/gateway_server.dart
import 'dart:convert';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/services/health_check_service.dart';
import 'package:dart_ipfs/src/platform/http_server.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/version.dart';
import 'package:prometheus_client/format.dart' as format;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// IPFS HTTP Gateway Server
///
/// Provides standard IPFS Gateway endpoints for accessing content via HTTP.
/// Compliant with IPFS Gateway specifications.
///
/// **Security (SEC-007):** Rate limiting is enabled by default to prevent DoS.
class GatewayServer implements ILifecycle {
  /// Creates a new [GatewayServer] with the given configuration.
  GatewayServer({
    required this.blockStore,
    this.node,
    this.address = 'localhost',
    this.port = 8080,
    this.corsOrigins = const [
      'http://localhost',
      'http://127.0.0.1',
    ], // SEC-006: Restrict CORS
    this.ipnsResolver,
    this.ipnsRecordResolver,
    this.maxRequestsPerIp = 100,
    this.rateLimitWindowSeconds = 60,
    this.metricsCollector,
    this.metricsConfig,
    this.gatewayConfig = const GatewayConfig(),
    HttpServerAdapter? httpAdapter,
  }) : httpAdapter = httpAdapter ?? createHttpServerAdapter() {
    _handler = GatewayHandler(
      blockStore,
      ipnsResolver: ipnsResolver,
      ipnsRecordResolver: ipnsRecordResolver,
      metricsCollector: metricsCollector,
      gatewayDomain: gatewayConfig.gatewayDomain,
      enableSubdomainGateway: gatewayConfig.enableSubdomainGateway,
      subdomainDNSLinkResolver: gatewayConfig.subdomainDNSLinkResolver,
      subdomainTLSRedirect: gatewayConfig.subdomainTLSRedirect,
    );
    if (node != null) {
      _healthCheckService = HealthCheckService(node!);
    }
    _setupRouter();
  }

  /// The block store used for content retrieval.
  final BlockStore blockStore;

  /// The IPFS node (optional, for health checks).
  final IPFSNode? node;

  /// The adapter for starting the HTTP server.
  final HttpServerAdapter httpAdapter;

  /// The address to listen on.
  final String address;

  /// The port to listen on.
  final int port;

  /// List of allowed CORS origins.
  final List<String> corsOrigins;

  /// Optional IPNS resolver for /ipns/ paths.
  final IpnsResolver? ipnsResolver;

  /// Optional resolver for signed IPNS record bytes.
  final IpnsRecordResolver? ipnsRecordResolver;

  /// Maximum requests per IP per time window (SEC-007)
  final int maxRequestsPerIp;

  /// Time window for rate limiting in seconds
  final int rateLimitWindowSeconds;

  /// Optional metrics collector for gateway instrumentation.
  final MetricsCollector? metricsCollector;

  /// Optional metrics configuration controlling the Prometheus endpoint.
  final MetricsConfig? metricsConfig;

  /// Gateway configuration including subdomain gateway settings.
  final GatewayConfig gatewayConfig;

  final _logger = Logger('GatewayServer');

  IpfsHttpServerInstance? _server;
  late final GatewayHandler _handler;
  late final Router _router;
  HealthCheckService? _healthCheckService;

  /// Tracks request counts per IP for rate limiting
  final Map<String, List<DateTime>> _requestLog = {};

  void _setupRouter() {
    _router = Router();

    // Path-based gateway
    _router.get('/ipfs/<path|.*>', (Request request, String path) async {
      return await _handler.handlePath(request);
    });

    _router.get('/ipns/<path|.*>', (Request request, String path) async {
      return await _handler.handlePath(request);
    });

    // HEAD requests for metadata
    _router.head('/ipfs/<path|.*>', (Request request, String path) async {
      final response = await _handler.handlePath(request);
      // Return headers only, no body
      return Response(response.statusCode, headers: response.headers);
    });

    // Version endpoint
    _router.get('/api/v0/version', (Request request) {
      return Response.ok(
        jsonEncode({
          'Version': agentVersion,
          'Commit': 'phase3',
          'Repo': repoVersion,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Health check
    _router.get('/health', (Request request) async {
      if (_healthCheckService != null) {
        final status = await _healthCheckService!.checkHealth();
        return Response.ok(
          jsonEncode(status),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return Response.ok('OK');
    });

    _setupMetricsRoute();
  }

  void _setupMetricsRoute() {
    final endpoint = metricsConfig?.prometheusEndpoint ?? '/metrics';
    final enabled = metricsConfig?.enablePrometheusExport == true &&
        metricsCollector != null;

    if (enabled) {
      _router.get(endpoint, (Request request) async {
        final metrics = await metricsCollector!.getPrometheusMetrics();
        return Response.ok(
          metrics,
          headers: {'Content-Type': format.contentType},
        );
      });
    } else {
      _router.get('/metrics', (Request request) {
        return Response.notFound('Metrics endpoint disabled');
      });
    }
  }

  /// Starts the gateway server.
  @override
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server is already running');
    }

    // Build middleware pipeline with rate limiting (SEC-007)
    final handler = const Pipeline()
        .addMiddleware(_subdomainMiddleware())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_rateLimitMiddleware())
        .addMiddleware(_metricsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(_router.call);

    try {
      _server = await httpAdapter.serve(handler, address, port);
      _logger.info(
        'Gateway server listening on http://${_server!.host}:${_server!.port}',
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to start gateway server', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the gateway server.
  @override
  Future<void> stop() async {
    if (_server == null) {
      return;
    }

    await _server!.close(force: true);
    _server = null;
    _requestLog.clear();
    _logger.info('Gateway server stopped');
  }

  /// Rate limiting middleware (SEC-007 security fix)
  ///
  /// Limits requests per IP to [maxRequestsPerIp] per [rateLimitWindowSeconds].
  Middleware _rateLimitMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // Extract client IP
        final clientIp = request.headers['x-forwarded-for']?.split(',').first ??
            request.headers['x-real-ip'] ??
            'unknown';

        final now = DateTime.now();
        final windowStart = now.subtract(
          Duration(seconds: rateLimitWindowSeconds),
        );

        // Clean old entries and get recent requests
        _requestLog[clientIp] = (_requestLog[clientIp] ?? [])
            .where((t) => t.isAfter(windowStart))
            .toList();

        // Check rate limit
        if (_requestLog[clientIp]!.length >= maxRequestsPerIp) {
          _logger.warning('Rate limit exceeded for $clientIp');
          return Response(
            429,
            body: '{"error": "Rate limit exceeded. Try again later."}',
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': rateLimitWindowSeconds.toString(),
            },
          );
        }

        // Record request
        _requestLog[clientIp]!.add(now);

        return handler(request);
      };
    };
  }

  /// Subdomain gateway middleware.
  ///
  /// Intercepts requests addressed to `*.ipfs.{gatewayDomain}` or
  /// `*.ipns.{gatewayDomain}` before they reach the path-gateway router.
  Middleware _subdomainMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (_handler.isSubdomainRequest(request)) {
          return _handler.handleSubdomain(request);
        }
        return handler(request);
      };
    };
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final isSubdomain = _handler.isSubdomainRequest(request);
        final headers = _corsHeaders(isSubdomain: isSubdomain);

        // Handle preflight OPTIONS request
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: headers);
        }

        // Process request and add CORS headers to response
        final response = await handler(request);
        return response.change(headers: headers);
      };
    };
  }

  /// CORS headers
  Map<String, String> _corsHeaders({bool isSubdomain = false}) {
    // Subdomain origins use a public wildcard; path-gateway origins keep the
    // configured allow-list (SEC-006).
    final origin = isSubdomain ? '*' : corsOrigins.join(',');
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Range',
      'Access-Control-Expose-Headers':
          'Content-Range, X-IPFS-Path, X-IPFS-Roots, X-IPFS-DNSLink',
      'Access-Control-Max-Age': '86400',
    };
  }

  /// Metrics instrumentation middleware.
  ///
  /// Records every gateway request with namespace, HTTP method, status code,
  /// and duration.
  Middleware _metricsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final start = DateTime.now();
        final response = await handler(request);
        final duration = DateTime.now().difference(start);

        final namespace = _namespaceFor(request.url.path);
        metricsCollector?.recordGatewayRequest(
          namespace,
          request.method,
          response.statusCode,
          duration,
        );

        return response;
      };
    };
  }

  /// Maps a request path to a gateway namespace for metrics.
  static String _namespaceFor(String path) {
    if (path.startsWith('ipfs/')) return 'ipfs';
    if (path.startsWith('ipns/')) return 'ipns';
    if (path.startsWith('api/')) return 'api';
    return 'other';
  }

  /// Logging middleware
  Middleware _loggingMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final start = DateTime.now();
        final response = await handler(request);
        final duration = DateTime.now().difference(start);

        _logger.info(
          '[${request.method}] ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)',
        );

        return response;
      };
    };
  }

  /// Returns true if the server is running
  bool get isRunning => _server != null;

  /// Returns the server URL
  String get url => _server != null
      ? 'http://${_server!.host}:${_server!.port}'
      : 'http://$address:$port (not started)';
}
