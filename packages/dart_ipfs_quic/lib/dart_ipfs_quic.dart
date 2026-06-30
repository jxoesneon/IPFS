/// Pure-Dart QUIC transport for dart_ipfs backed by the [quic_lib] package.
///
/// This package provides a libp2p-compatible [Transport] implementation that
/// can be registered with [Libp2pRouter] when `enableQuic` is true. It avoids
/// native FFI dependencies by using the pure-Dart QUIC stack in [quic_lib].
///
/// Exported symbols:
/// - [QuicTransport] — implements `package:ipfs_libp2p`'s [Transport] interface.
/// - [QuicConnection] — wraps a [quic_lib] libp2p QUIC connection.
/// - [QuicListener] — accepts incoming QUIC connections.
library;

export 'src/quic_transport.dart' show QuicTransport, QuicConnection;
export 'src/quic_listener.dart' show QuicListener;
export 'src/quic_p2p_stream.dart' show QuicP2PStream;
