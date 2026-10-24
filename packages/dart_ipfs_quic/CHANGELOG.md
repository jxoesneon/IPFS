# Changelog

## 0.3.0

- Minimum Dart SDK raised to 3.11.0 (from 3.4.0) to match the toolchain the package's dev dependencies need.
- Dependencies updated to their latest releases: `ipfs_libp2p 0.5.11`, `dart_ipfs_core 1.14.0`, `collection 1.19.1`, `meta 1.19.0`, `logging 1.3.0`, `uuid 4.6.0`, `test 1.33.0`, `lints 6.1.0`.
- Added the `dart_udx ^2.0.3` dependency override, mirroring the umbrella package's security pin. `ipfs_libp2p` still allows the older `dart_udx` releases, so without the override this published package resolved the vulnerable version.

## 0.2.1

- Excised dead native `quiche.dll` binary (3.2 MB), `quiche.h` C headers, and legacy `ffigen.yaml` configuration.
- Bumped `dart_ipfs_core` dependency constraint to `^1.11.6`.

## 0.2.0

- Replaced Cloudflare quiche FFI backend with the pure-Dart `quic_lib` package from pub.dev.
- Added `QuicTransport` implementing `package:ipfs_libp2p`'s `Transport` interface.
- Added `QuicConnection`, `QuicListener`, and `QuicP2PStream` adapters around `quic_lib`.
- `QuicConnection.newStream` opens real QUIC bidirectional streams.
- Added `verifyPeer()`, `verifyPeerCertificate()`, and `verifyPeerFromHandshake()` for libp2p TLS extension verification.
- Removed native `quiche.dll`/`quiche.h` and `ffigen` configuration.
- Updated tests to verify transport interface compliance without native deps.
- Development dependency now points to the local `quic_lib` checkout; production releases use the hosted pub.dev package.
- Fixed `QuicP2PStream.read()` buffering so incoming data is always buffered and `maxLength` reads work correctly.
- Added comprehensive tests for `QuicListener`, `QuicP2PStream` read/write/close/reset, and `QuicConnection` metadata.

## 0.1.0

- Initial foundation package.
- Hand-written FFI bindings to quiche 0.23.0 C API.
- `QuicheLibrary.probe()` runtime loader.
- `QuicheConfig` and `QuicheConnection` Dart wrappers.
- Unit tests verifying native library load and config creation.
