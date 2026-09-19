import 'package:shelf/shelf.dart';

import 'http_server_adapter.dart';

/// Fallback [HttpServerAdapter] for platforms with no HTTP server backend
/// (neither `dart:io` sockets nor a browser runtime).
///
/// Every method throws [UnsupportedError] naming the missing capability so
/// callers can distinguish "platform cannot do this" from a real
/// implementation gap.
class HttpServerAdapterStub implements HttpServerAdapter {
  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    throw UnsupportedError(
      'HTTP server binding is not supported on this platform '
      '(no dart:io socket support and no web runtime)',
    );
  }

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    Object context,
  ) async {
    throw UnsupportedError(
      'HTTPS server binding is not supported on this platform '
      '(no dart:io socket support and no web runtime)',
    );
  }
}

/// Factory for conditional imports.
HttpServerAdapter createHttpServerAdapter() => HttpServerAdapterStub();
