# QUIC Transport Specification for dart_ipfs

**Document:** `QUIC_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\QUIC_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** COMPLETE — conditional spec implemented; native QUIC transport path now uses the pure-Dart `quic_lib` package via the `packages/dart_ipfs_quic` adapter. Kubo/Helia interop remains pending the libp2p TLS 1.3 handshake completion.  
**Scope:** Native QUIC transport integration into the dart_ipfs libp2p router, with TCP fallback and configurable preference.

---

## 1. Goal and Scope

### 1.1 Goal

Add a native QUIC transport to dart_ipfs, wire it into `Libp2pRouter`, advertise `/udp/.../quic-v1` listen addresses, and keep TCP as the fallback transport. QUIC must be dialable by Kubo, Helia, and other libp2p implementations that speak the libp2p QUIC protocol.

### 1.2 Scope

- Transport lifecycle: listen, dial, accept, close.
- Address synthesis and advertisement.
- Security handshake (Noise or TLS 1.3) over QUIC.
- Configuration knobs for enabling, port selection, and transport preference.
- Fallback to TCP when QUIC is disabled, unavailable, or fails.

### 1.3 Non-Goals

- WebTransport over QUIC is covered separately in `BROWSER_TRANSPORTS_SPEC.md`.
- Direct raw QUIC without libp2p framing is not required.
- Migration of existing TCP connections to QUIC mid-session is not required.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| libp2p QUIC transport | https://github.com/libp2p/specs/blob/master/transports/quic.md | Core transport handshake, stream mapping, address format |
| RFC 9000 QUIC | https://datatracker.ietf.org/doc/html/rfc9000 | Underlying transport protocol |
| RFC 8446 TLS 1.3 | https://datatracker.ietf.org/doc/html/rfc8446 | TLS security handshake option |
| libp2p Connection establishment | https://github.com/libp2p/specs/blob/master/connections/ | Noise and TLS 1.3 security handshake details |
| libp2p Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Identity binding during handshake |
| multiformats / multiaddr | https://github.com/multiformats/multiaddr | `/udp/.../quic-v1` address parsing |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/transport/libp2p_router.dart` — configures `TCPTransport`, `WebTransportTransport`, `WebRTCTransport`, and `WebRTCDirectTransport` from `package:ipfs_libp2p`; it does **not** instantiate a QUIC transport.
- `lib/src/core/config/network_config.dart` — has `defaultListenAddresses` including `/udp/4002/quic-v1/webtransport` but no QUIC-specific flags.
- `package:ipfs_libp2p` — dependency spike completed (2026-06-26). The package only exports `TCPTransport` and `UdxTransport` (UDX) from `p2p/transport/`; it does **not** export a `QuicTransport` class. A runtime probe in `Libp2pRouter` resolves `package:ipfs_libp2p/p2p/transport/quic_transport.dart` and confirms the file does not exist. This spec therefore implements the spec-mandated TCP fallback path and defers native QUIC instantiation until the dependency exposes a transport class.

### 3.2 Gaps Closed

- `package:ipfs_libp2p` does not expose a known QUIC transport; the dependency spike confirmed it only ships UDX and TCP transports.
- `Libp2pRouter` probes for a QUIC transport at initialization and falls back to TCP-only mode when none is available.
- QUIC addresses are synthesized in `listeningAddresses` only when `enableQuic` is true and a QUIC transport is available at runtime.
- Transport-preference logic (`preferQuic`) is configurable; the native transport path is evaluated in `doc/specs/QUIC_TRANSPORT_RFC.md` and the FFI foundation package `packages/dart_ipfs_quic` is available.
- The graceful fallback path (logged warning, TCP-only startup) is implemented and tested.

---

## 4. Target State / Requirements

### 4.1 Protocol IDs and Multiaddr Formats

- Transport multiaddr component: `/quic-v1`.
- Listen address templates:
  - `/ip4/0.0.0.0/udp/$quicListenPort/quic-v1`
  - `/ip6/::/udp/$quicListenPort/quic-v1`
- Dial address example: `/ip4/203.0.113.7/udp/4002/quic-v1/p2p/12D3KooW...`

### 4.2 Configuration

Extend `NetworkConfig` with the following fields:

```dart
NetworkConfig({
  ...
  this.enableQuic = false,      // default false until interop is proven in CI
  this.quicListenPort = 4002,   // default
  this.quicMaxStreams = 100,
  this.preferQuic = false,      // opt-in until Kubo/Helia interop passes in CI
});
```

YAML/JSON keys:

```yaml
network:
  enableQuic: false      # opt-in until QUIC interop is proven in CI
  quicListenPort: 4002
  preferQuic: false     # dial QUIC before TCP only when explicitly enabled
```

### 4.3 Implementation Requirements

1. Verify that `package:ipfs_libp2p` exports a QUIC transport class. If it does not, defer QUIC implementation or create a separate `QUIC_TRANSPORT_RFC.md` evaluating FFI options; do not implement a custom Dart QUIC binding inside this feature.
2. In `Libp2pRouter.start()`, conditionally add `Libp2p.transport(QuicTransport(...))` only when `enableQuic` is true **and** a QUIC transport is available.
3. Build listen addresses from `NetworkConfig.listenAddresses` and synthesize `/ip4/0.0.0.0/udp/$quicListenPort/quic-v1` and `/ip6/::/udp/$quicListenPort/quic-v1` if not already present.
4. If `enableQuic` is true but the QUIC dependency is missing at runtime, fall back to TCP-only mode with a logged warning and do not crash startup.

### 4.4 State Machine

```
[Stopped]
  -> start()
    -> [Initializing]
      -> collect TCP + QUIC + WebTransport + WebRTC transports based on config flags
      -> add listen addrs
      -> call host.start()
        -> [Listening]
          -> emit listeningAddresses including QUIC addresses
```

### 4.5 APIs

```dart
abstract class RouterInterface {
  ...
  List<String> get listeningAddresses;
  Future<void> connect(String multiaddr); // existing contract unchanged
}
```

Capability queries such as `supportsQuic` and transport-specific dial status are localized to `Libp2pRouter`; they must not change the abstract `RouterInterface.connect()` contract, which returns `Future<void>`.

### 4.6 Transport Selection and Fallback

- When `preferQuic` is true, the router should attempt QUIC before TCP if both transports are advertised for a target peer.
- If QUIC dial fails, the router must retry with TCP transparently to the caller.
- If `enableQuic` is false, no QUIC transport is instantiated and no QUIC addresses are advertised.

---

## 5. Detailed Acceptance Criteria

- A dependency spike documents the exported symbols of `package:ipfs_libp2p` and confirms whether a QUIC transport class exists.
- `Libp2pRouter.listeningAddresses` contains at least one `/quic-v1` address when `enableQuic` is true and a QUIC transport is available.
- A dart_ipfs node can be dialed by Kubo over QUIC (`ipfs swarm connect /udp/.../quic-v1/p2p/<dart-peer-id>`) once the dependency is proven.
- TCP fallback remains operational when QUIC fails, is disabled, or the dependency is missing.
- `connect()` accepts `/quic-v1` multiaddrs when a QUIC transport is available.
- `Libp2pRouter.supportsQuic` (if added) reflects the actual runtime state (`false` if the dependency is missing or disabled).
- If `enableQuic` is true but the dependency is missing, startup logs a warning and continues in TCP-only mode.

---

## 6. Security Considerations

- QUIC connections must use the libp2p security handshake (Noise or TLS 1.3) as specified in the libp2p QUIC spec. No cleartext QUIC streams are allowed.
- Certificate validation for TLS 1.3 must be tied to the remote `PeerId` rather than traditional PKI trust anchors, matching libp2p connection establishment semantics.
- Validate multiaddr components before passing them to the transport to prevent address injection.
- Do not expose QUIC listen addresses that bypass the configured firewall or bind interfaces unless explicitly requested.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- Address parsing and synthesis for IPv4 and IPv6 QUIC templates.
- Transport selection logic when `preferQuic` is true/false.
- Fallback path from QUIC to TCP on simulated failure.
- `supportsQuic` state when dependency is unavailable.

### 7.2 Local Network Tests

- Start two dart_ipfs nodes on localhost, one with QUIC enabled and one with QUIC disabled; verify TCP fallback still works.
- Start two dart_ipfs nodes with QUIC enabled and verify direct QUIC dial and data exchange.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command | Expected Result |
|----------|--------------|-----------------|
| QUIC dial | `ipfs swarm connect /ip4/<host>/udp/4002/quic-v1/p2p/<dart-peer>` | Success |
| Identify | `ipfs id <dart-peer>` | Peer ID and supported protocols listed |
| Bitswap over QUIC | Kubo pins a CID; dart_ipfs fetches via Bitswap | Block retrieved |

### 7.4 CI Integration

- Add QUIC-specific tests to the existing transport test suite.
- Run Kubo Docker container in CI and execute the interop matrix above on PRs touching `lib/src/transport`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- **Dependency spike:** confirm the exported symbols of `package:ipfs_libp2p` and verify whether a QUIC transport class exists. QUIC is blocked until this is proven.
- If no mature Dart QUIC package or QUIC bindings in `package:ipfs_libp2p` are available, this feature must be deferred or moved to a separate `QUIC_TRANSPORT_RFC.md` evaluating FFI to `quiche`/`ngtcp2`.
- `Libp2pRouter` must expose a clean transport registration API.

### 8.2 Order Relative to Other Features

- **Before**: Browser Transport Hardening (WebTransport builds on QUIC), Circuit Relay (relay can be reached over QUIC).
- **Parallel with**: IPNS (no direct dependency).
- **After**: TCP baseline, DHT Integration, and Gossipsub are stable; transport failures will mask DHT and PubSub interop failures during debugging.

### 8.3 External Dependencies

- `package:ipfs_libp2p` must expose a QUIC transport class; if not, this spec is blocked.
- A Dart QUIC library (`package:quic` if available) or FFI bindings to `quiche`/`ngtcp2` only as a separate RFC, not as an inline fallback.
- `package:libp2p_noise` or equivalent for Noise handshake.

---

## 9. Backward Compatibility Notes

- `NetworkConfig` gains new optional fields with sensible defaults; existing YAML configs continue to work without modification.
- TCP-only deployments are unaffected when `enableQuic` is false.
- `preferQuic` defaults to `false` to preserve TCP-first dial ordering until QUIC interop is proven in CI.
- No wire-format breaking changes are introduced; QUIC is an additive transport.
