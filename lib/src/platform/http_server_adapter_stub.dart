import 'package:shelf/shelf.dart';

import 'http_server_adapter.dart';

/// Stub implementation of HTTP server adapter for unsupported platforms.
class HttpServerAdapterStub implements HttpServerAdapter {
  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    throw UnimplementedError(
      'HttpServerAdapter not implemented for this platform',
    );
  }

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    Object context,
  ) async {
    throw UnimplementedError(
      'HttpServerAdapter not implemented for this platform',
    );
  }
}

/// Factory for conditional imports.
HttpServerAdapter createHttpServerAdapter() => HttpServerAdapterStub();
