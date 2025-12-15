// lib/src/services/rpc/rpc_server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';

/// IPFS HTTP RPC API Server
///
/// Provides Kubo-compatible RPC API for programmatic control.
/// See: https://docs.ipfs.tech/reference/kubo/rpc/
class RPCServer {
  final IPFSNode node;
  final String address;
  final int port;
  final List<String> corsOrigins;

  HttpServer? _server;
  late final RPCHandlers _handlers;
  late final Router _router;

  RPCServer({
    required this.node,
    this.address = 'localhost',
    this.port = 5001,
    this.corsOrigins = const ['*'],
  }) {
    _handlers = RPCHandlers(node);
    _setupRouter();
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

    // Build middleware pipeline
    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(_router);

    try {
      _server = await shelf_io.serve(handler, address, port);
      print(
        '✅ RPC server listening on http://${_server!.address.host}:${_server!.port}',
      );
    } catch (e) {
      print('❌ Failed to start RPC server: $e');
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
    print('RPC server stopped');
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
      'Access-Control-Allow-Headers': 'Content-Type',
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

        print(
          '[RPC ${request.method}] ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)',
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
