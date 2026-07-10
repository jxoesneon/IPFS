/// Web stub for the public QUIC types exported from `dart_ipfs`.
///
/// The real `dart_ipfs_quic` package depends on `quic_lib`, which uses
/// `Int64` literals that cannot be compiled to JavaScript. On the web we
/// expose these symbols as stubs so that importing `package:dart_ipfs/dart_ipfs.dart`
/// does not pull the native QUIC stack into the dart2js bundle.
library;

/// Stub [QuicTransport] for web builds.
class QuicTransport {
  /// Creates a stub [QuicTransport] that throws on the web.
  QuicTransport() {
    throw UnsupportedError(
      'QUIC transport is not available on the web. '
      'Use TCP, WebRTC, or WebTransport transports instead.',
    );
  }
}

/// Stub [QuicConnection] for web builds.
class QuicConnection {
  /// Creates a stub [QuicConnection] that throws on the web.
  QuicConnection() {
    throw UnsupportedError('QuicConnection is not available on the web.');
  }
}

/// Stub [QuicListener] for web builds.
class QuicListener {
  /// Creates a stub [QuicListener] that throws on the web.
  QuicListener() {
    throw UnsupportedError('QuicListener is not available on the web.');
  }
}
