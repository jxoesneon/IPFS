# RFC: Native QUIC Transport for dart_ipfs

## Status

**Draft v1.0** — Produced as part of the QUIC_SPEC close-out. The conditional
QUIC_SPEC requirements (config, runtime probe, TCP fallback) are already
implemented in `lib/src/core/config/network_config.dart` and
`lib/src/transport/libp2p_router.dart`. This RFC evaluates the path to a
native, Kubo/Helia-interoperable QUIC transport.

## Background

`package:ipfs_libp2p` 0.5.6 only exports `TCPTransport` and `UdxTransport`. No
`QuicTransport` class or `/quic` multiaddr support is exposed. The dart_ipfs
router therefore probes for QUIC availability at runtime and falls back to
TCP when QUIC is unavailable.

Goal: provide a native QUIC transport that can be enabled when the runtime
environment supplies the native quiche library, without requiring changes to
`package:ipfs_libp2p`.

## Options Evaluated

| Option | License | Pros | Cons | Verdict |
|--------|---------|------|------|---------|
| `flutter_quic` | MIT | Pure Quinn Rust backend, desktop + mobile, full QUIC | Flutter-only plugin; dart_ipfs is a pure Dart/VM package; adds Rust build toolchain to consumers | Rejected for core package |
| `pure_dart_quic` | GPL-3.0 | Pure Dart, no native build | GPL copy-incompatible with MIT project; experimental | Rejected |
| `quic` (pub.dev) | GPL-3.0 | Pure Dart | GPL copy-incompatible; 5 years old, unlisted | Rejected |
| `Dusty-Quiche` | No license | FFI to quiche | No explicit license; stale; build issues reported | Rejected |
| **quiche FFI (new bindings)** | BSD-2 (quiche) | Battle-tested, Cloudflare maintained, C API, license-compatible | Requires native library build per platform; requires custom Dart transport wrapper | **Selected** |
| **msquic FFI** | MIT (msquic) | Microsoft maintained, C API | C API is `msquic.h` (C headers) but bindings are C++/C# oriented; less Rust/Dart ecosystem precedent | Alternative |
| Implement QUIC from scratch in Dart | MIT | No native dependency | High security risk, high maintenance, violates QUIC_SPEC guidance | Rejected by Ciel Safety veto |

## Council of Five Decision

The Ciel Council of Five deliberated on native QUIC strategy:

- **Coherence**: 9/10 for quiche FFI — project already has libsodium FFI and
  Docker native-library patterns.
- **Capability**: 4/10 for quiche FFI — no existing Dart bindings; libp2p QUIC
  framing layer must be built on top.
- **Safety**: 5/10 for quiche FFI (vetoed pure-Dart and Flutter-plugin options).
- **Efficiency**: 5/10 for quiche FFI — high effort, but highest value if
  completed.
- **Evolution**: 8/10 for quiche FFI — creates reusable FFI pattern and enables
  future native integrations.

**Outcome**: Proceed with quiche FFI as a separately versioned, optional
package (`packages/dart_ipfs_quic`) rather than a custom in-tree binding. Do
not ship a half-integrated transport that advertises `/quic` without full
libp2p security handshake support.

## Architecture

```
┌──────────────────────────────────────┐
│  dart_ipfs Libp2pRouter              │
│  (probes / enableQuic / fallback)    │
└────────────┬─────────────────────────┘
             │ optional import
┌────────────▼─────────────────────────┐
│  packages/dart_ipfs_quic             │
│  ┌──────────────────────────────┐  │
│  │ Quiche FFI bindings            │  │
│  │ (lib/src/generated/quiche_*) │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ QuicheLibrary / Config / Conn  │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ QuicTransport (implements    │  │
│  │ package:ipfs_libp2p Transport) │  │
│  └──────────────────────────────┘  │
└──────────────────────────────────────┘
             │
┌────────────▼─────────────────────────┐
│  native quiche.dll / libquiche.so    │
│  (built from cloudflare/quiche)      │
└──────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Foundation (completed)

- `packages/dart_ipfs_quic` package created.
- Hand-written FFI bindings for the quiche C API (config, connection, stream,
  error codes).
- Library loader that resolves `quiche.dll` / `libquiche.so` from the package
  `native/` directory, PATH, or system library paths.
- `QuicheLibrary.probe()` runtime availability check.
- Unit tests verifying library load and config creation.

### Phase 2: UDP I/O Loop

- Implement `quiche_recv` / `quiche_send` driven by `dart:io` `RawDatagramSocket`.
- Timer-based connection polling (quiche is a push/pull API; no async
  callbacks).
- Packet destination tracking for dial/listen.

### Phase 3: libp2p Transport Wrapper

- Implement `QuicTransport` implementing `package:ipfs_libp2p` `Transport`:
  - `protocols`: `/ip4/udp/quic`, `/ip6/udp/quic`, `/ip4/udp/quic-v1`, `/ip6/udp/quic-v1`.
  - `canDial` / `canListen`: match QUIC multiaddr components.
  - `dial`: resolve host, create `RawDatagramSocket`, create quiche client
    connection, drive handshake, wrap in `TransportConn`.
  - `listen`: bind UDP socket, accept Initial packets, create server
    connections, produce `Listener`.
- Implement `QuicConnection` extending `TransportConn`:
  - Map quiche streams to `P2PStream` via a multiplexer (Yamux or native
    QUIC streams).
  - Provide `localMultiaddr`, `remoteMultiaddr`, `localPeer`, `remotePeer`.

### Phase 4: libp2p Security Handshake

- libp2p QUIC requires TLS 1.3 with a self-signed certificate containing the
  peer's public key (per
  [libp2p QUIC spec](https://github.com/libp2p/specs/blob/master/transports/quic.md)).
- Generate short-lived certificates from the node's Ed25519 key pair.
- Configure quiche `verify_peer` to validate libp2p certificates.
- This is the highest-effort phase and the primary blocker for Kubo/Helia
  interoperability.

### Phase 5: Integration & Testing

- Wire `QuicTransport` into `Libp2pRouter` when `enableQuic` is true and
  `QuicheLibrary.probe().isAvailable` is true.
- Update `NetworkConfig` to expose certificate path / auto-generation options.
- Add interop tests against a local Kubo/Helia node.
- Build CI for Windows, Linux, macOS native libraries.

## Build & Distribution

### Windows

```powershell
# one-time build
$env:PATH = "C:\Users\josee\AppData\Local\nasm\nasm-3.01;$env:PATH"
git clone --branch 0.23.0 --recursive https://github.com/cloudflare/quiche.git
cd quiche
cargo build --package quiche --release --features ffi
# output: target/release/quiche.dll
copy target/release/quiche.dll packages/dart_ipfs_quic/native/
```

### Linux / macOS

```bash
git clone --branch 0.23.0 --recursive https://github.com/cloudflare/quiche.git
cd quiche
cargo build --package quiche --release --features ffi
# output: target/release/libquiche.so (Linux) or libquiche.dylib (macOS)
cp target/release/libquiche.* packages/dart_ipfs_quic/native/
```

### CI / Native Assets

Consider migrating to Dart `native_assets`/`native_toolchain_cmake` so the
Rust build runs during `dart pub get` on supported platforms. This avoids
committing binaries to the repo.

## Security Considerations

- The native library is built from the pinned quiche tag (0.23.0) with a
  verified checksum.
- FFI allocations use `calloc`/`free` and should be wrapped in `NativeFinalizer`
  for production use.
- TLS certificate generation must use the node's existing key pair and must not
  introduce a separate trust root.
- The transport should only be enabled explicitly (`enableQuic: true`) and the
  router must fall back to TCP if the library is missing or fails to load.

## Recommended Next Steps

1. Complete Phase 2 (UDP I/O loop) and Phase 3 (Transport wrapper) behind a
   feature flag or experimental API.
2. Implement Phase 4 (libp2p TLS 1.3 certificate handshake) before claiming
   Kubo/Helia interoperability.
3. Replace hand-written bindings with `ffigen` once LLVM/clang is available in
   the build environment (CI can install it easily).
4. Add native-assets build so consumers do not need to manually copy DLLs.

## References

- [QUIC_SPEC.md](features/QUIC_SPEC.md)
- [cloudflare/quiche](https://github.com/cloudflare/quiche)
- [libp2p QUIC spec](https://github.com/libp2p/specs/blob/master/transports/quic.md)
- [Dart FFI](https://dart.dev/guides/libraries/c-interop)
