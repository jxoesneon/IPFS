# Council of Five Audit Report — SERVICES_APIS Feature Specifications

**Audit Date:** 2026-01-25  
**Audited Documents:**
1. `doc/specs/features/MFS_SPEC.md`
2. `doc/specs/features/METRICS_SPEC.md`
3. `doc/specs/features/SUBDOMAIN_GATEWAY_SPEC.md`
4. `doc/specs/features/TRUSTLESS_GATEWAY_SPEC.md`
5. `doc/specs/features/CONTENT_BLOCKING_SPEC.md`

**Council Lenses:**
- **Coherence** — fit with dart_ipfs architecture and existing code paths.
- **Capability** — genuine, non-redundant capability expansion.
- **Safety** — risks, attack vectors, and veto-worthy issues.
- **Efficiency** — lean, focused, performant vs. bloated.
- **Evolution** — advances toward Kubo/Helia parity and superiority.

**Verdict Thresholds:**
- **PASS** — at least 3 scores ≥ 6 and Safety > 3.
- **CONDITIONAL** — minor issues that must be resolved before implementation.
- **DEFER** — not ready for v2.0; needs substantial rework or prerequisites.
- **REJECT** — Safety ≤ 3 or majority below threshold.

---

## 1. MFS Completeness Specification (`MFS_SPEC.md`)

### Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 7 | Builds directly on the existing `MFSManager` (`lib/src/core/mfs/mfs_manager.dart`, lines 15–368) and the `/mfs/root` persistence key. RPC targets `lib/src/services/rpc/rpc_handlers.dart` which already hosts Kubo-style handlers. However, the spec does not address how `MFSManager` is instantiated and registered in `IPFSNode`; the current file only shows the constructor, not integration. |
| Capability | 9 | Fills a genuine, large gap. Today `MFSManager` has only `mkdir`, `cp`, `rm`, `ls`, `stat`, `write`, `read`; it lacks `mv`, `flush`, `chcid`, `sync`, and the full Kubo RPC surface. The spec directly expands drop-in Kubo compatibility. |
| Safety | 7 | Calls out path traversal prevention, root CID integrity, input validation, and multipart size limits. Acceptable. The current `_splitPath` (line 236) does not normalize `..`, so this is a real gap the spec closes. Weakness: it does not define concurrency semantics for `sync()` or how torn roots are prevented beyond "serialize mutations." |
| Efficiency | 7 | `flush(path)` is scoped to ancestor rehashing, which is efficient. However, `stat` cumulative size remains recursive-DAG work without caching; the spec does not propose memoization or limit recursion depth. This is acceptable for a v2.0 P0 but not optimal. |
| Evolution | 9 | MFS is a foundational Kubo feature. Completing it is a prerequisite for CLI tooling and FUSE-like integrations. Strong parity move. |

**Overall Verdict: PASS (with conditions)**

### Strengths
- Targets the real existing file and method names, making the delta additive rather than a rewrite.
- Includes Kubo interoperability tests against v0.42.0+, which is the right acceptance bar.
- Explicitly preserves existing public signatures and requires only additive changes (Section 4.1, §9).
- Data models (`MFSStat`, `MFSListEntry`) are aligned with Kubo field names (`Hash`, `CumulativeSize`, `Blocks`, `Type`).

### Weaknesses
- The spec assumes the current `MFSManager` has deferred/transactional state to flush, but the existing code persists the root CID after every mutation (`_modifyPath`, line 272). The spec says "existing behavior that immediately materializes mutations may continue" (§9), which creates a contradiction with §4.1's description of `flush` materializing an "in-memory delta." The implementation must either introduce a real delta buffer or redefine `flush`/`sync` as no-ops that still return the current root CID.
- `write` with `offset` and `truncate=false` is not trivial because the existing `UnixFSBuilder` consumes a full stream and creates new chunking. The spec does not specify how partial updates preserve existing chunk boundaries or CIDs, which is required for Kubo parity.
- `chcid` is underspecified: the current `CID.fromContent` (used at lines 36, 59, 123, etc.) is called with only `codec: 'dag-pb'` and no hash parameter. The spec must confirm whether the `CID` class supports selectable multihash functions; if not, `chcid` must be implemented as a full re-encode/re-layout pass.
- No mention of how the new RPC handlers obtain the `MFSManager` instance from `RPCHandlers` (which currently only holds an `IPFSNode`).

### Recommendations
1. Clarify the `flush`/`sync` model: either (a) implement a buffered delta layer, or (b) declare `flush`/`sync` as synchronous root-CID accessors and remove "in-memory delta" language.
2. Add a subsection to `write` explaining partial-update semantics: read existing UnixFS chunks, replace the affected range, and re-chunk only the modified segment if possible.
3. Verify `CID.fromContent` signature and multihash support; if absent, add a requirement to re-encode DAGs for `chcid`.
4. Add acceptance criteria for `files/write` with `offset` and `truncate=false` tested against Kubo, not just unit tests.
5. Document the `MFSManager` lifecycle injection path (e.g., via `IPFSNode` or service locator).

### Missing References / Acceptance Criteria
- Reference to the current `MFSManager` constructor and `init()` method is missing; the spec should cite `lib/src/core/mfs/mfs_manager.dart` lines 17–42.
- Missing acceptance criterion: `MFSManager` must remain usable without RPC (i.e., internal API tests are standalone).
- Missing criterion: `flush` on an already-persistent MFS must return the same root CID idempotently.

---

## 2. Real Metrics Collection Specification (`METRICS_SPEC.md`)

### Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 9 | Maps directly to the stub `MetricsCollector` (`lib/src/core/metrics/metrics_collector.dart`, lines 1–82), the buggy `NetworkMetrics` (`lib/src/core/metrics/network_metrics.dart`, lines 1–39), and the already-present `MetricsConfig` (`lib/src/core/config/metrics_config.dart`, lines 16–74). The `prometheus_client` package is already in `pubspec.yaml` line 38. |
| Capability | 9 | Replacing hardcoded-zero getters with real Prometheus metrics is a genuine foundational capability. It unblocks observability for nearly every other feature. |
| Safety | 7 | Good: forbids sensitive labels (peer IDs, CIDs, paths), requires label sanitization, and keeps `reset()` test-only. Weakness: the public `/metrics` endpoint is exposed without authentication or IP allow-listing; the spec acknowledges this but defers it, which is acceptable for v2.0 but should be flagged as a production risk. |
| Efficiency | 8 | Requires O(1) increments, single-boolean disabled check, and periodic background collection. Well-focused. The histogram bucket set is reasonable. |
| Evolution | 9 | Production-grade metrics are essential for parity with Kubo and any operator deployment. Strong evolution item. |

**Overall Verdict: PASS**

### Strengths
- The metric catalog is well-organized and follows Prometheus naming conventions (`ipfs_<subsystem>_<unit>`).
- It explicitly fixes the documented `NetworkMetrics` null-entry bug (`peerMetrics[peer]?.messagesSent++` at line 17) via `putIfAbsent`.
- Includes the `LifecycleManager` registration requirement and the `/metrics` endpoint wiring with correct Prometheus content type.
- Disabled-state overhead is explicitly bounded by a single boolean check.

### Weaknesses
- The spec uses `MetricsConfig.enabled` as the gate, but the existing `MetricsCollector` constructor takes `IPFSConfig` and reads `_config.metrics.enabled` (line 80). The spec should be explicit about which config object is authoritative.
- The `MetricsCollector` class currently exposes a `metricsStream` broadcast stream and legacy getters. The spec says legacy getters must return real values but does not define whether the stream remains the primary event channel or becomes secondary to Prometheus exposition. This could cause confusion during instrumentation.
- The `recordRpcRequest` signature includes `String method` and `String endpoint`, but the metric table uses only `endpoint` for the histogram. The method label is redundant for the histogram; clarify or remove it.
- No explicit acceptance criterion that the `/metrics` body must parse with the official Prometheus Go client or `prometheus_client` parser.

### Recommendations
1. Standardize on the config path: state that `MetricsCollector` receives `IPFSConfig` and gates on `ipfsConfig.metrics.enabled`, or refactor the constructor to accept `MetricsConfig` directly.
2. Deprecate the `metricsStream` for production telemetry and document it as a legacy/secondary channel.
3. Add a performance acceptance criterion: a microbenchmark showing that disabled metrics do not allocate per request.
4. Add an acceptance criterion that the Prometheus output parses without error using the official `prometheus_client` parser.
5. Consider adding a note that future work should add authentication or IP allow-listing for `/metrics` before public-gateway deployment.

### Missing References / Acceptance Criteria
- Citation to `pubspec.yaml` line 38 for the `prometheus_client` dependency should be included.
- Missing criterion: validate that no metric label contains `\n`, `\`, or `"` characters after sanitization.
- Missing criterion: confirm that `LifecycleManager` calls `start()`/`stop()` on `MetricsCollector` and that the timer is cancelled cleanly.

---

## 3. Subdomain Gateway Specification (`SUBDOMAIN_GATEWAY_SPEC.md`)

### Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 8 | Builds on the existing stub `GatewayHandler.handleSubdomain` (`lib/src/services/gateway/gateway_handler.dart`, lines 270–289) and the existing `GatewayConfig`/`GatewayServer` classes. It correctly notes that `GatewayConfig` currently lacks subdomain fields and that `handleSubdomain` is not wired into the router. |
| Capability | 8 | Subdomain origin isolation is a real IPFS gateway feature and is required for browser security and public-gateway interoperability. It is not redundant with the existing path gateway. |
| Safety | 8 | Strong security section: origin isolation, no credentials on subdomain origins, host header injection prevention via domain allow-list, CID validation before lookup, DNSLink TTL capping, and denylist integration. |
| Efficiency | 7 | DNSLink caching is bounded (1 min to 1 hour). Subdomain parsing is per-request but lightweight. The spec does not address caching of resolved IPNS names, which could be expensive. |
| Evolution | 8 | Directly advances Kubo/Helia gateway parity and enables public-gateway deployment. Good. |

**Overall Verdict: PASS (with conditions)**

### Strengths
- Default-off (`enableSubdomainGateway: false`) preserves existing behavior.
- Correctly requires `handleSubdomain` to run before path-gateway fallback.
- Includes DNSLink resolution and IPNS resolver integration, matching the official IPFS subdomain gateway spec.
- Trustless format negotiation must be preserved on subdomain requests, which correctly couples this spec to the trustless gateway work.

### Weaknesses
- The spec's `gatewayDomain` semantics are slightly ambiguous. It says "null means subdomain gateway disabled except localhost" and also "localhost subdomain requests must be supported regardless of the configured `gatewayDomain`." The implementation must distinguish between the configured production domain and the implicit localhost domain; this needs a clear precedence rule.
- The `subdomainTLSRedirect` default is "true for production domains," but the spec does not define how the implementation distinguishes a "production domain" from `localhost`. This should be an explicit rule (e.g., TLS redirect is enabled only when `gatewayDomain` is non-null and not `localhost`/`127.0.0.1`).
- The `GatewayServer` currently creates `GatewayHandler` in its constructor (line 34) and passes `ipnsResolver` only. The spec's new `GatewayConfig` fields must be propagated through `GatewayServer` to `GatewayHandler`; the spec does not detail this wiring.
- The denylist integration is a dependency, but the spec does not specify what happens when the denylist service is unavailable (e.g., a blocking failure should not crash the gateway; it should fail open or closed based on policy).

### Recommendations
1. Define a formal host-parsing precedence: first check `localhost`/`127.0.0.1` bypass, then check the configured `gatewayDomain` against an allow-list.
2. Make `subdomainTLSRedirect` default `false` and require operators to opt in explicitly; this avoids accidental redirect loops in local development.
3. Add a router-sequence diagram or explicit acceptance criterion showing that `GatewayServer` calls `handleSubdomain` before `handlePath`.
4. Specify behavior when `subdomainDNSLinkResolver` is true but DNS resolution fails: return `400` or `502` consistently.
5. Clarify denylist fallback behavior when the denylist service is not yet implemented or disabled.

### Missing References / Acceptance Criteria
- Citation to `lib/src/services/gateway/gateway_handler.dart` lines 270–289 for the existing stub is missing.
- Missing criterion: requests to `Host: example.com` (bare domain) must fall back to path gateway and not be treated as a subdomain error.
- Missing criterion: CORS headers on subdomain responses must not include `Access-Control-Allow-Credentials: true` (mentioned in §6 but not in §5 acceptance criteria).
- Missing reference to the IPFS Subdomain Gateway Spec should be retained; it is already present but should be cited in the acceptance criteria.

---

## 4. Trustless Gateway Full Compliance Specification (`TRUSTLESS_GATEWAY_SPEC.md`)

### Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 5 | The spec references the existing `CAR` class in `lib/src/core/data_structures/car.dart` (lines 1–201), but that class implements a **protobuf-based custom CAR format**, not the IPLD CAR v1 spec. The spec demands "varint-prefixed CID+block frames per the CAR v1 spec" and "Content-Disposition: attachment; filename=\"<cid>.car\"" which the existing code cannot produce. This is a major coherence mismatch. The rest of the spec (gateway handler, content type handler) fits well. |
| Capability | 9 | Trustless gateway responses are a core modern IPFS capability and are required for Kubo/Helia/Iroh interoperability. Very genuine expansion. |
| Safety | 7 | Good: content blocking, bypassing HTML rendering, CAR attachment, opaque IPNS records. Weakness: the requirement to attempt Bitswap retrieval before returning `404` for missing blocks could block requests for long periods and be abused for DoS; the spec does not define timeouts or limits. |
| Efficiency | 6 | CAR generation of "all blocks reachable from the root CID ... up to the full DAG" can be extremely expensive for large DAGs and is not bounded or streamed. The spec does not mention size limits, depth limits, or streaming responses. This is a significant efficiency concern. |
| Evolution | 9 | Trustless gateway compliance is one of the highest-impact parity features. It enables programmatic HTTP clients and CAR-based workflows. |

**Overall Verdict: CONDITIONAL — must resolve CAR format mismatch before implementation.**

### Strengths
- Correctly identifies that the current `ContentTypeHandler._processCarArchive` (line 144) converts CAR archives to HTML, which breaks programmatic clients.
- Negotiation precedence (`?format=` > `Accept` > default) matches the official spec.
- Includes raw block, CAR, IPNS record, DAG-JSON, and DAG-CBOR response types, covering the full trustless surface.
- Good security guidance on bypassing HTML rendering and serving CARs as attachments.

### Weaknesses
- **Critical:** The existing `CAR` class uses a protobuf serialization (`proto.CarProto`) and is not IPLD CAR v1 compliant. The spec incorrectly treats this file as a ready dependency. The implementation must either (a) write a new `CarV1Encoder` class, or (b) significantly refactor `CAR` to support standard CAR v1 serialization. This is a non-trivial, spec-blocking issue.
- **Critical:** CAR responses must include "all blocks reachable ... up to the full DAG." For large DAGs this is unbounded and must be implemented with streaming or depth/size limits. The spec is silent on this.
- Bitswap fallback before `404` lacks a timeout policy, risking request-blocking and resource exhaustion.
- The spec says `ContentTypeHandler` may continue to render CAR files as HTML for non-trustless requests, but the existing `ContentTypeHandler` is not currently used by `GatewayHandler._serveContent`. The spec should clarify whether `ContentTypeHandler` is integrated into the gateway path or remains separate.
- DAG-JSON/CBOR "canonical encoding" requirements assume the presence of correct IPLD codecs; the spec does not verify these exist in the codebase.

### Recommendations
1. **Highest priority:** Remove the dependency on `lib/src/core/data_structures/car.dart` as-is and add a new requirement to implement a standard IPLD CAR v1 encoder (or refactor the existing class). Include a test that parses the output with the official `go-car` or `js-car` library.
2. Add bounded CAR traversal: define a maximum DAG depth, maximum total block count, and/or maximum total byte size, with `416` or `413` responses when exceeded. Alternatively, implement streaming CAR generation and document it.
3. Add a timeout/attempt policy for Bitswap fallback (e.g., 5 seconds default, configurable) and return `404` or `504` on timeout.
4. Clarify whether `ContentTypeHandler` is used by the path gateway; if not, state that the trustless bypass lives entirely in `GatewayHandler`.
5. Add acceptance criteria for each format (`raw`, `car`, `ipns-record`, `dag-json`, `dag-cbor`) using both `?format=` and `Accept` negotiation.
6. Verify the availability of canonical DAG-JSON and DAG-CBOR codecs in the codebase; if absent, add them as dependencies.

### Missing References / Acceptance Criteria
- The reference to `lib/src/core/data_structures/car.dart` must be corrected or removed; the current file does not implement IPLD CAR v1.
- Missing criterion: CAR output must be parseable by a standard IPLD CAR v1 reader (e.g., Kubo `ipfs dag import`).
- Missing criterion: define maximum CAR size/depth and expected behavior when exceeded.
- Missing criterion: Bitswap fallback timeout policy.
- Missing reference to the official IPLD CAR v1 spec binary format (varint length + CID + block bytes, DAG-CBOR header).

---

## 5. Content Blocking / Compact Denylist Specification (`CONTENT_BLOCKING_SPEC.md`)

### Scores

| Lens | Score | Rationale |
|------|-------|-----------|
| Coherence | 8 | Targets the existing `SecurityConfig` (`lib/src/core/config/security_config.dart`, lines 1–72), `SecurityManager` (`lib/src/core/security/security_manager.dart`, lines 1–328), `RPCHandlers` (`lib/src/services/rpc/rpc_handlers.dart`, lines 1–472), `GatewayHandler` (`lib/src/services/gateway/gateway_handler.dart`, lines 1–331), and `DHTHandler` (`lib/src/protocols/dht/dht_handler.dart`). The design as a separate `DenylistService` module is coherent and avoids replacing `SecurityManager`. |
| Capability | 8 | Operator-controlled content blocking is a real operational requirement for public gateways and is a capability gap today. It supports the BadBits-style compact format used by the community. |
| Safety | 9 | Excellent security posture: default-off, no hardcoded entries, no telemetry/phone-home, bounded in-memory audit log, O(log n)/O(1) matching, hostile input handling, and DHT provide rejection. |
| Efficiency | 8 | Requires sorted/deduplicated binary-search lookup or hash-set lookup, atomic refresh without dropping requests, and FIFO audit log. Good. |
| Evolution | 8 | Advances dart_ipfs toward production public-gateway readiness and Kubo-style operational tooling. Good. |

**Overall Verdict: PASS (with conditions)**

### Strengths
- Strong default-off policy: no blocking unless the operator explicitly enables it and provides a source.
- Supports both BadBits-style compact multihash lists and plain CID lists, easing operator adoption.
- Covers gateway, RPC, and DHT provider paths, preventing blocked content from being re-provided.
- Audit log with FIFO eviction and metrics integration provides observability without leaking sensitive data.
- Refresh failures are handled gracefully (keep previous list, increment `refreshErrors`).

### Weaknesses
- The compact format description says entries may be "base32-encoded multihash (lowercase)" or "CID string (base32 or base58btc)." This is ambiguous: a base32-encoded multihash is not a CID string, and the parser must distinguish them. The spec should define the exact detection rule (e.g., try CID decode first, then multihash decode).
- JSON comment lines starting with `#` are described as containing metadata such as `{"reason": "...", "cid": "..."}`. This conflicts with plain text comment lines; the parser must distinguish JSON comments from plain `#` comments. The spec should be explicit.
- The spec does not define how `denylistDefaultAction="log"` interacts with the audit log and metrics. Specifically, it should clarify whether `denylist_logged` events are counted as hits in `DenylistStats`.
- The DHT integration references `DHTHandler.handleProvideRequest`, but the spec does not verify the exact signature or how the DHT handler accesses `DenylistService`. This should be documented.
- The spec does not address what happens when a denylist URL refresh returns a partial or corrupt list: should the entire refresh be rejected, or should valid lines be kept? Atomic swap implies all-or-nothing, but the spec should state this explicitly.

### Recommendations
1. Define the parser's line-type detection algorithm unambiguously: CID decode first, multihash decode second, JSON comment third, plain comment fourth, otherwise skip and warn.
2. Clarify that `denylistDefaultAction="log"` records an audit event with `action="logged"` and emits `MetricsCollector.recordSecurityEvent("denylist_logged")`, but does not increment `refreshErrors`.
3. Add a requirement that partial/corrupt denylist refreshes are rejected atomically; the previous list remains active.
4. Document the `DenylistService` dependency injection path (e.g., constructed with `SecurityConfig` and `MetricsCollector` and registered in `LifecycleManager`).
5. Add an acceptance criterion that metrics labels never contain CIDs or paths, verified by a test that inspects `/metrics` output.

### Missing References / Acceptance Criteria
- Citation to the actual `DHTHandler` file location is missing; it should reference `lib/src/protocols/dht/dht_handler.dart`.
- Missing criterion: define the maximum allowed line length and behavior when exceeded (skip and warn).
- Missing criterion: define the maximum denylist size in entries or bytes and behavior when exceeded.
- Missing criterion: verify that `DenylistService` is registered as an `ILifecycle` service and started/stopped by `LifecycleManager`.
- Missing reference to RFC 7725 for the `451` status code is already present; good.

---

## Council Summary Table

| Spec | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|------|-----------|------------|--------|------------|-----------|---------|
| MFS_SPEC | 7 | 9 | 7 | 7 | 9 | PASS (conditional) |
| METRICS_SPEC | 9 | 9 | 7 | 8 | 9 | PASS |
| SUBDOMAIN_GATEWAY_SPEC | 8 | 8 | 8 | 7 | 8 | PASS (conditional) |
| TRUSTLESS_GATEWAY_SPEC | 5 | 9 | 7 | 6 | 9 | CONDITIONAL |
| CONTENT_BLOCKING_SPEC | 8 | 8 | 9 | 8 | 8 | PASS (conditional) |

### Cross-Cutting Observations
1. **Dependencies are mostly correct.** The specs correctly identify P0 foundation items (MFS, metrics, trustless gateway) and P1 dependent items (subdomain gateway, content blocking). However, the trustless gateway spec cannot be implemented without first resolving its CAR format mismatch, which may affect the subdomain gateway timeline.
2. **Config consistency.** All five specs propose additive `Config` fields with default-off or backward-compatible defaults. This is consistent and safe.
3. **Lifecycle integration.** Several specs mention `LifecycleManager` but none detail the current registration mechanism. The codebase should be audited for an existing `LifecycleManager` implementation and how new services are registered; if it does not exist, a separate spec should be created or the existing `ISecurityManager.start()`/`stop()` patterns (e.g., lines 263–275) should be used as the template.
4. **Testing strategy.** All specs target 80% coverage per file and include interoperability tests. This is commendable but must be balanced against the reality that some features (e.g., Kubo interoperability in CI) require infrastructure that may not yet exist.
5. **Security metrics.** `METRICS_SPEC` and `CONTENT_BLOCKING_SPEC` both reference `ipfs_security_events_total`. The event types (`rate_limit`, `blocked_cid`, `auth_failure`, `denylist_logged`, `denylist_blocked`) should be consolidated in a single enum or constant list to avoid drift.

### Final Council Ruling
- **Approve for implementation:** `METRICS_SPEC.md`.
- **Approve with conditions:** `MFS_SPEC.md`, `SUBDOMAIN_GATEWAY_SPEC.md`, `CONTENT_BLOCKING_SPEC.md`.
- **Return for revision before implementation:** `TRUSTLESS_GATEWAY_SPEC.md` (must resolve the CAR v1 format mismatch and add traversal bounds/timeout policies).

No specification is rejected. All are directionally sound, but `TRUSTLESS_GATEWAY_SPEC.md` contains a factual error regarding the existing CAR implementation and lacks operational bounds that could cause production outages. Once those issues are corrected, it should be re-audited for a PASS verdict.
