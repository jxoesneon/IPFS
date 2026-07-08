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

  /// Starts serving with the given handler over TLS at the specified address
  /// and port using the provided [context].
  ///
  /// The [context] is typed as [Object] to keep the platform adapter abstract
  /// and avoid importing `dart:io` on web platforms. IO implementations are
  /// expected to receive a [SecurityContext] instance.
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    Object context,
  );
}
