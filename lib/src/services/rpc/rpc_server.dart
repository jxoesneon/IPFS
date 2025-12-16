// lib/src/services/rpc/rpc_server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// IPFS HTTP RPC API Server
///
/// Provides Kubo-compatible RPC API for programmatic control.
/// See: https://docs.ipfs.tech/reference/kubo/rpc/
///
/// **Security (SEC-003):** When [apiKey] is provided, all write operations
/// require the `X-API-Key` header to match. Read-only operations like
/// `version`, `id`, and `cat` are allowed without authentication.
class RPCServer {
  final IPFSNode node;
  final String address;
  final int port;
  final List<String> corsOrigins;

  /// Optional API key for authentication.
  /// When set, write operations require `X-API-Key` header.
  final String? apiKey;

  final _logger = Logger('RPCServer');
  HttpServer? _server;
  late final RPCHandlers _handlers;
  late final Router _router;

  /// Read-only endpoints that don't require authentication
  static const _publicEndpoints = {
    '/api/v0/version',
    '/api/v0/id',
    '/api/v0/cat',
    '/api/v0/get',
    '/api/v0/ls',
    '/api/v0/dag/get',
    '/api/v0/block/get',
    '/api/v0/block/stat',
    '/api/v0/name/resolve',
    '/api/v0/swarm/peers',
    '/api/v0/dht/findprovs',
    '/api/v0/dht/findpeer',
  };

  RPCServer({
    required this.node,
    this.address = 'localhost',
    this.port = 5001,
    this.corsOrigins = const [
      'http://localhost',
      'http://127.0.0.1',
    ], // SEC-006: Restrict CORS
    this.apiKey,
  }) {
    _handlers = RPCHandlers(node);
    _setupRouter();
    if (apiKey != null) {
      _logger.info('RPC server configured with API key authentication');
    } else {
      _logger.warning(
        'RPC server running WITHOUT authentication - set apiKey for production!',
      );
    }
  }

  void _setupRouter() {
    _router = Router();

    // Core endpoints
    _router.post('/api/v0/version', _handlers.handleVersion);
    _router.post('/api/v0/id', _handlers.handleId);

    // Content endpoints
    _router.post('/api/v0/add', _handlers.handleAdd);
    _router.post('/api/v0/cat', _handlers.handleCat);
    _router.post('/api/v0/get', _handlers.handleGet);
    _router.post('/api/v0/ls', _handlers.handleLs);

    // DAG endpoints
    _router.post('/api/v0/dag/get', _handlers.handleDagGet);
    _router.post('/api/v0/dag/put', _handlers.handleDagPut);

    // DHT endpoints
    _router.post('/api/v0/dht/findprovs', _handlers.handleDhtFindProviders);
    _router.post('/api/v0/dht/findpeer', _handlers.handleDhtFindPeer);
    _router.post('/api/v0/dht/provide', _handlers.handleDhtProvide);

    // Name (IPNS) endpoints
    _router.post('/api/v0/name/publish', _handlers.handleNamePublish);
    _router.post('/api/v0/name/resolve', _handlers.handleNameResolve);

    // Swarm endpoints
    _router.post('/api/v0/swarm/peers', _handlers.handleSwarmPeers);
    _router.post('/api/v0/swarm/connect', _handlers.handleSwarmConnect);
    _router.post('/api/v0/swarm/disconnect', _handlers.handleSwarmDisconnect);

    // Block endpoints
    _router.post('/api/v0/block/get', _handlers.handleBlockGet);
    _router.post('/api/v0/block/put', _handlers.handleBlockPut);
    _router.post('/api/v0/block/stat', _handlers.handleBlockStat);
  }

  /// Starts the RPC server
  Future<void> start() async {
    if (_server != null) {
      throw StateError('RPC server is already running');
    }

    // Build middleware pipeline with authentication (SEC-003)
    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(_router.call);

    try {
      _server = await shelf_io.serve(handler, address, port);
      _logger.info(
        'RPC server listening on http://${_server!.address.host}:${_server!.port}',
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to start RPC server', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the RPC server
  Future<void> stop() async {
    if (_server == null) {
      return;
    }

    await _server!.close(force: true);
    _server = null;
    _logger.info('RPC server stopped');
  }

  /// Authentication middleware (SEC-003 security fix)
  ///
  /// When [apiKey] is set, requires X-API-Key header for write operations.
  /// Public/read-only endpoints in [_publicEndpoints] are allowed without auth.
  Middleware _authMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // Skip auth if no API key configured
        if (apiKey == null) {
          return handler(request);
        }

        // Allow public endpoints without auth
        final path = '/${request.url.path}';
        if (_publicEndpoints.contains(path)) {
          return handler(request);
        }

        // Check API key for protected endpoints
        // SEC-009: Use constant-time comparison to prevent timing attacks
        final providedKey = request.headers['x-api-key'] ?? '';
        if (!_constantTimeEquals(providedKey, apiKey!)) {
          _logger.warning(
            'Unauthorized RPC request to $path from ${request.headers['x-forwarded-for'] ?? 'unknown'}',
          );
          return Response.forbidden(
            '{"error": "Unauthorized: Invalid or missing API key"}',
            headers: {'Content-Type': 'application/json'},
          );
        }

        return handler(request);
      };
    };
  }

  /// Constant-time string comparison to prevent timing attacks (SEC-009).
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      // Still compare to use constant time even if lengths differ
      // Use dummy comparison to equalize timing
      var dummy = 0;
      for (var i = 0; i < a.length; i++) {
        dummy |= a.codeUnitAt(i) ^ (i < b.length ? b.codeUnitAt(i) : 0);
      }
      assert(dummy >= 0); // Prevent optimizer from removing
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  /// CORS headers
  Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Origin': corsOrigins.join(','),
      'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
      'Access-Control-Max-Age': '86400',
    };
  }

  /// Logging middleware
  Middleware _loggingMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final start = DateTime.now();
        final response = await handler(request);
        final duration = DateTime.now().difference(start);

        _logger.verbose(
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
      ? 'http://${_server!.address.host}:${_server!.port}'
      : 'http://$address:$port (not started)';
}
