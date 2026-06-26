import 'dart:ffi';
import 'dart:typed_data';

import '../generated/quiche_bindings.dart' as q;

/// Minimal wrapper around a quiche connection.
class QuicheConnection {
  final Pointer<q.quiche_conn> _conn;

  QuicheConnection._(this._conn);

  /// Wraps an existing quiche connection pointer.
  factory QuicheConnection.fromPointer(Pointer<q.quiche_conn> conn) {
    if (conn.address == 0) {
      throw ArgumentError('Null quiche connection pointer');
    }
    return QuicheConnection._(conn);
  }

  /// True if the handshake has completed.
  bool get isEstablished => q.quiche_conn_is_established(_conn);

  /// True if the connection has been closed.
  bool get isClosed => q.quiche_conn_is_closed(_conn);

  /// Feeds an incoming UDP packet into the connection.
  int recv(List<int> data) => q.quiche_conn_recv(_conn, data);

  /// Generates an outgoing UDP packet if the connection has data to send.
  (int, List<int>) send(int maxLen) => q.quiche_conn_send(_conn, maxLen);

  /// Sends data on a bidirectional stream.
  int streamSend(int streamId, List<int> data, bool fin) =>
      q.quiche_conn_stream_send(_conn, streamId, data, fin);

  /// Receives data from a stream.
  (int, Uint8List, bool) streamRecv(int streamId, int maxLen) {
    final (read, bytes, fin) =
        q.quiche_conn_stream_recv(_conn, streamId, maxLen);
    return (read, Uint8List.fromList(bytes), fin);
  }

  /// Shuts down a stream direction.
  int streamShutdown(int streamId, int direction) =>
      q.quiche_conn_stream_shutdown(_conn, streamId, direction);

  /// Closes the connection with the given error code and reason.
  void close(bool app, int error, String reason) =>
      q.quiche_conn_close(_conn, app, error, reason);

  /// Releases the native connection object.
  void dispose() {
    q.quiche_conn_free(_conn);
  }
}
