# Changelog

## 0.2.0

- Replaced Cloudflare quiche FFI backend with the pure-Dart `quic_lib` package from pub.dev.
- Added `QuicTransport` implementing `package:ipfs_libp2p`'s `Transport` interface.
- Added `QuicConnection`, `QuicListener`, and `QuicP2PStream` adapters around `quic_lib`.
- `QuicConnection.newStream` opens real QUIC bidirectional streams.
- Added `verifyPeer()` and `verifyPeerCertificate()` for libp2p TLS extension verification.
- Removed native `quiche.dll`/`quiche.h` and `ffigen` configuration.
- Updated tests to verify transport interface compliance without native deps.

## 0.1.0

- Initial foundation package.
- Hand-written FFI bindings to quiche 0.23.0 C API.
- `QuicheLibrary.probe()` runtime loader.
- `QuicheConfig` and `QuicheConnection` Dart wrappers.
- Unit tests verifying native library load and config creation.
