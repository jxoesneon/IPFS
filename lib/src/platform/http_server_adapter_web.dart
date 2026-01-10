import 'package:shelf/shelf.dart';

import 'http_server_adapter.dart';

/// Web stub implementation of HTTP server instance.
class IpfsHttpServerInstanceWeb implements IpfsHttpServerInstance {
  /// Creates an instance with the given address and port.
  IpfsHttpServerInstanceWeb(this._address, this._port);

  final String _address;
  final int _port;

  @override
  Future<void> close({bool force = false}) async {
    // No-op on web
  }

  @override
  String get host => _address;

  @override
  int get port => _port;
}

/// Web stub implementation of HTTP server adapter.
class HttpServerAdapterWeb implements HttpServerAdapter {
  @override
  Future<IpfsHttpServerInstance> serve(Handler handler, String address, int port) async {
    // On web, we generally cannot bind a TCP port.
    // This is a stub that mainly allows compilation.
    return IpfsHttpServerInstanceWeb(address, port);
  }
}

/// Factory for conditional imports.
HttpServerAdapter createHttpServerAdapter() => HttpServerAdapterWeb();
