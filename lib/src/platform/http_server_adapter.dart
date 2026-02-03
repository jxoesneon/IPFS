import 'package:shelf/shelf.dart';

/// Abstract interface for a running HTTP server instance.
abstract class IpfsHttpServerInstance {
  /// Closes the server.
  Future<void> close({bool force = false});

  /// Returns the host address.
  String get host;

  /// Returns the port number.
  int get port;
}

/// Abstract interface for starting an HTTP server.
abstract class HttpServerAdapter {
  /// Starts serving with the given handler at the specified address and port.
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  );
}

