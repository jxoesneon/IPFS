# Browser-Native P2P Connectivity Plan: WebRTC + WebTransport

**Status:** Draft  
**Owner:** dart_ipfs maintainer  
**Target Release:** v1.11 (Q2 2026)  
**Upstream dependency:** `ipfs_libp2p` (currently `^0.5.6`) — referred to colloquially as "dart_libp2p"  
**Last Updated:** 2026-05-08

---

## 1. Executive Summary

This plan defines the work required to deliver **full browser-native peer-to-peer connectivity** in `dart_ipfs` by adding two libp2p transports — **WebTransport** and **WebRTC** — to the underlying `ipfs_libp2p` library and integrating them into the `Libp2pRouter` and `IPFSWebNode`.

When complete, a browser running `dart_ipfs` will be able to:

- Dial any libp2p server that exposes a WebTransport listener (browser → server, no relay required).
- Dial other browsers using WebRTC private-to-private with a relay-based signaling channel (browser ↔ browser).
- Be dialed back from native Dart VM nodes that learn its multiaddr via the DHT.

This unlocks the `IPFSWebNode` from its current "stub router" state and gives the Dart implementation feature parity with `js-libp2p` for browser deployments.

---

## 2. Current State

### 2.1 Where we are today

| Layer | Native (Dart VM) | Web (Browser) |
| --- | --- | --- |
| Router | `Libp2pRouter` (TCP/Noise/Yamux) | `WebStubRouter` (no real networking) |
| Transport | TCP only | _none_ |
| Discovery | DHT + mDNS + Bootstrap | _none_ |
| Bitswap / PubSub / IPNS | ✅ over libp2p | ⚠️ defined but no peers reachable |
| Storage | FileStore / Hive | IndexedDB ✅ |

### 2.2 Specific code anchors

The following code locations encode the current limitation and will be the touch-points for this work:

- `@c:\Users\Eduardo\ipfs\lib\src\transport\libp2p_router.dart:587-607` — `_buildTransports()` only registers `TCPTransport`, with a placeholder `TODO: Add WebTransport and WebRTC based on config (Phase 1)`.
- `@c:\Users\Eduardo\ipfs\lib\src\core\ipfs_node\ipfs_web_node.dart:33` — Doc comment acknowledges _"For full P2P functionality, run on native platforms or use a WebRTC/WebSocket relay supported by the router."_
- `@c:\Users\Eduardo\ipfs\lib\src\core\ipfs_node\ipfs_web_node.dart:42` — `_router = WebStubRouter()` is hard-coded.
- `@c:\Users\Eduardo\ipfs\lib\src\core\ipfs_node\ipfs_web_node.dart:247-248` — `WebStubRouter` exists explicitly _"until Libp2p supports WebSockets/WebRTC"_.
- `@c:\Users\Eduardo\ipfs\lib\src\core\config\network_config.dart:67-71` — `defaultListenAddresses` only contains TCP multiaddrs.
- `@c:\Users\Eduardo\ipfs\doc\ARCHITECTURE.md:46-52` — Networking stack docs already promise _"Transports: TCP, WebSocket, and soon WebRTC/WebTransport."_
- `@c:\Users\Eduardo\ipfs\ROADMAP.md:43` — v1.11 explicitly lists _"Libp2p browser transport (WebRTC/WebTransport)."_

---

## 3. Goals & Non-Goals

### 3.1 Goals

1. **Browser-to-server WebTransport**: A browser node can dial any libp2p peer that listens on `/ip4/.../udp/.../quic-v1/webtransport/certhash/...`.
2. **Browser-to-browser WebRTC**: Two browsers can establish a direct, encrypted, multiplexed libp2p connection using the `webrtc` (private-to-private) protocol with a public libp2p relay node performing SDP signaling.
3. **Browser-to-server WebRTC-direct**: A browser can dial a non-browser node that listens on `/ip4/.../udp/.../webrtc-direct/certhash/...` (no relay needed).
4. **Native node interop**: Dart VM nodes can listen on WebTransport and act as signaling relays for WebRTC, so browsers running `dart_ipfs` can reach the wider IPFS network.
5. **Replace `WebStubRouter`** with a real `Libp2pRouter` configured for browser-safe transports.
6. **Maintain Kubo/js-libp2p protocol compliance** — multiaddrs, certificate hashes, Noise integration, and stream multiplexing must match the upstream specs.

### 3.2 Non-Goals (deferred to later releases)

- Native QUIC transport beyond what WebTransport requires (deferred to v2.0).
- Acting as a TURN server.
- WebSocket transport (separately tracked; complementary, not blocking).
- Mobile-platform WebRTC tuning (Flutter mobile deferred to v1.11.x patches).
- Replacing all native transports with QUIC-only.

---

## 4. Technical Background

### 4.1 libp2p WebTransport (browser → server)

- Runs over **HTTP/3 / QUIC** (UDP).
- Multiaddr form: `/ip4/<ip>/udp/<port>/quic-v1/webtransport/certhash/<mh1>/certhash/<mh2>/p2p/<peerid>`.
- `certhash` entries are multihashes of self-signed server certificates, allowing a browser to verify a server even without a CA-signed cert (CA path is also supported).
- Connection establishment cost: **3 RTTs** (vs 6 for WebSocket+Noise+Yamux).
- Uses Noise on top of QUIC streams; multiplexing comes from QUIC native streams (no Yamux/Mplex needed).
- Spec: <https://github.com/libp2p/specs/tree/master/webtransport>.

### 4.2 libp2p WebRTC private-to-private (browser ↔ browser)

- Uses a public libp2p relay node only as a **signaling channel** (not as a TURN server, not relaying media).
- Flow:
  1. Both browsers connect to a relay (over WebTransport, WebSocket-secure, or another browser-reachable transport).
  2. Initiator opens a libp2p stream to the responder over the relayed connection running the `/libp2p/webrtc/signaling/0.0.1` protocol.
  3. Both sides exchange SDP offer/answer and ICE candidates over that stream.
  4. Browsers' WebRTC stacks negotiate a direct DTLS-encrypted SCTP channel.
  5. The relay drops out of the data path; all subsequent traffic is direct browser-to-browser.
- Multiaddr form (advertised via DHT/PubSub): `/ip4/<relay-ip>/udp/<port>/quic-v1/webtransport/.../p2p/<relay-peer-id>/p2p-circuit/webrtc/p2p/<remote-peer-id>`.
- Spec: <https://github.com/libp2p/specs/blob/master/webrtc/webrtc.md>.

### 4.3 libp2p WebRTC-direct (browser → server, no relay)

- Browser dials a server's listening UDP port.
- Server presents a self-signed certificate; browser pins it via `certhash` in the multiaddr (same trust model as WebTransport).
- Multiaddr: `/ip4/<ip>/udp/<port>/webrtc-direct/certhash/<mh>/p2p/<peerid>`.
- Useful for bootstrapping a browser into the network without any TLS-CA infrastructure.

### 4.4 Browser APIs we must wrap

- **WebTransport**: `globalThis.WebTransport` (Chrome 97+, Firefox 114+, Safari 16.4+ behind flag earlier; broadly available 2025+).
- **WebRTC**: `RTCPeerConnection`, `RTCDataChannel`, `RTCSessionDescription`, `RTCIceCandidate`.
- Both must be accessed via `package:web` (already in `pubspec.yaml`) or `dart:js_interop`. No `dart:html`.

---

## 5. Architecture Changes

### 5.1 Upstream `ipfs_libp2p` (the bigger lift)

Two new transport implementations need to exist in the upstream package. Both implement `libp2p.Transport` so `Libp2pRouter._buildTransports()` can register them like `TCPTransport`.

```text
ipfs_libp2p/
├── lib/p2p/transport/
│   ├── tcp_transport.dart                  (existing)
│   ├── webtransport/
│   │   ├── webtransport_transport.dart     (NEW)
│   │   ├── webtransport_listener.dart      (NEW, Dart VM only)
│   │   ├── webtransport_dialer_web.dart    (NEW, conditional import)
│   │   ├── webtransport_dialer_io.dart     (NEW, conditional import)
│   │   ├── certhash.dart                   (NEW, multihash helpers)
│   │   └── multiaddr_parser.dart           (NEW)
│   └── webrtc/
│       ├── webrtc_transport.dart           (NEW, private-to-private)
│       ├── webrtc_direct_transport.dart    (NEW, browser→server)
│       ├── signaling_protocol.dart         (NEW, /libp2p/webrtc/signaling/0.0.1)
│       ├── peer_connection_web.dart        (NEW)
│       ├── peer_connection_io.dart         (NEW, via flutter_webrtc or stub)
│       ├── data_channel_stream.dart        (NEW, P2PStream<Uint8List> adapter)
│       └── ice_config.dart                 (NEW, STUN servers list)
```

### 5.2 Downstream `dart_ipfs`

Changes needed in this repo are smaller — mostly configuration plumbing, replacing the stub router, and adding tests.

```text
dart_ipfs/
├── lib/src/
│   ├── core/config/
│   │   └── network_config.dart            (UPDATE — add transport flags, listen-addr defaults)
│   ├── core/ipfs_node/
│   │   └── ipfs_web_node.dart             (UPDATE — replace WebStubRouter with Libp2pRouter)
│   └── transport/
│       └── libp2p_router.dart             (UPDATE — _buildTransports activates WebTransport/WebRTC)
├── doc/
│   └── plans/WEBRTC_WEBTRANSPORT_PLAN.md  (THIS FILE)
└── test/
    ├── transport/
    │   ├── webtransport_dial_test.dart     (NEW)
    │   ├── webrtc_signaling_test.dart      (NEW)
    │   └── browser_to_browser_test.dart    (NEW, runs in Chrome via dart test -p chrome)
    └── e2e/
        └── browser_full_node_test.dart     (NEW, replaces stub)
```

### 5.3 NetworkConfig surface

```dart
class NetworkConfig {
  // ...existing fields...

  /// Enables WebTransport listener (Dart VM) and dialer (Web + VM).
  final bool enableWebTransport;

  /// Enables WebRTC private-to-private (browser↔browser) and WebRTC-direct.
  final bool enableWebRtc;

  /// Public libp2p peer used as a signaling relay for browser↔browser WebRTC.
  /// If empty, browser↔browser is disabled but browser↔server still works.
  final List<String> webRtcSignalingRelays;

  /// Override the default STUN server list.
  final List<String> stunServers;
}
```

`defaultListenAddresses` gains entries that depend on platform:

- **VM**: keep TCP, add `/ip4/0.0.0.0/udp/4002/quic-v1/webtransport`, add `/ip4/0.0.0.0/udp/4003/webrtc-direct`.
- **Web**: empty listen addresses (browsers can't listen); rely on relay reservation for inbound dials.

---

## 6. Phased Implementation Plan

The work is broken into six phases. Phases 1–3 are upstream (`ipfs_libp2p`); phases 4–6 are downstream (`dart_ipfs`).

### Phase 1 — WebTransport dialer (browser → server) | _2 weeks_

**Upstream:** `ipfs_libp2p`

- [ ] Implement `WebTransportTransport` class implementing the libp2p `Transport` interface.
- [ ] Browser dialer using `package:web` to access `globalThis.WebTransport`.
- [ ] Multiaddr parser for `/quic-v1/webtransport/certhash/<mh>/...` (with multibase-encoded multihashes).
- [ ] Verify server cert hash against the `certhash` components in the multiaddr.
- [ ] Wrap WebTransport bidirectional streams as `libp2p.P2PStream<Uint8List>`.
- [ ] Run Noise handshake on the first stream (security upgrade).
- [ ] Use QUIC native streams as the muxer (no Yamux).
- [ ] Unit tests against a fixture WebTransport server (Node `js-libp2p`).

**Exit criteria:** A Dart Web app can dial a known js-libp2p WebTransport server and exchange a Bitswap message.

### Phase 2 — WebTransport listener (server) | _2 weeks_

**Upstream:** `ipfs_libp2p`

- [ ] Pick a Dart VM HTTP/3 backend. Options:
  - **A**: FFI to `quiche` (Cloudflare's QUIC, mature, but adds a native dependency — see §8 risks).
  - **B**: FFI to `msquic` (Microsoft).
  - **C**: Pure-Dart QUIC (only `dart_quic` exists in alpha — likely unviable in scope).
  - **Decision:** start with `quiche` via `package:quiche_dart` if maintained, else write a minimal FFI binding.
- [ ] Generate self-signed ECDSA P-256 cert at startup, persist in keystore, export multihash for advertising.
- [ ] Build `WebTransportListener` exposing accept-connection stream.
- [ ] Integrate with `Libp2pRouter._buildTransports()` when `enableWebTransport == true`.
- [ ] Update DHT/identify advertisement to include the new listen multiaddr.
- [ ] Integration test: VM node listens, Chrome browser dials via Phase 1 client.

**Exit criteria:** A Dart VM node listens on WebTransport, advertises the multiaddr via DHT, and accepts a real connection from a Dart Web browser node.

### Phase 3 — WebRTC private-to-private | _3 weeks_

**Upstream:** `ipfs_libp2p`

- [ ] Implement `/libp2p/webrtc/signaling/0.0.1` protocol handler.
- [ ] Browser-side `RTCPeerConnection` wrapper using `package:web` JS interop.
- [ ] SDP munging: replace `a=fingerprint` with the libp2p-required SHA-256 fingerprint that ties the DTLS identity to the libp2p PeerId.
- [ ] Run Noise handshake over the first SCTP DataChannel (the spec requires this, even though DTLS already encrypts).
- [ ] Map each `RTCDataChannel` to a `libp2p.P2PStream<Uint8List>`.
- [ ] Reuse the relay `Reservation` infrastructure already present in `circuit_relay_client_*.dart`.
- [ ] Implement `WebRTCDirectTransport` (browser→server, no relay) — shares 80% of the code with private-to-private but uses HTTP for SDP exchange instead of a libp2p stream.

**Exit criteria:** Two Chrome instances running `dart_ipfs` each connect to a public libp2p relay, exchange SDP via the relay, and establish a direct WebRTC data-channel that successfully runs Bitswap.

### Phase 4 — `Libp2pRouter` integration | _1 week_

**Downstream:** `dart_ipfs`

- [ ] Update `_buildTransports()` in `@c:\Users\Eduardo\ipfs\lib\src\transport\libp2p_router.dart:591` to register WebTransport / WebRTC transports based on `NetworkConfig` flags.
- [ ] Surface new `NetworkConfig` fields per §5.3.
- [ ] Update `defaultListenAddresses` to be platform-aware.
- [ ] Wire transport selection through the `IpfsConfig.fromJson` codepath.
- [ ] Make sure `Libp2pRouter` works correctly when bumped to the new `ipfs_libp2p` version.

### Phase 5 — Web node migration | _1 week_

**Downstream:** `dart_ipfs`

- [ ] Replace `WebStubRouter` usage in `@c:\Users\Eduardo\ipfs\lib\src\core\ipfs_node\ipfs_web_node.dart:42` with a real `Libp2pRouter` configured for `enableWebTransport: true, enableWebRtc: true`.
- [ ] Provide sensible default signaling relays (e.g., Protocol Labs public bootstrappers that support WebRTC signaling, plus a self-hosted fallback documented in the README).
- [ ] Delete the `WebStubRouter` class in the same file (lines 247–248) once nothing references it.
- [ ] Replace mock DHT (`MockDHTHandler`) with `DelegateDHTHandler` against an HTTP delegated routing endpoint, since browsers can't run a full DHT server. Keep `MockDHTHandler` for tests only.

### Phase 6 — Testing, docs, telemetry | _1 week_

**Downstream:** `dart_ipfs`

- [ ] Browser tests: `dart test -p chrome` with two-browser harness for browser↔browser scenarios.
- [ ] Update `@c:\Users\Eduardo\ipfs\doc\ARCHITECTURE.md:49` to reflect new transports as **shipped**, not "soon".
- [ ] Update `README.md` Multi-Platform Support table to show full Web P2P columns.
- [ ] Update `ROADMAP.md` v1.11 entries to ✅.
- [ ] Add WebTransport / WebRTC handshake metrics to `MetricsCollector`.
- [ ] Add `example/web_p2p_chat.dart` — minimal browser-to-browser app.
- [ ] Update `CHANGELOG.md` with v1.11 entry.

---

## 7. Testing Strategy

### 7.1 Unit tests

- Multiaddr parsing for `/webtransport/certhash/...` and `/webrtc/...` forms.
- Certhash verification against fixture certificates.
- SDP munging utilities (libp2p fingerprint injection).

### 7.2 Integration tests

- VM ↔ VM: WebTransport using two Dart VM processes.
- Web ↔ VM: Chrome `dart test -p chrome` connecting to a VM listener.
- Web ↔ Web: Two Chrome instances + a VM running as relay.

### 7.3 Cross-implementation tests

- Dial a public `js-libp2p` peer via WebTransport. Use `bootstrap.libp2p.io` if it exposes a WebTransport listener; otherwise spin up `js-libp2p` in CI.
- Be dialed by `js-libp2p` to verify the listener side.
- Verify Bitswap block exchange across the new transport (not just connection establishment).

### 7.4 Coverage target

The `dart_ipfs` test coverage gate stays at **88.7% → ≥90%** post-feature. New transport code should ship with **≥85% line coverage** of the dart_ipfs side; the upstream library has its own coverage policy.

---

## 8. Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | No mature pure-Dart QUIC/HTTP-3 stack for the **server side** | High | High | Use FFI to `quiche`. If too heavy, defer Phase 2 listener and ship browser→server only initially using public js-libp2p WebTransport listeners as bootstrappers. |
| R2 | `package:web` JS interop shape changes between Dart SDK versions | Medium | Low | Pin to current Dart SDK minor; add CI matrix on stable + beta. |
| R3 | WebRTC SDP munging is fragile across browsers | Medium | Medium | Test on Chrome, Firefox, Safari. Track `js-libp2p`'s SDP normalizer as the reference and mirror its behavior. |
| R4 | Default signaling relays go down or rate-limit `dart_ipfs` users | Medium | Medium | Document how to run a private relay; ship a `relay_node_example.dart`. |
| R5 | Increase in binary size from FFI dependencies (Phase 2) | Low | Medium | Make `quiche` optional via a separate `dart_ipfs_quic` package; the listener side becomes opt-in. |
| R6 | NAT traversal still fails for symmetric NAT users on WebRTC private-to-private | Low | Medium | Document fallback to circuit-relay-only data path; AutoNAT already detects symmetric NAT. |
| R7 | Upstream `ipfs_libp2p` is not yet at 1.0 — breaking changes possible during this work | Medium | High | Coordinate via single PR per phase; gate on upstream version bumps; hold an internal fork branch if needed. |

---

## 9. Success Criteria

The milestone is considered complete when **all** of the following are true:

1. ✅ A pure-browser `IPFSWebNode` can connect to at least one node on the public IPFS network and successfully `cat` a CID it doesn't have locally.
2. ✅ Two browsers running `dart_ipfs` exchange a block via Bitswap over a direct WebRTC connection (not relayed).
3. ✅ A Dart VM node listens on WebTransport, advertises the multiaddr via DHT, and accepts a connection from `js-libp2p`.
4. ✅ `WebStubRouter` and `MockDHTHandler` are removed from production paths (kept only in test helpers).
5. ✅ `dart analyze` passes with 0 issues; `dart test` (VM) and `dart test -p chrome` (Web) both pass.
6. ✅ Coverage ≥90% overall.
7. ✅ Documentation, README, ROADMAP, and CHANGELOG reflect the new state.
8. ✅ A new `example/web_p2p_chat.dart` demonstrates a real browser↔browser app and is referenced from the README.

---

## 10. Timeline

| Phase | Description | Effort | Cumulative |
| --- | --- | --- | --- |
| 1 | WebTransport dialer (browser→server) | 2w | 2w |
| 2 | WebTransport listener (server) | 2w | 4w |
| 3 | WebRTC private-to-private + WebRTC-direct | 3w | 7w |
| 4 | `Libp2pRouter` integration | 1w | 8w |
| 5 | Web node migration | 1w | 9w |
| 6 | Testing, docs, telemetry | 1w | 10w |
| **Total** | | | **~10 weeks** |

Targeting the v1.11 release by end of Q2 2026 (June 30, 2026). Phases 1–3 can run partially in parallel if upstream contributors can be parallelized; otherwise they are sequential because Phase 3 depends on at least one browser-reachable transport (Phase 1) being available for the signaling relay.

---

## 11. Open Questions

- **Q1:** Should the WebTransport listener be in `ipfs_libp2p` itself, or in a sibling package `ipfs_libp2p_quic` to keep the QUIC FFI optional? **Proposed:** sibling package.
- **Q2:** What's the policy for shipping default STUN servers? Use Google's public STUN, Cloudflare's, or self-hosted? **Proposed:** Google + Cloudflare with override via `NetworkConfig`.
- **Q3:** Do we need a TURN fallback for symmetric NAT users? **Proposed:** No — symmetric NAT users keep using circuit-relay v2 as the data path (already shipping).
- **Q4:** Should `IPFSWebNode` and `IPFSNode` converge into a single class once the web node has real networking? **Proposed:** Yes, post-v1.11 cleanup — track as separate refactor.

---

## 12. References

- libp2p WebTransport spec: <https://github.com/libp2p/specs/tree/master/webtransport>
- libp2p WebRTC spec: <https://github.com/libp2p/specs/blob/master/webrtc/webrtc.md>
- libp2p WebRTC concept docs: <https://docs.libp2p.io/concepts/transports/webrtc/>
- WebTransport in libp2p (blog): <https://libp2p.io/docs/webtransport/>
- WebRTC private-to-private with js-libp2p: <https://libp2p.io/docs/webrtc-browser-connectivity/>
- `js-libp2p` reference implementations: <https://github.com/libp2p/js-libp2p>
