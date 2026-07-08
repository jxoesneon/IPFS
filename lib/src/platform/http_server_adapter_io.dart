import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'http_server_adapter.dart';

/// IO implementation of HTTP server instance.
class IpfsHttpServerInstanceIO implements IpfsHttpServerInstance {
  /// Creates an instance wrapping an HttpServer.
  IpfsHttpServerInstanceIO(this._server);

  final HttpServer _server;

  @override
  Future<void> close({bool force = false}) async {
    await _server.close(force: force);
  }

  @override
  String get host => _server.address.host;

  @override
  int get port => _server.port;
}

/// IO implementation of HTTP server adapter.
class HttpServerAdapterIO implements HttpServerAdapter {
  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    final server = await HttpServer.bind(address, port);
    shelf_io.serveRequests(server, handler);
    return IpfsHttpServerInstanceIO(server);
  }

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    covariant SecurityContext context,
  ) async {
    final server = await HttpServer.bindSecure(address, port, context);
    shelf_io.serveRequests(server, handler);
    return IpfsHttpServerInstanceIO(server);
  }
}

/// Factory for conditional imports.
HttpServerAdapter createHttpServerAdapter() => HttpServerAdapterIO();
