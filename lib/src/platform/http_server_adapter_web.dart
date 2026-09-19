import 'package:shelf/shelf.dart';

import 'http_server_adapter.dart';

/// Web implementation of [HttpServerAdapter].
///
/// Browsers cannot bind TCP or TLS listening sockets, so both [serve] and
/// [serveSecure] throw [UnsupportedError] rather than silently pretending
/// to host a server. HTTP *clients* (gateways, RPC consumers) work on the
/// web through `package:http`; only server-side binding is unsupported.
class HttpServerAdapterWeb implements HttpServerAdapter {
  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    throw UnsupportedError(
      'Cannot bind an HTTP server on the web platform: '
      'browsers do not allow listening TCP sockets. '
      'Run the gateway/RPC server on a native platform instead.',
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
      'Cannot bind an HTTPS server on the web platform: '
      'browsers do not allow listening TCP/TLS sockets. '
      'Run the gateway/RPC server on a native platform instead.',
    );
  }
}

/// Factory for conditional imports.
HttpServerAdapter createHttpServerAdapter() => HttpServerAdapterWeb();
