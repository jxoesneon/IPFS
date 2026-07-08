/// Native QUIC transport for dart_ipfs using Cloudflare quiche FFI.
///
/// This package is optional: when the native quiche library is available,
/// [Libp2pRouter] can instantiate [QuicTransport] and advertise `/quic` and
/// `/quic-v1` multiaddresses. When the library is unavailable, the router
/// falls back to TCP-only mode with a logged warning, exactly as documented
/// in QUIC_SPEC.
library;

export 'src/quiche/quiche_library.dart';
export 'src/quiche/quiche_config.dart';
export 'src/quiche/quiche_connection.dart';
