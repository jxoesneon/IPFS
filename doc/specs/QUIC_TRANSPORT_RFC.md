# RFC: Native QUIC Transport for dart_ipfs

## Status

**Updated v1.1** — The project now uses the pure-Dart `quic_lib` package as the
QUIC transport foundation. The previous quiche FFI foundation has been removed
from `packages/dart_ipfs_quic`. The conditional QUIC_SPEC requirements (config,
runtime probe, TCP fallback) remain implemented in
`lib/src/core/config/network_config.dart` and
`lib/src/transport/libp2p_router.dart`. This RFC records the rationale and
remaining work toward a Kubo/Helia-interoperable QUIC transport.

## Background

`package:ipfs_libp2p` 0.5.6 only exports `TCPTransport` and `UdxTransport`. No
`QuicTransport` class or `/quic` multiaddr support is exposed. The dart_ipfs
router therefore probes for QUIC availability at runtime and falls back to
TCP when QUIC is unavailable.

Goal: provide a native QUIC transport without requiring changes to
`package:ipfs_libp2p` and without native FFI build dependencies.

## Options Evaluated

| Option | License | Pros | Cons | Verdict |
|--------|---------|------|------|---------|
| `flutter_quic` | MIT | Pure Quinn Rust backend, desktop + mobile, full QUIC | Flutter-only plugin; dart_ipfs is a pure Dart/VM package; adds Rust build toolchain to consumers | Rejected for core package |
| `pure_dart_quic` | GPL-3.0 | Pure Dart, no native build | GPL copy-incompatible with MIT project; experimental | Rejected |
| `quic` (pub.dev) | GPL-3.0 | Pure Dart | GPL copy-incompatible; 5 years old, unlisted | Rejected |
| `Dusty-Quiche` | No license | FFI to quiche | No explicit license; stale; build issues reported | Rejected |
| quiche FFI (new bindings) | BSD-2 (quiche) | Battle-tested, Cloudflare maintained, C API | Requires native library build per platform; requires custom Dart transport wrapper | Replaced |
| **quic_lib (custom pure-Dart package)** | MIT | Full pure-Dart QUIC, HTTP/3, WebTransport, libp2p transport exports; no native build; license-compatible | libp2p `Transport`/`Conn`/`Listener` adapter layer required; Kubo interop not yet proven | **Selected** |
| **msquic FFI** | MIT (msquic) | Microsoft maintained, C API | C API is `msquic.h` (C headers) but bindings are C++/C# oriented; less Rust/Dart ecosystem precedent | Alternative |
| Implement QUIC from scratch in Dart | MIT | No native dependency | High security risk, high maintenance | Superseded by quic_lib |

## Council of Five Decision

The Ciel Council of Five deliberated on native QUIC strategy. After the user
provided the `quic_lib` package, the Council updated its verdict:

- **Coherence**: 9/10 for `quic_lib` — pure-Dart aligns with the project's
  goal of minimizing native build/toolchain dependencies for consumers.
- **Capability**: 7/10 for `quic_lib` — a full QUIC wire-format, HTTP/3,
  WebTransport, and libp2p transport layer exists; only the adapter to
  `package:ipfs_libp2p`'s `Transport`/`Conn`/`Listener` interfaces is needed.
- **Safety**: 7/10 for `quic_lib` — well-structured pure-Dart code with
  comprehensive tests; avoids FFI memory-safety risks and native binary
  distribution.
- **Efficiency**: 7/10 for `quic_lib` — removes the Rust build step and
  native-assets complexity, but requires adapter and interop testing.
- **Evolution**: 8/10 for `quic_lib` — creates a reusable pure-Dart QUIC
  stack that can be published independently.

**Outcome**: Replace the quiche FFI foundation in `packages/dart_ipfs_quic`
with a `quic_lib` adapter. The transport remains behind the `enableQuic`
flag and TCP fallback is preserved. Do not ship a half-integrated transport
that advertises `/quic-v1` without full libp2p security handshake support and
proven Kubo/Helia interop.

## Architecture

```
┌──────────────────────────────────────┐
│  dart_ipfs Libp2pRouter              │
│  (probes / enableQuic / fallback)    │
└────────────┬─────────────────────────┘
             │ imports package:dart_ipfs_quic
┌────────────▼─────────────────────────┐
│  packages/dart_ipfs_quic             │
│  ┌──────────────────────────────┐  │
│  │ QuicTransport                │  │
│  │ (implements                │  │
│  │ package:ipfs_libp2p Transport)│  │
│  ├──────────────────────────────┤  │
│  │ QuicConnection               │  │
│  │ QuicListener                 │  │
│  └──────────────────────────────┘  │
└────────────┬─────────────────────────┘
             │ imports package:quic_lib
┌────────────▼─────────────────────────┐
│  quic_lib (pure-Dart)                │
│  ┌──────────────────────────────┐  │
│  │ Libp2pQuicTransport          │  │
│  │ Libp2pQuicConnection         │  │
│  │ QuicEndpoint / QuicConnection│  │
│  │ libp2p TLS extension         │  │
│  └──────────────────────────────┘  │
└──────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Foundation (completed)

- `packages/dart_ipfs_quic` package created.
- `quic_lib` dependency added (pure-Dart QUIC stack).
- `QuicTransport` implementing `package:ipfs_libp2p` `Transport`:
  - `protocols`: `/ip4/udp/quic-v1`, `/ip6/udp/quic-v1`.
  - `canDial` / `canListen`: match QUIC multiaddr components.
  - `dial`: delegate to `quic_lib.Libp2pQuicTransport.dial` and wrap in
    `QuicConnection`.
  - `listen`: delegate to `quic_lib.Libp2pQuicTransport.listen` and wrap in
    `QuicListener`.
- `QuicConnection` and `QuicListener` adapters implementing the required
  libp2p interfaces.
- Unit tests verifying `Transport` interface compliance.

### Phase 2: UDP I/O Loop

- `quic_lib` already provides the QUIC endpoint and UDP I/O loop.
- Verify that `Libp2pQuicTransport` binds the correct local address and can
  receive incoming Initial packets.

### Phase 3: libp2p Transport Wrapper (completed)

- `QuicConnection.newStream` now opens a real QUIC bidirectional stream and
  wraps it in `QuicP2PStream`.
- `QuicP2PStream` maps `quic_lib` stream data to the `P2PStream.read`/`write`
  contract.
- `localMultiaddr`, `remoteMultiaddr`, `localPeer`, and `remotePeer` are
  provided from the connection metadata.

### Phase 4: libp2p Security Handshake (partial)

- libp2p QUIC requires TLS 1.3 with a self-signed certificate containing the
  peer's public key (per
  [libp2p QUIC spec](https://github.com/libp2p/specs/blob/master/transports/quic.md)).
- `QuicConnection` now exposes `verifyPeer()` for ALPN validation and
  `verifyPeerCertificate()` for libp2p TLS extension verification.
- `quic_lib`'s `Libp2pCertificateGenerator` is used to produce test
  certificates and the extension parser validates them.
- The remaining gap is automatic extraction of the peer's certificate bytes
  from the live `quic_lib` handshake. Once `quic_lib` exposes those bytes,
  `verifyPeerCertificate()` can be invoked automatically during connection
  establishment. Until then, Kubo/Helia interoperability is not yet
  complete.

### Phase 5: Integration & Testing

- Wire `QuicTransport` into `Libp2pRouter` when `enableQuic` is true.
- Add interop tests against a local Kubo/Helia node.
- Add CI for `dart_ipfs_quic` and `quic_lib` tests on Windows, Linux, macOS.

## Build & Distribution

No native library build is required. `quic_lib` is pure Dart and is resolved
as a normal `pub` dependency.

### Dependency

`packages/dart_ipfs_quic/pubspec.yaml` references `quic_lib` as a hosted
pub.dev dependency:

```yaml
dependencies:
  quic_lib: ^1.10.0
```

### CI

Run `dart pub get` followed by `dart test` for both `quic_lib` and
`packages/dart_ipfs_quic`.

## Security Considerations

- The QUIC implementation is pure Dart; no native binary verification is
  required.
- TLS certificate generation must use the node's existing key pair and must not
  introduce a separate trust root.
- The transport should only be enabled explicitly (`enableQuic: true`) and the
  router must fall back to TCP if the transport fails to load or the handshake
  cannot complete.

## Recommended Next Steps

1. Update `quic_lib` so the live TLS handshake exposes the peer's certificate
   bytes to the adapter, then call `verifyPeerCertificate()` automatically
   during connection establishment.
2. Harden the `QuicP2PStream` read path for real bidirectional peer
   communication and add end-to-end QUIC stream tests.
3. Add interop tests against a local Kubo node and a Helia node over QUIC.
4. Keep the `quic_lib` hosted dependency current as new versions are
   published.

## References

- [QUIC_SPEC.md](features/QUIC_SPEC.md)
- [quic_lib](https://github.com/jxoesneon/quic_lib)
- [libp2p QUIC spec](https://github.com/libp2p/specs/blob/master/transports/quic.md)
