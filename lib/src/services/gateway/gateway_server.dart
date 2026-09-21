// lib/src/services/gateway/gateway_server.dart
import 'dart:convert';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/services/health_check_service.dart';
import 'package:dart_ipfs/src/platform/http_server.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_tls_manager.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_wss_handler.dart';
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
    this.tlsPort = 443,
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
    this.denylistService,
    this.gatewayConfig = const GatewayConfig(),
    HttpServerAdapter? httpAdapter,
    GatewayTlsManager? tlsManager,
  }) : httpAdapter = httpAdapter ?? createHttpServerAdapter(),
       tlsManager = tlsManager ?? GatewayTlsManager(gatewayConfig) {
    _handler = GatewayHandler(
      blockStore,
      ipnsResolver: ipnsResolver,
      ipnsRecordResolver: ipnsRecordResolver,
      metricsCollector: metricsCollector,
      denylistService: denylistService,
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

  /// The TLS port to listen on when TLS is enabled.
  final int tlsPort;

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

  /// Optional denylist service for content blocking.
  final DenylistService? denylistService;

  /// Gateway configuration including subdomain gateway settings.
  final GatewayConfig gatewayConfig;

  /// TLS certificate and AutoTLS manager.
  final GatewayTlsManager tlsManager;

  final _logger = Logger('GatewayServer');

  IpfsHttpServerInstance? _server;
  IpfsHttpServerInstance? _tlsServer;
  IpfsHttpServerInstance? _redirectServer;
  late final GatewayHandler _handler;
  late final Router _router;
  HealthCheckService? _healthCheckService;

  /// Tracks request timestamps per client key for rate limiting.
  ///
  /// Bounded by [_maxTrackedClients]; entries whose timestamps have all
  /// fallen outside the rate-limit window are removed by periodic sweeps
  /// so the map shrinks without requiring [stop].
  final Map<String, List<DateTime>> _requestLog = {};

  /// Maximum number of distinct client keys tracked in [_requestLog].
  ///
  /// Once the cap is reached, the least-recently-active client is evicted
  /// to make room for a new key. This prevents an attacker from growing
  /// the map without bound by forging client identities.
  static const int _maxTrackedClients = 10000;

  /// Number of rate-limited requests between full sweeps of [_requestLog].
  static const int _requestLogSweepInterval = 256;

  int _requestsSinceSweep = 0;

  void _setupRouter() {
    _router = Router();

    // Path-based gateway
    _router.get('/ipfs/<path|.*>', (Request request, String path) async {
      return await _handler.handlePath(request);
    });

    _router.get('/ipns/<path|.*>', (Request request, String path) async {
      return await _handler.handlePath(request);
    });

    // HEAD requests for metadata (GET-equivalent headers, no body)
    _router.head('/ipfs/<path|.*>', (Request request, String path) async {
      final response = await _handler.handlePath(request);
      // Return headers only, no body
      return Response(response.statusCode, headers: response.headers);
    });

    _router.head('/ipns/<path|.*>', (Request request, String path) async {
      final response = await _handler.handlePath(request);
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

    // WebSocket Secure upgrade endpoint (WSS gateway)
    _router.get('/ws', (Request request) async {
      return handleGatewayWebSocket(request, _logger);
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
    final enabled =
        metricsConfig?.enablePrometheusExport == true &&
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
    if (_server != null || _tlsServer != null || _redirectServer != null) {
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
      if (gatewayConfig.enableTls || gatewayConfig.autoTls) {
        final effectiveTlsPort = gatewayConfig.tlsPort > 0
            ? gatewayConfig.tlsPort
            : tlsPort;
        final context = await tlsManager.loadSecurityContext();
        _tlsServer = await httpAdapter.serveSecure(
          handler,
          address,
          effectiveTlsPort,
          context,
        );
        tlsManager.markActive();
        _logger.info(
          'Gateway TLS server listening on https://${_tlsServer!.host}:${_tlsServer!.port}',
        );

        if (gatewayConfig.redirectHttpToHttps) {
          _redirectServer = await httpAdapter.serve(
            _redirectToHttpsHandler(effectiveTlsPort),
            address,
            port,
          );
          _logger.info(
            'HTTP redirect server listening on http://${_redirectServer!.host}:${_redirectServer!.port}',
          );
        } else {
          _server = await httpAdapter.serve(handler, address, port);
          _logger.info(
            'Gateway server listening on http://${_server!.host}:${_server!.port}',
          );
        }
      } else {
        _server = await httpAdapter.serve(handler, address, port);
        _logger.info(
          'Gateway server listening on http://${_server!.host}:${_server!.port}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start gateway server', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the gateway server and any TLS or redirect listeners.
  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    await _tlsServer?.close(force: true);
    _tlsServer = null;
    await _redirectServer?.close(force: true);
    _redirectServer = null;
    tlsManager.markInactive();
    await tlsManager.dispose();
    _requestLog.clear();
    _logger.info('Gateway server stopped');
  }

  /// Rate limiting middleware (SEC-007 security fix)
  ///
  /// Limits requests per client to [maxRequestsPerIp] per
  /// [rateLimitWindowSeconds]. Clients are keyed by their real transport
  /// peer address when available; the log itself is hard-bounded by
  /// [_maxTrackedClients] and periodically swept of expired entries.
  Middleware _rateLimitMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final clientKey = _clientKeyFor(request);

        final now = DateTime.now();
        final windowStart = now.subtract(
          Duration(seconds: rateLimitWindowSeconds),
        );

        // Periodic sweep: drop entries whose timestamps have all expired
        // so the map actually shrinks instead of accumulating empty lists.
        if (++_requestsSinceSweep >= _requestLogSweepInterval) {
          _requestsSinceSweep = 0;
          _sweepRequestLog(windowStart);
        }

        // Prune expired timestamps for this client.
        final recent = (_requestLog.remove(clientKey) ?? const <DateTime>[])
            .where((t) => t.isAfter(windowStart))
            .toList();

        // Check rate limit
        if (recent.length >= maxRequestsPerIp) {
          _requestLog[clientKey] = recent;
          _logger.warning('Rate limit exceeded for $clientKey');
          return Response(
            429,
            body: '{"error": "Rate limit exceeded. Try again later."}',
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': rateLimitWindowSeconds.toString(),
            },
          );
        }

        // Inserting a new key while at capacity: reclaim expired entries
        // first, then evict the least-recently-active client.
        if (recent.isEmpty && _requestLog.length >= _maxTrackedClients) {
          _sweepRequestLog(windowStart);
          if (_requestLog.length >= _maxTrackedClients) {
            _evictOldestClient();
          }
        }

        // Record request
        recent.add(now);
        _requestLog[clientKey] = recent;

        return handler(request);
      };
    };
  }

  /// Returns the rate-limit key for [request].
  ///
  /// Prefers the real transport peer address that `shelf_io` stores under
  /// the `shelf.io.connection_info` context key, accessed via `dynamic`
  /// so this library stays free of `dart:io`. Header-derived identities
  /// (`x-forwarded-for`, `x-real-ip`) are trivially spoofable by the
  /// client, so they are only used as an advisory fallback when no
  /// transport info exists (e.g. unit tests or embedded adapters); in
  /// that case the hard cap on [_requestLog] still prevents unbounded
  /// growth from forged identities.
  String _clientKeyFor(Request request) {
    final info = request.context['shelf.io.connection_info'];
    if (info != null) {
      try {
        final address = (info as dynamic).remoteAddress.address;
        if (address is String && address.isNotEmpty) {
          return address;
        }
      } catch (_) {
        // Fall through to the advisory header fallback.
      }
    }

    final forwarded = request.headers['x-forwarded-for']
        ?.split(',')
        .first
        .trim();
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded;
    }
    final realIp = request.headers['x-real-ip'];
    if (realIp != null && realIp.isNotEmpty) {
      return realIp;
    }
    return 'unknown';
  }

  /// Removes entries from [_requestLog] whose timestamps have all fallen
  /// outside the window starting at [windowStart].
  void _sweepRequestLog(DateTime windowStart) {
    _requestLog.removeWhere((_, timestamps) {
      timestamps.removeWhere((t) => !t.isAfter(windowStart));
      return timestamps.isEmpty;
    });
  }

  /// Evicts the client whose most recent request is the oldest.
  void _evictOldestClient() {
    String? oldestKey;
    DateTime? oldestSeen;
    _requestLog.forEach((key, timestamps) {
      if (timestamps.isEmpty) return;
      final last = timestamps.last;
      if (oldestSeen == null || last.isBefore(oldestSeen!)) {
        oldestSeen = last;
        oldestKey = key;
      }
    });
    if (oldestKey != null) {
      _requestLog.remove(oldestKey);
    }
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

  /// Returns true if the TLS listener is active and a certificate is loaded.
  Future<bool> isTlsActive() async =>
      _tlsServer != null && tlsManager.isActive && tlsManager.isContextLoaded;

  /// Returns the not-after expiry of the loaded TLS certificate, if known.
  Future<DateTime?> certificateExpiry() async => tlsManager.certificateExpiry;

  /// Returns true if the server is running
  bool get isRunning =>
      _server != null || _tlsServer != null || _redirectServer != null;

  /// Returns the server URL.
  ///
  /// Prefer HTTPS when the TLS listener is active.
  String get url {
    if (_tlsServer != null) {
      return 'https://${_tlsServer!.host}:${_tlsServer!.port}';
    }
    if (_server != null) {
      return 'http://${_server!.host}:${_server!.port}';
    }
    return 'http://$address:$port (not started)';
  }

  /// Handler that redirects every request to the HTTPS listener.
  Handler _redirectToHttpsHandler(int targetTlsPort) {
    return (Request request) {
      final host = request.headers['host'] ?? request.url.host;
      final domain = host.contains(':') ? host.split(':').first : host;
      final location =
          'https://$domain${targetTlsPort == 443 ? '' : ':$targetTlsPort'}/${request.url}';
      _logger.info('Redirecting HTTP request to HTTPS: $location');
      return Response.movedPermanently(location);
    };
  }
}
