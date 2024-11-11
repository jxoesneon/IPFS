import 'dart:io';
import 'gateway_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../../core/data_structures/blockstore.dart';

/// IPFS Gateway server that handles HTTP requests following the IPFS Gateway specs
class GatewayServer {
  final String host;
  final int port;
  final BlockStore blockStore;
  final GatewayHandler _handler;
  HttpServer? _server;

  GatewayServer({
    this.host = 'localhost',
    this.port = 8080,
    required this.blockStore,
  }) : _handler = GatewayHandler(blockStore);

  /// Starts the gateway server
  Future<void> start() async {
    final app = Router();

    // Path-based gateway routes
    app.get('/ipfs/<cid>/**', _handleIpfsRequest);
    app.get('/ipns/<name>/**', _handleIpnsRequest);

    // Subdomain gateway route
    app.get('/**', _handleSubdomainRequest);

    // Trustless gateway route
    app.get('/trustless/ipfs', _handleTrustlessRequest);

    // Create a handler pipeline
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(app);

    // Start the server
    _server = await shelf_io.serve(handler, host, port);
    print('IPFS Gateway server running on http://$host:$port/');
  }

  /// Stops the gateway server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Handles IPFS path-based requests
  Future<Response> _handleIpfsRequest(Request request, String cid) async {
    return _handler.handlePath(request);
  }

  /// Handles IPNS path-based requests
  Future<Response> _handleIpnsRequest(Request request, String name) async {
    try {
      // Get the IPNS record from the handler
      final ipnsRecord = await _handler.handleIPNS(request);
      if (ipnsRecord != null) {
        return ipnsRecord;
      }

      // If no record is found, return a 404
      return Response.notFound('IPNS name not found');
    } catch (e) {
      return Response.internalServerError(
          body: 'Error resolving IPNS name: $e');
    }
  }

  /// Handles subdomain-based requests
  Future<Response> _handleSubdomainRequest(Request request) async {
    return _handler.handleSubdomain(request);
  }

  /// Handles trustless gateway requests
  Future<Response> _handleTrustlessRequest(Request request) async {
    return _handler.handleTrustless(request);
  }

  /// CORS middleware for handling cross-origin requests
  Middleware _corsMiddleware() {
    return createMiddleware(
      requestHandler: (request) => null,
      responseHandler: (response) {
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'X-IPFS-Path, X-IPFS-Roots',
          'Access-Control-Expose-Headers': 'X-IPFS-Path, X-IPFS-Roots',
        });
      },
    );
  }
}
