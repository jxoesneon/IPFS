// lib/src/services/gateway/gateway_server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// IPFS HTTP Gateway Server
///
/// Provides standard IPFS Gateway endpoints for accessing content via HTTP.
/// Compliant with IPFS Gateway specifications.
class GatewayServer {
  final BlockStore blockStore;
  final String address;
  final int port;
  final List<String> corsOrigins;
  final IpnsResolver? ipnsResolver;
  final _logger = Logger('GatewayServer');

  HttpServer? _server;
  late final GatewayHandler _handler;
  late final Router _router;

  GatewayServer({
    required this.blockStore,
    this.address = 'localhost',
    this.port = 8080,
    this.corsOrigins = const ['*'],
    this.ipnsResolver,
  }) {
    _handler = GatewayHandler(blockStore, ipnsResolver: ipnsResolver);
    _setupRouter();
  }

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
      return Response(
        response.statusCode,
        headers: response.headers,
      );
    });

    // Version endpoint
    _router.get('/api/v0/version', (Request request) {
      return Response.ok(
        '{"Version":"dart_ipfs/0.1.0","Commit":"phase3","Repo":"1"}',
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Health check
    _router.get('/health', (Request request) {
      return Response.ok('OK');
    });
  }

  /// Starts the gateway server
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server is already running');
    }

    // Build middleware pipeline
    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(_router);

    try {
      _server = await shelf_io.serve(
        handler,
        address,
        port,
      );
      _logger.info(
          'Gateway server listening on http://${_server!.address.host}:${_server!.port}');
    } catch (e, stackTrace) {
      _logger.error('Failed to start gateway server', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the gateway server
  Future<void> stop() async {
    if (_server == null) {
      return;
    }

    await _server!.close(force: true);
    _server = null;
    _logger.info('Gateway server stopped');
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // Handle preflight OPTIONS request
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }

        // Process request and add CORS headers to response
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
      'Access-Control-Allow-Headers': 'Content-Type, Range',
      'Access-Control-Expose-Headers':
          'Content-Range, X-IPFS-Path, X-IPFS-Roots',
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

        _logger.info(
            '[${request.method}] ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)');

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
