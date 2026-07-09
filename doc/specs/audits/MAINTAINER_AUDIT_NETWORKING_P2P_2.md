# Project Review — Networking & P2P Feature Specifications (Batch 2)

**Document:** `MAINTAINER_AUDIT_NETWORKING_P2P_2.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_NETWORKING_P2P_2.md`  
**Date:** 2026-06-25  
**Audited Specifications:**

1. `CIRCUIT_RELAY_SPEC.md`
2. `BROWSER_TRANSPORTS_SPEC.md`
3. `GRAPHSYNC_SPEC.md`
4. `BITSWAP_HTTP_FALLBACK_SPEC.md`
5. `GATEWAY_TLS_SPEC.md`

**Review Lenses:**

- **Coherence:** Does the specification fit the existing dart_ipfs architecture and code paths?
- **Capability:** Does it specify a genuine, non-redundant capability expansion?
- **Safety:** What are the risks, attack vectors, and veto-worthy issues?
- **Efficiency:** Is it lean, focused, and performant, or bloated?
- **Evolution:** Does it advance dart_ipfs toward Kubo/Helia parity and superiority?

**Scoring:** 0-10 per lens.  
**Verdict Thresholds:**

- **PASS:** at least 3 scores ≥ 6 and Safety > 3.
- **CONDITIONAL:** minor issues that must be resolved before implementation begins.
- **DEFER:** not ready for implementation; requires significant rework or dependencies.
- **REJECT:** Safety ≤ 3 or a majority of scores below threshold.

---

## Executive Summary

| Specification | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|---------------|-----------|------------|--------|------------|-----------|---------|
| CIRCUIT_RELAY_SPEC.md | 7 | 9 | 7 | 7 | 8 | **PASS** |
| BROWSER_TRANSPORTS_SPEC.md | 6 | 7 | 8 | 6 | 8 | **CONDITIONAL** |
| GRAPHSYNC_SPEC.md | 6 | 7 | 7 | 7 | 7 | **CONDITIONAL** |
| BITSWAP_HTTP_FALLBACK_SPEC.md | 7 | 8 | 7 | 7 | 7 | **PASS** |
| GATEWAY_TLS_SPEC.md | 7 | 8 | 8 | 7 | 8 | **PASS** |

**Cross-Cutting Findings:**

- All five specifications reference the correct official libp2p/IPFS specs and protocol IDs.
- Three specifications (`BROWSER_TRANSPORTS_SPEC.md`, `GRAPHSYNC_SPEC.md`, `GATEWAY_TLS_SPEC.md`) contain significant external-dependency risks that are not fully acknowledged: Dart has no mature WebTransport IO API, no spec-compliant IPLD selector implementation yet (a P0 dependency), and no published ACME client package.
- The `RouterInterface` already provides unicast message delivery via `sendMessage(String peerIdStr, Uint8List message, {String? protocolId})`, but `GRAPHSYNC_SPEC.md` incorrectly assumes unicast is unsupported and adds a misleading `supportsUnicast` guard.
- Two specifications reference file paths that have moved since the specifications were written (`circuit_relay_client.dart` and `http_gateway_client.dart`).
- Safety is generally sound across all five specs; no veto-worthy security defects were found.

---

## 1. CIRCUIT_RELAY_SPEC.md — Circuit Relay v2 Client Dialing

**Scores:**

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | Correctly identifies the existing `CircuitRelayClient` and `RouterInterface` integration points. The protocol ID (`/libp2p/circuit/relay/0.2.0/hop`) and message flow are accurate. However, the specification does not explain how a relayed stream is upgraded to a `Conn` and injected into `RouterInterface.connectedPeers`, which is a critical gap because `RouterInterface` exposes no method to register a manually constructed connection. The referenced file path `lib/src/protocols/relay/circuit_relay_client.dart` is incorrect; the actual file is `lib/src/transport/circuit_relay_client.dart`. |
| Capability | 9 | Client-side Circuit Relay v2 is a genuine capability gap. The current `CircuitRelayClient.reserve` exists but the `connect` method simply calls `_router.connect(peerId)`, which is not relayed dialing. The specification correctly limits scope to client dialing and defers relay server (hop) and AutoRelay, avoiding redundancy. |
| Safety | 7 | The security section covers reservation limits, expiry, private IP blocking, relay PeerId validation, and mandatory security handshakes. It omits relay status-code handling, resource-manager integration, and metadata leakage (the relay learns both endpoint PeerIds). No veto-worthy issue. |
| Efficiency | 7 | Scope is narrow: RESERVE + CONNECT + refresh. However, it does not define circuit reuse, connection pooling, or how `maxCircuits` is enforced. The refresh interval is under-specified. |
| Evolution | 8 | Circuit Relay v2 is required for NAT traversal and browser interoperability. This directly advances Kubo/Helia parity. |

**Overall Verdict:** PASS

**Strengths:**

- Official reference links are accurate and complete.
- Non-goals are well scoped: relay server, AutoRelay, and relayed listener are correctly deferred.
- Acceptance criteria are concrete and testable against a Kubo relay.
- The reservation state machine is clear.

**Weaknesses:**

- No concrete design for bridging the relayed stream to the existing `ipfs_libp2p` transport abstraction.
- `RouterInterface` is not extended to accept an injected relayed connection; the requirement to expose it in `connectedPeers` is not actionable without an API change.
- Missing handling of Circuit Relay v2 status codes (`NO_RESERVATION_SLOT`, `RESOURCE_LIMIT_REACHED`, `CONNECTION_FAILED`, etc.).
- Missing resource-manager integration (`maxCircuits` enforcement is not defined).
- The `CircuitRelayConfig` class is introduced without specifying where it is wired into `IPFSConfig` or `NetworkConfig`.
- Outdated file path reference.

**Recommendations:**

1. Add an explicit `RouterInterface` extension (e.g., `Future<void> registerConnection(Connection conn)` or `Future<void> connectThroughRelay(...)`) and define how `Libp2pRouter` will bridge it to `ipfs_libp2p`.
2. Document the mapping of every Circuit Relay v2 status code to a dart_ipfs error and metric.
3. Integrate `maxCircuits` with the `ResourceManagerImpl` used in `Libp2pRouter.start`.
4. Specify where `CircuitRelayConfig` is stored and how it is parsed from JSON/YAML.
5. Fix the file path reference to `lib/src/transport/circuit_relay_client.dart`.
6. Add a security note on relay metadata visibility and per-relay bandwidth limits.

**Missing References / Acceptance Criteria:**

- Reference to the Circuit Relay v2 status code table.
- Acceptance criterion for handling `RESOURCE_LIMIT_REACHED` and `NO_RESERVATION_SLOT`.
- Acceptance criterion for relayed connection teardown on `RouterInterface.stop`.
- Acceptance criterion for verifying that the security handshake is completed over the relayed stream (not just the relay hop).

---

## 2. BROWSER_TRANSPORTS_SPEC.md — Browser Transport Hardening

**Scores:**

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 6 | The spec correctly identifies the current gaps: stub WebTransport IO listener, missing certhash validation, hardcoded Google STUN, and incomplete `Conn` metadata. However, it proposes a non-web `WebTransportListener` that binds a UDP socket and accepts QUIC WebTransport sessions. Standard Dart/IO does not provide a WebTransport API; this would require a custom QUIC + WebTransport stack or FFI bindings that do not currently exist in the project. The spec acknowledges platform unavailability but still requires the implementation, which is unrealistic. Additionally, the `WebTransportConn` and `WebRTCConn` metadata API shown does not match the `libp2p.Conn` interface from `ipfs_libp2p` (which exposes `localMultiaddr`, `remoteMultiaddr`, `stat`, `scope`, etc., not `metadata`). |
| Capability | 7 | Certhash validation and configurable STUN/TURN are genuine, necessary improvements. The non-web WebTransport IO listener adds little value in the current Dart ecosystem and is mostly a capability stub. |
| Safety | 8 | Certhash validation is fail-closed. Removing hardcoded public STUN servers from production defaults is correct. TURN credential handling and local-address privacy are addressed. The safety section is the strongest part of this specification. |
| Efficiency | 6 | The specification bundles four distinct concerns: WebTransport dialer, WebTransport IO listener, WebRTC STUN/TURN hardening, and `Conn` metadata. This is too broad for a single implementation unit. The IO listener scope is inefficient relative to its value. |
| Evolution | 8 | Browser transports are essential for parity with Helia/js-libp2p. Kubo also supports WebTransport. Removing the hardcoded STUN server is a clear superiority improvement. |

**Overall Verdict:** CONDITIONAL

**Strengths:**

- The certhash validation flow is correct and security-first.
- Correctly calls out the hardcoded `stun:stun.l.google.com:19302` in `lib/src/transport/webrtc/webrtc_transport.dart` (lines 71 and 228) as a production anti-pattern.
- Configurable STUN/TURN fields in `NetworkConfig` are well specified.
- Official references include the W3C WebTransport API and RFC 9000 QUIC.

**Weaknesses:**

- The non-web WebTransport IO listener is not feasible with current Dart/IO and the project's dependencies. It should not be a P1 requirement.
- The `Conn` metadata section conflates the custom `Conn` concept with the `libp2p.Conn` interface from `ipfs_libp2p`. The specification should state which concrete `libp2p.Conn` fields (`stat`, `scope`, etc.) must be implemented, rather than inventing a new `metadata` map.
- The WebTransport dialer implementation in `lib/src/transport/webtransport/webtransport_dialer_web.dart` currently sets `hash.value = Uint8List(32).toJS` (line 31) instead of the actual decoded certhash; the spec must require fixing this bug as part of certhash validation.
- No concrete dependency is named for WebTransport IO support.
- WebRTC metadata is underspecified; exposing ICE/signaling state is not sufficient for production diagnostics.

**Recommendations:**

1. Remove the non-web `WebTransportListener` requirement from this specification. Defer it to a P2 spec or mark it as a browser-only feature.
2. Rename the specification to focus on "WebTransport Browser Dialer + WebRTC STUN/TURN Hardening" to reflect the real scope.
3. Rewrite the `Conn` metadata section to align with the `libp2p.Conn` interface from `ipfs_libp2p`. Specify exactly which `UnimplementedError` throws must be eliminated (`stat`, `scope`, etc.) and what values they should return.
4. Add an explicit requirement to fix the dummy certhash value in `webtransport_dialer_web.dart` line 31 and to validate the returned server certificate hashes against the multiaddr.
5. Add WebRTC privacy guidance: STUN/TURN allowlists, IP-leakage warnings, and TURN TLS validation.

**Missing References / Acceptance Criteria:**

- Reference to the libp2p WebRTC and WebRTC-direct specifications.
- Reference to W3C `WebTransportHash` / `serverCertificateHashes` semantics.
- Acceptance criterion that the browser WebTransport dialer rejects the connection when the server certhash does not match.
- Acceptance criterion that no hardcoded `stun.l.google.com` string remains in production code (a CI lint check is already mentioned and should be retained).
- Acceptance criterion for graceful degradation on platforms without WebTransport APIs (browser-only vs. IO stub behavior).

---

## 3. GRAPHSYNC_SPEC.md — Server-Side GraphSync MVP

**Scores:**

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 6 | The specification correctly identifies the broadcast bug in `GraphsyncHandler._sendResponse` (`lib/src/protocols/graphsync/graphsync_handler.dart` lines 335-339) and the need to populate `GraphsyncMessage.blocks`. However, it introduces a `supportsUnicast` guard that does not exist on `RouterInterface` and is unnecessary because `RouterInterface.sendMessage(String peerIdStr, ...)` is already a unicast method. The current `Libp2pRouter.sendMessage` sends to a specific peer. This misunderstanding weakens the design guidance. The specification also depends on a spec-compliant IPLD selector implementation (`IPLDSelector.fromBytesAsync`, `_ipld.executeSelector`), which is a P0 dependency from `PROTOCOL_COMPLIANCE_SPEC.md` and is not yet implemented in the current `IPLDHandler`/`ipld_selector.dart`. The `_traverse` helper is undefined. |
| Capability | 7 | Server-side GraphSync responses with attached blocks are a genuine gap. The current handler only sends progress/completion metadata. The unicast requirement is correct. |
| Safety | 7 | Budgets for depth, block count, and bytes are good defenses. The spec mentions selector validation, CID verification, and concurrent request limits. However, the budget depth implementation shown (`enterDepth` increments a counter on every block) is incorrect for tree-depth tracking; it would count every visited node as a depth level. It also does not specify request authentication or per-peer rate limiting. |
| Efficiency | 7 | Server-side-only scope is focused. Unicast responses avoid wasting bandwidth on broadcast. However, synchronous Bitswap fallback for every missing block during traversal could block the response for a long time. Streaming block collection is not specified. |
| Evolution | 7 | GraphSync is supported by Kubo and advances DAG exchange efficiency. The MVP scope is reasonable for parity. |

**Overall Verdict:** CONDITIONAL

**Strengths:**

- Correctly scopes to server-side only and defers bidirectional pause/resume and client-side response matching.
- The broadcast-to-unicast fix is the highest-value change.
- Budget defaults (depth 32, 1024 blocks, 16 MiB) are reasonable for an MVP.
- Official references to the GraphSync and IPLD selector specs are correct.

**Weaknesses:**

- The `supportsUnicast` guard is a design error. `RouterInterface.sendMessage` already provides unicast; the implementation should simply use it.
- The specification depends on a spec-compliant IPLD selector implementation that is not yet available. This must be sequenced after the P0 IPLD selector work.
- The `_traverse` helper and budget depth logic are not defined with correct tree-depth semantics.
- `Block.prefix` construction is ambiguous. The prefix should be the CID prefix (version + codec + hash function + hash length), not the full CID bytes.
- The Bitswap fallback API shown (`_bitswap.getBlock(cid)`) does not exist; the current handler uses `wantBlock` and `want`.
- No handling for request ID deduplication or cancellation across multiple requests from the same peer.

**Recommendations:**

1. Remove the `supportsUnicast` guard and rewrite the requirement to use `RouterInterface.sendMessage(peerId, response, protocolId: ...)` directly.
2. Add an explicit dependency on the P0 IPLD selector specification; sequence GraphSync implementation after the selector implementation is complete.
3. Define the traversal algorithm precisely, including correct depth tracking (increment on entering a nested node, decrement on leaving) and streaming block collection.
4. Clarify that `Block.prefix` must be the CID prefix bytes (the first bytes of the CID before the digest), not the full CID.
5. Use the existing `BitswapHandler.wantBlock` or `want` API for fallback.
6. Add per-peer request concurrency limits and request ID deduplication.

**Missing References / Acceptance Criteria:**

- Reference to `PROTOCOL_COMPLIANCE_SPEC.md` section 4.6 (P0 IPLD selectors) as a hard blocker.
- Reference to GraphSync response status codes (`RS_FULL`, `RS_PARTIAL`, `RS_REJECTED`, `RS_COMPLETED`, etc.).
- Acceptance criterion that the response is sent only to the requesting peer (verified by not invoking `broadcastMessage`).
- Acceptance criterion for malformed selector rejection and for budget-exceeded responses.
- Acceptance criterion that the `Block.prefix` field is a valid CID prefix and that the combined `(prefix, data)` reconstructs the expected CID.

---

## 4. BITSWAP_HTTP_FALLBACK_SPEC.md — Bitswap HTTP Gateway Fallback

**Scores:**

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | The fallback flow (blockstore -> P2P -> HTTP) is clear and aligns with the existing `BitswapHandler` and `HttpGatewayClient`. The spec correctly identifies the missing HTTP fallback and the lack of CID verification for HTTP blocks. However, the referenced path for `HttpGatewayClient` is wrong (`lib/src/services/gateway/http_gateway_client.dart` vs. actual `lib/src/transport/http_gateway_client.dart`). The `BitswapConfig` class does not exist; `IPFSConfig` currently stores `maxConcurrentBitswapRequests` directly. The `_getBlockFromBitswap` method name does not match the current `wantBlock`/`want` API. |
| Capability | 8 | HTTP gateway fallback is a genuine availability improvement. It does not duplicate P2P functionality; it is a fallback after P2P failure. This is a common pattern in Helia and Kubo. |
| Safety | 7 | Mandatory CID verification is the correct security model. Gateway URL validation, response size limits, HTTPS preference, and private-range rejection are all specified. However, the `verifyHttpBlocks` flag is redundant and dangerous if verification is mandatory in production. The spec also does not address gateway fingerprinting or request metadata leakage. |
| Efficiency | 7 | Ordering is correct: local blockstore first, then P2P, then HTTP. Verified blocks are cached. However, sequential gateway iteration could be slow; no circuit breaker or per-gateway timeout tuning is specified. |
| Evolution | 7 | HTTP fallback improves availability and brings dart_ipfs closer to Helia's gateway retrieval and Kubo's `--gateway` options. It is a parity feature, not a differentiator. |

**Overall Verdict:** PASS

**Strengths:**

- Clear, well-ordered fallback flow.
- Security-first design with mandatory CID verification.
- Practical acceptance criteria including bad-gateway simulation.
- Correctly references the trustless gateway specification for `?format=raw`.

**Weaknesses:**

- `BitswapConfig` does not exist and must be created and wired into `IPFSConfig`.
- `HttpGatewayClient.fetchRawBlock` does not exist; the current client only has `get(String cid, {String? baseUrl})` and uses `https://gateway/ipfs/<cid>` without `?format=raw`.
- The `_verifyBlock` implementation is oversimplified. It does not specify how to select the multihash function from the CID or how to handle non-raw codecs (DAG-PB, DAG-CBOR, etc.) correctly.
- The `verifyHttpBlocks` flag is unnecessary if verification is mandatory. It should be removed or restricted to test overrides.
- No mention of gateway allowlists/denylists, request fingerprinting, or circuit breakers.
- Outdated file path reference.

**Recommendations:**

1. Create a `BitswapConfig` class and integrate it into `IPFSConfig` (or extend `NetworkConfig`). Migrate `maxConcurrentBitswapRequests` into it if appropriate.
2. Add `HttpGatewayClient.fetchRawBlock(String gatewayUrl, String cidStr)` and `fetchCar` methods that construct the correct trustless gateway URLs (`/ipfs/<cid>?format=raw` and `?format=car`).
3. Reuse the existing `Block.validate()` logic or the `dart_multihash` package for verification; specify the exact multihash function lookup from the CID.
4. Remove the `verifyHttpBlocks` production flag or make it a test-only `@visibleForTesting` override. Verification must be unconditional in production.
5. Add gateway privacy and fingerprinting guidance to the security section.
6. Add per-gateway timeout, retry count, and circuit-breaker configuration.

**Missing References / Acceptance Criteria:**

- Reference to the trustless gateway spec for `?format=raw` and `?format=car` (already present but should be explicit).
- Reference to Kubo's gateway fallback behavior.
- Acceptance criterion for SSRF/private-IP rejection (e.g., `localhost`, `127.0.0.1`, `10.0.0.0/8`).
- Acceptance criterion that the multihash of the returned bytes matches the CID multihash for raw, DAG-PB, and DAG-CBOR blocks.
- Acceptance criterion that a malicious gateway returning mismatched bytes is discarded and the next gateway is tried.

---

## 5. GATEWAY_TLS_SPEC.md — AutoTLS / TLS for WSS Gateway

**Scores:**

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | The specification correctly identifies the lack of TLS fields in `GatewayConfig` and the plain-HTTP `GatewayServer`. It uses `dart:io SecurityContext`, which is the correct Dart API. However, the gateway uses an `HttpServerAdapter` platform abstraction (`lib/src/platform/http_server.dart`) whose interface may not expose `SecurityContext`; the spec does not address how this adapter must be updated. AutoTLS depends on an ACME client package that is not currently in `pubspec.yaml` and may not be mature in the Dart ecosystem. WSS integration with the existing `shelf` router is also not specified. |
| Capability | 8 | TLS termination, HTTPS, and WSS are genuine production capabilities. Kubo supports AutoTLS and TLS gateway modes, so this is a parity feature. |
| Safety | 8 | The security section is strong: TLS 1.2+, disabled old protocols, explicit ToS acceptance, no logging of private keys, separate ACME keys, and protection of the challenge endpoint. It lacks certificate revocation, OCSP stapling, and HSTS headers. The risk of a writable gateway being exposed over TLS is not addressed. |
| Efficiency | 7 | The scope is focused on the gateway server. AutoTLS adds background certificate acquisition and renewal tasks, which is reasonable complexity for a production feature. |
| Evolution | 8 | HTTPS and WSS are essential for production gateways and browser deployments. AutoTLS advances parity with Kubo's AutoTLS feature. |

**Overall Verdict:** PASS

**Strengths:**

- Strong security-first defaults: AutoTLS is off by default and requires explicit ToS acceptance.
- Clear configuration model with operator-provided certificates and ACME paths.
- Good backward compatibility: plain HTTP continues to work when TLS is disabled.
- HTTP-to-HTTPS redirect is optional and off by default.

**Weaknesses:**

- AutoTLS relies on an unspecified ACME client package. No mature `acme_client` package is currently in the project's dependencies, and the spec does not provide a fallback design if the package is unavailable.
- The `HttpServerAdapter` abstraction must be extended to support `SecurityContext` before `GatewayServer` can use it; the spec does not address this.
- WSS upgrade support is not integrated with the current `shelf` router and `GatewayHandler`.
- Missing certificate revocation, OCSP, and HSTS considerations.
- No acceptance criteria for certificate renewal failure handling or expiry warnings.
- No mention of how writable gateway mode interacts with TLS exposure.

**Recommendations:**

1. Either split AutoTLS into a separate P2 specification or clearly mark it as dependent on selecting a mature Dart ACME client. If no such package exists, defer AutoTLS and implement operator-provided TLS only for v2.1.
2. Update `HttpServerAdapter` and the platform-specific implementations to accept a `SecurityContext` (or a TLS flag + certificate paths) and return the bound TLS port.
3. Define how WSS upgrades are handled by the `shelf` router and whether a separate WebSocket handler is required.
4. Add HSTS, OCSP, and revocation handling to the acceptance criteria.
5. Add a security note that `GatewayConfig.writable` should be disabled by default when exposing a public TLS gateway.
6. Add acceptance criteria for certificate expiry monitoring and renewal failure alerting.

**Missing References / Acceptance Criteria:**

- Reference to `dart:io SecurityContext` binding and whether it supports certificate passwords across all target platforms.
- Reference to ACME HTTP-01 challenge mechanics (RFC 8555).
- Reference to Kubo AutoTLS behavior.
- Acceptance criterion for binding HTTPS and WSS on the same port.
- Acceptance criterion for redirect behavior when `redirectHttpToHttps` is enabled.
- Acceptance criterion for handling certificate expiry within a configurable renewal window.

---

## Maintainer Recommendations and Implementation Order

1. **Proceed with `BITSWAP_HTTP_FALLBACK_SPEC.md` and `GATEWAY_TLS_SPEC.md` (operator-provided TLS only) after the minor corrections noted above.**
2. **Proceed with `CIRCUIT_RELAY_SPEC.md` after adding the missing `RouterInterface` integration design and status-code handling.**
3. **Hold `BROWSER_TRANSPORTS_SPEC.md` in CONDITIONAL status.** Remove or defer the non-web WebTransport IO listener and align the `Conn` metadata section with the `libp2p.Conn` interface before implementation begins.
4. **Hold `GRAPHSYNC_SPEC.md` in CONDITIONAL status.** Remove the `supportsUnicast` guard and sequence implementation after the P0 IPLD selector specification is complete. Define the traversal algorithm and CID-prefix semantics precisely.
5. **Defer AutoTLS to a separate spec** unless a reliable Dart ACME client is identified and added to the dependency list before implementation.

---

## Audit Metadata

- **Audit Authority:** project maintainers
- **Architecture Reviewed:** dart_ipfs v1.11.5 with `ipfs_libp2p` v0.5.6
- **Primary Architecture Documents:** `NETWORKING_P2P_SPEC.md`, `PROTOCOL_COMPLIANCE_SPEC.md`
- **Key Code Paths Reviewed:**
  - `lib/src/transport/router_interface.dart`
  - `lib/src/transport/libp2p_router.dart`
  - `lib/src/transport/circuit_relay_client.dart`
  - `lib/src/transport/circuit_relay_client_io.dart`
  - `lib/src/transport/webtransport/webtransport_transport.dart`
  - `lib/src/transport/webtransport/webtransport_dialer_web.dart`
  - `lib/src/transport/webtransport/webtransport_listener.dart`
  - `lib/src/transport/webrtc/webrtc_transport.dart`
  - `lib/src/protocols/bitswap/bitswap_handler.dart`
  - `lib/src/transport/http_gateway_client.dart`
  - `lib/src/protocols/graphsync/graphsync_handler.dart`
  - `lib/src/services/gateway/gateway_server.dart`
  - `lib/src/core/config/network_config.dart`
  - `lib/src/core/config/gateway_config.dart`
  - `lib/src/core/config/ipfs_config.dart`
  - `pubspec.yaml`
