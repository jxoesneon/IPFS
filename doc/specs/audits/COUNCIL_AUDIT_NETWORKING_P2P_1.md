# Ciel Council of Five Audit Report

## Networking / P2P Feature Specifications — Batch 1

**Audit Date:** 2026-06-25  
**Audited Documents:**

1. `REPROVIDE_SPEC.md` — Reprovide Strategies, DHT Provide Sweep, and On-Demand Provide
2. `QUIC_SPEC.md` — QUIC Transport
3. `GOSSIPSUB_SPEC.md` — Gossipsub v1.1 Compliance
4. `DHT_INTEGRATION_SPEC.md` — Amino DHT Network Integration
5. `IPNS_SPEC.md` — DHT-First Signed IPNS Records

**Council Lenses:**

- **Coherence:** does it fit the dart_ipfs architecture and existing code paths?
- **Capability:** does it specify a genuine, non-redundant capability expansion?
- **Safety:** what are the risks, attack vectors, and veto-worthy issues?
- **Efficiency:** is it lean, focused, and performant, or bloated?
- **Evolution:** does it advance dart_ipfs toward Kubo/Helia parity and superiority?

**Verdict Thresholds:**

- **PASS:** at least 3 scores >= 6 and Safety > 3.
- **CONDITIONAL:** meets the numeric threshold but has material gaps that must be closed before implementation.
- **DEFER:** not ready for the current release cycle.
- **REJECT:** Safety <= 3 or majority of scores below threshold.

---

## 1. REPROVIDE_SPEC.md

### 1.1 Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | The spec maps cleanly onto `DHTHandler` (`lib/src/protocols/dht/dht_handler.dart`), `DHTClient` (`lib/src/protocols/dht/dht_client.dart`), `PinManager` (`lib/src/core/data_structures/pin_manager.dart`), `MFSManager` (`lib/src/core/mfs/mfs_manager.dart`), `ILifecycle` (`lib/src/core/interfaces/i_lifecycle.dart`), and `LifecycleManager` (`lib/src/core/ipfs_node/lifecycle_manager.dart`). The current `provide()` method is indeed a no-feedback black box (`dht_handler.dart:302-309`). Deductions: the spec references a DHT "server mode" that does not exist in `DHTConfig` (`lib/src/core/config/dht_config.dart`), and it assumes a denylist/content-blocking service whose current presence is unclear. |
| Capability | 8 | Reprovide strategies (`pinned`, `roots`, `all`, `pinned+mfs`, `unique`, `entities`) are genuine Kubo-equivalent capabilities. On-demand provide refinement with `ProvideResult`, queueing, and recursive enumeration is a real expansion. The DHT Provide Sweep optimization is a non-redundant performance capability. |
| Safety | 6 | The 1000-item provide queue limit and metric-label safety rules are good. The `recursive=true` local-only traversal rule is correct. The spec acknowledges rate-limiting in `DHTHandler`. Concerns: the `all` strategy on a large blockstore can be used as a DHT amplification vector; the 80% overlap threshold for proximity grouping is stated without justification; and provider-record validation on the receiving side is delegated to `DHTHandler.handleProvideRequest`, which today only checks rate limits and provider counts, not content authenticity. |
| Efficiency | 7 | The XOR-ordered grouping and batching reduce DHT message volume. Default 12-hour interval matches Kubo. Deductions: six strategies overlap (`unique` is essentially `pinned` with explicit deduplication, which should be default behavior anyway), and `all` is inherently inefficient for large blockstores. |
| Evolution | 9 | Reprovide is a baseline requirement for public-network IPFS participation. The spec directly advances Kubo parity and adds measurable metrics. |

### 1.2 Overall Verdict

**PASS** — with the condition that the DHT mode/denylist assumptions and the `all` strategy bounds are clarified before implementation.

### 1.3 Strengths and Weaknesses

**Strengths**

- Builds on existing `DHTHandler.provide` and `DHTClient.addProvider` rather than introducing a parallel code path.
- Adds production-grade observability (`ipfs_dht_*` metrics) that aligns with the stub `MetricsCollector` (`lib/src/core/metrics/metrics_collector.dart`).
- Backward compatibility is explicit: existing `DHTHandler.provide(CID)` and `DHTClient.addProvider(String, String)` signatures remain valid.

**Weaknesses**

- References a DHT server/client mode that is not modeled in the current codebase (`DHTConfig` lacks `mode` or any equivalent).
- Depends on a content-blocking / denylist service that is not clearly implemented.
- The `all` strategy lacks a cap or block-store size guard; a naive implementation could spam the DHT with millions of provider records.
- The 80% overlap grouping threshold is arbitrary and not backed by a benchmark or reference.

### 1.4 Recommendations

1. **Remove or model the DHT mode assumption.** Either add `DHTMode { client, server, auto }` to `DHTConfig` or change the default rule to `reproviderEnabled = true when enableDHT is true`.
2. **Cap `all` strategy.** Add a `maxReprovideCids` safety limit to `DHTConfig` and document that operators can override it.
3. **Justify the grouping threshold.** Replace the magic 80% with a formula based on `bucketSize` and expected key-space distribution, or make it configurable.
4. **Strengthen receiver validation.** Require that `DHTHandler.handleProvideRequest` verify that the announcing peer actually claims to provide the CID and that the CID is not on the denylist before the reprovider is allowed to announce it.
5. **Define `once` semantics.** The on-demand `once` parameter is mentioned in the goal but is not in the parameter table or acceptance criteria; either add it or remove the reference.

### 1.5 Missing References and Acceptance Criteria

- **Missing reference:** Kubo reprovider implementation source (`go-libp2p-kad-dht` / `routing` package) for the exact strategy definitions and interval defaults.
- **Missing reference:** Amino DHT provider-record TTL and revalidation policy, because the spec states it is out of scope but the reprovider interval must still respect network TTL conventions.
- **Missing acceptance criterion:** Reprovider must be registered in `LifecycleManager` and start/stop cleanly under `IPFSNode.start()` / `IPFSNode.stop()` (`lib/src/core/ipfs_node/ipfs_node.dart:323-368`).
- **Missing acceptance criterion:** `MetricsCollector` must expose the `recordDhtProvide` / `recordReprovide` methods or the spec must define them as new interface additions.

---

## 2. QUIC_SPEC.md

### 2.1 Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 5 | The spec correctly identifies that `NetworkConfig.defaultListenAddresses` (`lib/src/core/config/network_config.dart:76-79`) advertises a QUIC/WebTransport address but `Libp2pRouter` (`lib/src/transport/libp2p_router.dart:160-171`) only instantiates `TCPTransport`, `WebTransportTransport`, `WebRTCTransport`, and `WebRTCDirectTransport`. The coherence problem is the dependency cliff: the spec does not verify whether `package:ipfs_libp2p` exposes a QUIC transport, and it proposes falling back to a custom Dart QUIC binding or FFI to `quiche`/`ngtcp2` without assessing the build/runtime cost on Dart VM, Flutter, and web targets. The proposed `RouterInterface` additions (`supportsQuic`, `connect()` returning `bool`) conflict with the current interface where `connect()` returns `void` (`lib/src/transport/router_interface.dart:53-56`). |
| Capability | 8 | Native QUIC transport is a genuine capability that Kubo and modern Helia nodes use. It enables 0-RTT dialing, stream multiplexing, and future WebTransport hardening. The non-goals (WebTransport separately, no raw QUIC, no mid-session migration) keep the scope focused. |
| Safety | 6 | TLS 1.3 and Noise handshakes are the correct security model. PeerId-bound certificate validation is required. The fallback to TCP prevents a total connectivity loss if QUIC fails. Concern: `preferQuic` defaults to `true`, which is risky when the underlying QUIC dependency is unproven; a safer default is `false` for v2.1 until interop is proven in CI. |
| Efficiency | 7 | QUIC is intrinsically efficient for P2P. Deductions: the fallback wrapper adds complexity, and the dependency on FFI bindings would introduce build and binary-size overhead that the spec does not quantify. |
| Evolution | 9 | QUIC is a first-class transport in the modern libp2p stack. Adding it is a major step toward parity and is a prerequisite for robust WebTransport. |

### 2.2 Overall Verdict

**CONDITIONAL** — the specification is directionally correct but contains a dependency/implementation gap that must be closed before work begins. Numeric threshold is met (4/5 scores >= 6, Safety = 6), but the architectural uncertainty is too large for an unqualified PASS.

### 2.3 Strengths and Weaknesses

**Strengths**

- Clear multiaddr formats (`/quic-v1`) and listen-address templates.
- Explicit TCP fallback path preserves backward compatibility.
- Security section correctly ties certificate validation to `PeerId` and avoids cleartext QUIC.
- Interop matrix with Kubo is concrete and testable.

**Weaknesses**

- No evidence that `package:ipfs_libp2p` provides a QUIC transport. The entire specification hinges on a dependency investigation that is not documented.
- The proposed custom Dart QUIC binding / FFI fallback is a massive undertaking that is glossed over in a single sentence.
- `RouterInterface` changes are not reconciled with the existing `connect()` contract.
- The spec claims QUIC is "P0 Approved" but the dependency availability is a clear blocker.

### 2.4 Recommendations

1. **Prove the dependency before implementation.** Add a spike task: list the exported symbols of `package:ipfs_libp2p` and confirm whether a QUIC transport class exists. If it does not, either bump QUIC to a later release or create a separate `QUIC_TRANSPORT_RFC.md` evaluating FFI options.
2. **Default `preferQuic` to `false`.** Enable opt-in dialing until Kubo/Helia interop tests pass in CI for at least one release cycle.
3. **Update `RouterInterface` explicitly.** Add `supportsQuic` and change `connect()` to return a result/status, or keep the interface change local to `Libp2pRouter` and do not promise it across all router implementations.
4. **Quantify the build/runtime cost.** If FFI to `quiche`/`ngtcp2` is the fallback, document supported platforms, binary-size impact, and CI requirements.
5. **Order dependency.** This spec should be sequenced after `DHT_INTEGRATION_SPEC.md` and `GOSSIPSUB_SPEC.md` are stable, because transport failures will mask DHT and PubSub interop failures during debugging.

### 2.5 Missing References and Acceptance Criteria

- **Missing research:** `package:ipfs_libp2p` QUIC transport availability and API surface.
- **Missing reference:** libp2p QUIC security handshake details (TLS 1.3 + Noise selection logic) for multiaddr negotiation.
- **Missing acceptance criterion:** A CI job that runs the Kubo QUIC interop matrix on every PR touching `lib/src/transport`.
- **Missing acceptance criterion:** Build-size and platform matrix if FFI fallback is chosen.
- **Missing acceptance criterion:** Behavior when `enableQuic` is true but the dependency is missing at runtime: startup must not crash; TCP-only mode must be selected with a logged warning.

---

## 3. GOSSIPSUB_SPEC.md

### 3.1 Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | The spec accurately describes the existing `PubSubClient` (`lib/src/protocols/pubsub/pubsub_client.dart`) as a custom JSON/HMAC wire format incompatible with libp2p Gossipsub. The `RouterInterface` generic protocol registration surface is correctly identified. The proposed `GossipsubHandler` API is a reasonable fit. Deductions: the relationship between the new `GossipsubHandler` and the existing `PubSubHandler` (`lib/src/core/ipfs_node/pubsub_handler.dart`) / `PubSubClient` is slightly muddled. The spec says "Keep `PubSubClient` as a thin shim that delegates to `GossipsubHandler`", but today `PubSubHandler` is the shim and `PubSubClient` is the implementation; reversing this requires careful re-wiring in `IPFSNodeBuilder` (`lib/src/core/builders/ipfs_node_builder.dart:88-92`). |
| Capability | 9 | Replacing a non-interoperable custom PubSub with wire-compatible Gossipsub v1.1 is a major capability expansion. It enables Kubo/Helia interop and the future IPNS PubSub notification path. |
| Safety | 8 | Strict peer-key signing, SHA-256 message IDs, peer scoring with decay and caps, topic limits, and UTF-8 validation are all correct. The spec correctly states that invalid messages must not be forwarded. |
| Efficiency | 8 | Gossipsub v1.1 is the standard efficient pub/sub protocol for libp2p. The mesh degree parameters (`d`, `dLow`, `dHigh`) and gossip factor are standard. The spec avoids encryption-at-the-pubsub-layer bloat. |
| Evolution | 9 | Gossipsub is essential for IPNS real-time notifications and for participating in the broader libp2p application ecosystem. This is a major parity step. |

### 3.2 Overall Verdict

**PASS** — with a recommendation to clarify the handler layering in `IPFSNodeBuilder`.

### 3.3 Strengths and Weaknesses

**Strengths**

- Correctly targets Gossipsub v1.1 (`/meshsub/1.1.0`) as the primary protocol.
- Protobuf wire format matches the canonical libp2p specification.
- Security defaults are strict (`signMessages = true`, `strictSign = true`).
- Acceptance criteria include interop with Kubo and Helia, plus invalid-signature penalization.

**Weaknesses**

- The proposed layering contradicts the current `PubSubHandler` -> `PubSubClient` relationship. The spec needs to state whether `PubSubHandler` will be rewritten to wrap `GossipsubHandler` or be deprecated.
- The protobuf definition includes a deprecated `subscriptions_` field; while copied from the libp2p spec, it should not be used in the implementation.
- Default `maxMessageSize = 1 MiB` is reasonable but should be enforced at the stream level before full buffer allocation to avoid memory pressure.
- Peer scoring defaults are listed but not tied to the existing `PubSubClient._scores` decay factor or to the v1.1 spec's recommended defaults.

### 3.4 Recommendations

1. **Clarify the handler architecture.** Document the final relationship: `PubSubHandler` wraps `GossipsubHandler`, or `PubSubHandler` is deprecated and `GossipsubHandler` becomes the `IPubSub` implementation. Update `IPFSNodeBuilder` wiring accordingly.
2. **Remove the deprecated `subscriptions_` field** from the generated protobuf usage; keep it only for wire compatibility if the generator requires it.
3. **Add memory-safe message-size enforcement.** Read the length prefix first, then cap the subsequent buffer read to `maxMessageSize` plus framing overhead.
4. **Map peer-score parameters to the libp2p v1.1 defaults.** Cite the exact default values from the libp2p Gossipsub v1.1 spec and make them the `PubSubConfig` defaults.
5. **Add a migration test.** Verify that the old `PubSubClient` JSON/HMAC format is rejected (not silently misinterpreted) by the new `GossipsubHandler`.

### 3.5 Missing References and Acceptance Criteria

- **Missing reference:** libp2p Gossipsub v1.1 default peer-score parameters (`topicScoreCap`, `meshMessageDeliveries`, etc.) and their exact numeric defaults.
- **Missing reference:** Dart protobuf `protoc` generation workflow currently used in the project (`lib/src/proto/generated/dht/`, etc.).
- **Missing acceptance criterion:** `PubSubHandler` API surface remains compatible with existing tests and dashboard usage while delegating to the new Gossipsub implementation.
- **Missing acceptance criterion:** A malformed old-format PubSub message is rejected with a clear log entry.
- **Missing acceptance criterion:** IPNS PubSub notifications are disabled until `GossipsubHandler` is compliant and `enablePubSubNotifications` is true.

---

## 4. DHT_INTEGRATION_SPEC.md

### 4.1 Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | The spec accurately describes the current gaps: `findProviders` is single-hop (`lib/src/protocols/dht/dht_client.dart:146-194`), `findPeer` is single-hop (`lib/src/protocols/dht/dht_client.dart:199-231`), peer addresses are encoded as UTF-8 strings (`lib/src/protocols/dht/dht_client.dart:108-123`), `_sendRequest` has no request correlation (`lib/src/protocols/dht/dht_client.dart:376-414`), and provider records are not validated. The proposed `DHTEnvelope` fallback is a pragmatic fit for the existing `RouterInterface`. Deductions: the spec adds `storeValue`/`getValue`/`reprovide` to `DHTClient` but `DHTHandler` already has `putValue`/`getValue` (`lib/src/protocols/dht/dht_handler.dart:112-143`), creating a potential duplication; and `maxProvidersPerKey` already exists in `DHTConfig` (`lib/src/core/config/dht_config.dart:11`). The iterative query pseudocode uses `closest.takeUnqueried(alpha, queried)`, which is not a method on Dart's `PriorityQueue`. |
| Capability | 9 | Iterative Kademlia queries, proper multiaddr encoding, request/response correlation, provider validation, and a reprovide sweep are all essential for public Amino DHT participation. These are genuine, non-redundant capabilities. |
| Safety | 7 | The spec addresses Sybil/eclipse resistance, record poisoning, amplification, address spoofing, and request flooding. It includes rate limiting and caps on in-flight requests. Deductions: server-side record signing enforcement is deferred, which leaves a known poisoning vector; the `isValidProviderRecord` sample only checks parseability and TTL, not content authenticity or provider ownership; and the reprovide sweep is bundled here while also being detailed in `REPROVIDE_SPEC.md`, creating overlap. |
| Efficiency | 7 | Iterative queries with `alpha` concurrency and bucket-based routing are standard and efficient. The reprovide sweep reduces redundant announcements. Deductions: the spec lacks detail on caching query results, routing-table persistence, and bucket refresh optimization. |
| Evolution | 9 | A working DHT client is the foundation for Bitswap content discovery, IPNS resolution, and provider routing. This is one of the highest-value parity items. |

### 4.2 Overall Verdict

**PASS** — with the condition that the duplication with `DHTHandler` and `REPROVIDE_SPEC.md` is resolved.

### 4.3 Strengths and Weaknesses

**Strengths**

- Precise, accurate gap analysis of the current `DHTClient`.
- Proposes a minimal, wire-compatible fix: multiaddr bytes instead of UTF-8 strings.
- Correctly identifies `RouterInterface` limitations and offers a `DHTEnvelope` workaround.
- Acceptance criteria are concrete and interop-testable against Kubo.

**Weaknesses**

- Overlaps significantly with `REPROVIDE_SPEC.md` on the reprovide sweep. Two specs should not own the same acceptance criteria.
- `DHTClient` `storeValue`/`getValue` duplicate `DHTHandler` `putValue`/`getValue`. The spec should state which layer owns persistence vs. network propagation.
- `maxProvidersPerKey` is already in `DHTConfig`; adding it again is redundant.
- The iterative query pseudocode relies on a non-existent `PriorityQueue` method.
- No mention of `KademliaRoutingTable.nodeLookup` (`lib/src/protocols/dht/kademlia_routing_table.dart:226-227`) even though it exists and should be used or refactored.

### 4.4 Recommendations

1. **Deduplicate the reprovide sweep.** Remove the reprovide sweep section from `DHT_INTEGRATION_SPEC.md` and reference `REPROVIDE_SPEC.md` as the authoritative owner. Keep only the `DHTClient` primitives needed by the reprovider.
2. **Clarify layer ownership.** Define that `DHTClient` is the network client (PUT/GET over the wire) and `DHTHandler` is the local datastore / RPC facade. Remove `DHTHandler.putValue`/`getValue` or make them delegates to `DHTClient` with local storage hooks.
3. **Fix the iterative query pseudocode.** Replace `closest.takeUnqueried(alpha, queried)` with a concrete loop using `List<PeerId>` and a `Set<PeerId>` of queried peers, or wrap `PriorityQueue` in a helper class.
4. **Use or remove `KademliaRoutingTable.nodeLookup`.** If the existing method is not fit for purpose, document why and delete it; otherwise, build the iterative query on top of it.
5. **Strengthen provider validation.** Add provider-record signature verification and a check that the provider address is actually dialable from the local node's perspective before returning it to callers.

### 4.5 Missing References and Acceptance Criteria

- **Missing reference:** Amino DHT (`/ipfs/kad/1.0.0`) record signing and validation rules, because server-side enforcement is deferred but the client must still validate.
- **Missing reference:** Exact Kubo `FIND_NODE` / `GET_PROVIDERS` concurrency (`alpha`) and termination conditions.
- **Missing acceptance criterion:** `DHTClient` must be able to bootstrap from `bootstrap.libp2p.io` and join the public DHT.
- **Missing acceptance criterion:** The multiaddr byte encoding fix must be wire-compatible with Kubo and must not break existing dart_ipfs-only tests that rely on the old UTF-8 format.
- **Missing acceptance criterion:** Request/response correlation must survive cross-protocol traffic (i.e., a `GET_VALUE` response does not accidentally complete a `FIND_NODE` completer).

---

## 5. IPNS_SPEC.md

### 5.1 Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 6 | The spec correctly identifies the existing hardcoded fallback (`lib/src/protocols/ipns/ipns_handler.dart:191`) and the stubbed `_publishToDHT` (`lib/src/protocols/ipns/ipns_handler.dart:194-197`). The existing `IPNSRecord` (`lib/src/protocols/ipns/ipns_record.dart`) is already a solid CBOR/Ed25519 implementation, which is highly coherent. Deductions: the spec assumes `PeerId` supports `fromPublicKey(..., type: 'Ed25519')`, `toBase36()`, and `fromBase36()`; none of these methods exist in `lib/src/core/types/peer_id.dart`. The `IPNSHandler.publish` signature changes from `String cid, {String? keyName}` to `CID cid, SimpleKeyPair keyPair`, which is a breaking change not fully reconciled with the keystore-based existing tests and the `SecurityManager` key model. |
| Capability | 9 | DHT-first IPNS publishing and resolution with signed records is a core IPFS capability. Removing the hardcoded `QmResolvedCid` and the base64 PubSub hack is a genuine, necessary expansion. |
| Safety | 8 | The spec requires Ed25519 signature verification, name/public-key binding, expiration validation, and sequence-number anti-replay. It correctly gates PubSub notifications behind consent and Gossipsub compliance. |
| Efficiency | 8 | The spec is focused. Caching is included, and the optional PubSub path avoids overhead when disabled. |
| Evolution | 9 | IPNS is a foundational feature for mutable content in IPFS. This spec brings dart_ipfs to Kubo/Helia parity. |

### 5.2 Overall Verdict

**CONDITIONAL** — meets the numeric threshold (all scores >= 6, Safety = 8) but has a material gap around `PeerId` base36 methods and API compatibility that must be closed before implementation.

### 5.3 Strengths and Weaknesses

**Strengths**

- Leverages the existing, well-structured `IPNSRecord` class for CBOR encoding and Ed25519 signing.
- Correctly identifies the two worst current behaviors: hardcoded fallback CID and base64 PubSub broadcast.
- Security model is sound: verify signature, name, and expiration before caching or returning.
- DHT-first design aligns with Kubo defaults.

**Weaknesses**

- The spec assumes `PeerId` base36 methods that do not exist. IPNS names are base36 by spec; this is a non-trivial missing primitive.
- The new `publish` API takes a `SimpleKeyPair` directly, while the existing API and `IPFSNodeBuilder` wiring (`lib/src/core/builders/ipfs_node_builder.dart:122-133`) use a `SecurityManager` / keystore key name. The migration path is not detailed.
- The `_nameMatchesPublicKey` helper is referenced in testing but not defined in the API or algorithms section.
- The spec says `resolveAsString` will be kept for compatibility, but it does not define how `resolve()` will coexist with it.

### 5.4 Recommendations

1. **Add the missing `PeerId` primitives.** Either extend `PeerId` (`lib/src/core/types/peer_id.dart`) with `fromPublicKey(Uint8List publicKey, {required String type})`, `toBase36()`, and `fromBase36(String name)`, or create a dedicated `IpnsName` helper in `lib/src/protocols/ipns/`. This is a hard blocker.
2. **Reconcile the publish API with the keystore.** Keep the existing `publish(String cid, {String? keyName})` as a convenience that loads the key from `SecurityManager`, and add the new `publishRecord(IPNSRecord)` / `publish(CID, SimpleKeyPair)` as overloads. Do not break existing tests until v2.3 as the backward-compatibility note promises.
3. **Define `_nameMatchesPublicKey`.** Add it to the algorithms section and include the exact byte comparison logic.
4. **Sequence after DHT Integration.** IPNS publish/resolve cannot be validated until `DHTClient.storeValue` and `DHTClient.getValue` are iterative and reliable. The dependency note is correct but should be treated as a hard ordering constraint, not just a parallel note.
5. **Remove the public HTTP fallback.** The current `IPNSHandler.resolve` indirectly relies on a public resolver via `DHTHandler.resolveIPNS`. The spec should explicitly state whether this fallback is removed or retained; DHT-first resolution should not silently fall back to a centralized HTTP service.

### 5.5 Missing References and Acceptance Criteria

- **Missing reference:** IPNS name encoding (base36) and public-key-to-peer-ID conversion rules from `specs.ipfs.tech/ipns/ipns-record`.
- **Missing reference:** The current `SecurityManager` / keystore API used by the existing `IPNSHandler`.
- **Missing acceptance criterion:** `IPNSHandler` must be able to publish and resolve records using only the DHT, with no fallback to `QmResolvedCid` or centralized HTTP.
- **Missing acceptance criterion:** `PeerId` (or an `IpnsName` utility) must support base36 encode/decode before IPNS implementation begins.
- **Missing acceptance criterion:** Existing `IPNSHandler.publish(String, {String? keyName})` callers must continue to compile and work during v2.1.

---

## 6. Cross-Cutting Findings and Council Recommendations

### 6.1 Duplication and Ownership

`REPROVIDE_SPEC.md` and `DHT_INTEGRATION_SPEC.md` both specify a reprovide sweep. The Council assigns ownership to `REPROVIDE_SPEC.md`. `DHT_INTEGRATION_SPEC.md` should be reduced to the primitive DHT operations (iterative queries, `ADD_PROVIDER` batching, value store/get, provider validation) that the reprovider consumes.

### 6.2 Dependency Ordering

The recommended implementation order is:

1. `DHT_INTEGRATION_SPEC.md` — primitives must work before anything else.
2. `REPROVIDE_SPEC.md` — builds on the refined DHT client.
3. `GOSSIPSUB_SPEC.md` — can proceed in parallel with DHT but must land before IPNS PubSub notifications.
4. `IPNS_SPEC.md` — depends on DHT Integration and the missing `PeerId` base36 primitives.
5. `QUIC_SPEC.md` — defer until the `package:ipfs_libp2p` QUIC transport availability is proven.

### 6.3 Safety Veto Items

No specification is rejected. The following issues are veto-worthy if not addressed before merge:

- `IPNS_SPEC.md`: `QmResolvedCid` fallback must be removed in the implementation.
- `REPROVIDE_SPEC.md`: the `all` strategy must have a configurable CID cap to prevent DHT amplification.
- `QUIC_SPEC.md`: `preferQuic` must not default to `true` until interop is proven in CI.
- `DHT_INTEGRATION_SPEC.md`: server-side record signing enforcement should be added in a follow-up; the deferred note is acceptable for v2.1 only if client-side validation is strict.

### 6.4 Missing Architecture Primitives

The following primitives must be added or clarified before the affected specs are implemented:

- `DHTConfig` needs a `DHTMode` or equivalent (`REPROVIDE_SPEC.md`).
- `PeerId` needs base36 methods and Ed25519 public-key derivation (`IPNS_SPEC.md`).
- `RouterInterface` needs a consistent transport-capability query or the changes should be localized to `Libp2pRouter` (`QUIC_SPEC.md`).
- `MetricsCollector` needs concrete DHT metric methods or the specs should define them as new interface requirements (`REPROVIDE_SPEC.md`, `DHT_INTEGRATION_SPEC.md`).

---

## 7. Summary Table

| Spec | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|------|-----------|------------|--------|------------|-----------|---------|
| REPROVIDE_SPEC.md | 7 | 8 | 6 | 7 | 9 | **PASS** |
| QUIC_SPEC.md | 5 | 8 | 6 | 7 | 9 | **CONDITIONAL** |
| GOSSIPSUB_SPEC.md | 7 | 9 | 8 | 8 | 9 | **PASS** |
| DHT_INTEGRATION_SPEC.md | 7 | 9 | 7 | 7 | 9 | **PASS** |
| IPNS_SPEC.md | 6 | 9 | 8 | 8 | 9 | **CONDITIONAL** |

**Council Signatures:** Ciel Council of Five — Networking & P2P Audit Batch 1
