# QUIC Transport Specification for dart_ipfs

**Document:** `QUIC_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\QUIC_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** P0 Approved — implementation pending  
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

- `lib/src/transport/libp2p_router.dart` — only configures `TCPTransport` from `package:ipfs_libp2p`.
- `lib/src/core/config/network_config.dart` — has `defaultListenAddresses` including `/udp/4002/quic-v1/webtransport` but no QUIC-specific flags.

### 3.2 Gaps

- `Libp2pRouter` does not instantiate a QUIC transport even when the config advertises a UDP address.
- QUIC addresses are not emitted in `listeningAddresses`.
- There is no transport-preference logic; TCP is always used first.
- No graceful fallback path exists if the QUIC dependency is unavailable at runtime.

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
  this.enableQuic = true,       // default true
  this.quicListenPort = 4002,   // default
  this.quicMaxStreams = 100,
  this.preferQuic = true,       // dial QUIC before TCP if both advertised
});
```

YAML/JSON keys:

```yaml
network:
  enableQuic: true
  quicListenPort: 4002
  preferQuic: true
```

### 4.3 Implementation Requirements

1. Add a `QuicTransport` wrapper around the QUIC transport exposed by `package:ipfs_libp2p`, or a custom Dart QUIC binding if the package does not expose one. Select the most mature dependency available.
2. In `Libp2pRouter.start()`, conditionally add `Libp2p.transport(QuicTransport(...))` when `enableQuic` is true.
3. Build listen addresses from `NetworkConfig.listenAddresses` and synthesize `/ip4/0.0.0.0/udp/$quicListenPort/quic-v1` and `/ip6/::/udp/$quicListenPort/quic-v1` if not already present.
4. If `package:ipfs_libp2p` does not expose QUIC, fall back to TCP-only and log a warning at startup.

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
  bool get supportsQuic;
  Future<bool> connect(String multiaddr); // must understand /quic-v1
}
```

### 4.6 Transport Selection and Fallback

- When `preferQuic` is true, the router should attempt QUIC before TCP if both transports are advertised for a target peer.
- If QUIC dial fails, the router must retry with TCP transparently to the caller.
- If `enableQuic` is false, no QUIC transport is instantiated and no QUIC addresses are advertised.

---

## 5. Detailed Acceptance Criteria

- `Libp2pRouter.listeningAddresses` contains at least one `/quic-v1` address when `enableQuic` is true.
- A dart_ipfs node can be dialed by Kubo over QUIC (`ipfs swarm connect /udp/.../quic-v1/p2p/<dart-peer-id>`).
- TCP fallback remains operational when QUIC fails or is disabled.
- `connect()` accepts `/quic-v1` multiaddrs and returns success when the peer is reachable.
- `supportsQuic` reflects the actual runtime state (false if dependency missing or disabled).

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

- Availability of a mature Dart QUIC package or QUIC bindings in `package:ipfs_libp2p`.
- `Libp2pRouter` must expose a clean transport registration API.

### 8.2 Order Relative to Other Features

- **Before**: Browser Transport Hardening (WebTransport builds on QUIC), DHT Integration (DHT queries benefit from QUIC dial), Circuit Relay (relay can be reached over QUIC).
- **Parallel with**: Gossipsub, IPNS (no direct dependency).
- **After**: TCP baseline already exists.

### 8.3 External Dependencies

- `package:ipfs_libp2p` or a Dart QUIC library (`package:quic` if available, FFI bindings to `quiche`/`ngtcp2` otherwise).
- `package:libp2p_noise` or equivalent for Noise handshake.

---

## 9. Backward Compatibility Notes

- `NetworkConfig` gains new optional fields with sensible defaults; existing YAML configs continue to work without modification.
- TCP-only deployments are unaffected when `enableQuic` is false.
- `preferQuic` defaulting to true may change dial ordering; downstream callers that assume TCP first must update expectations or set `preferQuic: false`.
- No wire-format breaking changes are introduced; QUIC is an additive transport.
