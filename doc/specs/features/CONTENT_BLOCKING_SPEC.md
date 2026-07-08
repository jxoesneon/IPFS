# Content Blocking / Compact Denylist Specification

**Document ID:** `CONTENT_BLOCKING_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P1 (should ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.6

---

## 1. Goal and Scope

The goal of this specification is to add an operator-controlled content denylist service to dart_ipfs that can block CID or multihash retrieval at the gateway and RPC layers. The service must be default-off, auditable, and independent from the existing authentication and rate-limiting logic in `SecurityManager`. It must support the BadBits-style compact denylist format used by many public IPFS gateway operators.

This is a **denylist** (block list) service, not a general content-filtering or classification engine. The operator is solely responsible for maintaining and updating the list; dart_ipfs does not ship, curate, or automatically update any denylist entries. List updates are performed only through the operator-configured local file path or HTTP(S) URL on the configured refresh interval.

Scope includes:

- Configuration additions to `SecurityConfig` for enabling and tuning the denylist.
- A new `DenylistService` that loads, refreshes, and matches denylist entries.
- Support for CID strings, multihash strings, and compact BadBits-style lists.
- Gateway and RPC integration that returns `451` or logs hits based on operator policy.
- DHT provider-announcement rejection for blocked CIDs.
- An audit log with FIFO eviction and metrics integration.

Out of scope: hardcoded denylist entries, automated legal classification, and cryptographic verification of denylist authenticity.

---

## 2. Official References

- [BadBits Denylist](https://badbits.dwebops.pub/) — community CID/multihash denylist format and tooling.
- [IPFS Gateway Content Blocking](https://specs.ipfs.tech/http-gateways/) — operator guidance on default-off, auditable, and privacy-preserving blocking.
- [IPFS HTTP Gateway Specs](https://specs.ipfs.tech/http-gateways/) — gateway request handling conventions, including `451` status code semantics.
- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — Kubo-style error JSON format.
- [RFC 7725](https://tools.ietf.org/html/rfc7725) — HTTP `451 Unavailable For Legal Reasons` status code.

---

## 3. Current State in dart_ipfs

The current security layer is in `lib/src/core/security/security_manager.dart` and `lib/src/core/config/security_config.dart`.

- `SecurityManager` only blocks clients based on authentication and rate-limiting; it has no denylist module.
- `SecurityConfig` has no `enableDenylist`, `denylistPath`, `denylistRefreshInterval`, `denylistCompactFormat`, or `denylistDefaultAction` fields.
- `RPCHandlers` (in `lib/src/services/rpc/rpc_handlers.dart`) has `handleCat`, `handleBlockGet`, `handleDagGet`, and `handleDhtProvide` methods that do not check any denylist.
- `GatewayHandler` (in `lib/src/services/gateway/gateway_handler.dart`) does not check CIDs against a denylist before serving content.
- `DHTHandler.handleProvideRequest` in `lib/src/protocols/dht/dht_handler.dart` does not reject provider announcements for blocked CIDs.

---

## 4. Target State / Requirements

### 4.1 Configuration Additions

Extend `SecurityConfig` in `lib/src/core/config/security_config.dart` with:

```text
SecurityConfig
  bool enableDenylist              // default false
  String? denylistPath             // local file path or HTTP(S) URL
  Duration denylistRefreshInterval // default 1 hour
  bool denylistCompactFormat         // default true (BadBits-style)
  String denylistDefaultAction     // "block" | "log", default "block"
```

All fields are additive. Default values must keep the denylist disabled and have no effect on request handling unless the operator explicitly enables it.

### 4.2 Denylist Service API

Create a new `DenylistService` (recommended location: `lib/src/core/security/denylist_service.dart`) implementing `ILifecycle`:

```text
DenylistService implements ILifecycle
  DenylistService(SecurityConfig, MetricsCollector)
  Future<void> start()        // loads initial list and starts refresh timer
  Future<void> stop()         // cancels timer
  bool isBlocked(CID cid)
  bool isBlockedByMultihash(String multihash)
  bool isBlockedByCidString(String cidStr)
  Future<void> loadFromPath(String path)
  Future<void> loadFromUrl(String url)
  void loadCompactBytes(Uint8List bytes)
  DenylistStats getStats()
  List<DenylistAuditEvent> getAuditLog()

DenylistStats
  int loadedEntries
  DateTime? lastRefresh
  int refreshErrors

DenylistAuditEvent
  DateTime timestamp
  String cidOrMultihash
  String action       // "blocked" | "logged" | "allowed"
  String source       // "gateway" | "rpc" | "dht"
  String? reason      // optional operator-provided reason from list metadata
```

`DenylistService` is constructed with `SecurityConfig` and `MetricsCollector`, must be registered as an `ILifecycle` service in `LifecycleManager`, and must be started/stopped by `LifecycleManager`. Gateway, RPC, and DHT handlers access the same shared instance through `IPFSNode` (or a service locator).

### 4.3 Compact Denylist Format

Support the BadBits-style compact format:

- A text file with one entry per line.
- The parser must classify each line in this exact order:
  1. Skip empty lines and lines that begin with a plain `#` comment (e.g., `# List updated 2026-01-25`).
  2. If a line begins with `#` and the remainder is valid JSON, parse it as a JSON comment containing metadata (e.g., `{"reason": "...", "cid": "..."}`). Store any `reason` and `cid` metadata for audit events.
  3. Attempt to decode the line as a CID string. If successful, extract the multihash and match both the CID and the underlying multihash.
  4. Attempt to decode the line as a base32-encoded multihash (lowercase). If successful, match against any CID that contains the same multihash regardless of codec or version.
  5. If none of the above succeed, skip the line, count it as a refresh warning, and continue processing.
- When `denylistCompactFormat=true`, entries may be sorted and deduplicated for binary-search lookup.
- Also support plain text lists of CID strings for backward compatibility.
- Maximum line length: 4096 characters; longer lines are skipped and counted as a refresh warning.
- Maximum denylist size: 1,000,000 entries or 256 MiB (whichever is reached first); exceeding this fails the refresh atomically and keeps the previous list active.

For CID entries, the service must extract the multihash and match both the CID and the underlying multihash. For base32 multihash entries, the service must decode and match against any CID that contains the same multihash regardless of codec or version.

### 4.4 Gateway and RPC Integration

- In `GatewayHandler.handlePath` and `GatewayHandler.handleSubdomain`, check `DenylistService.isBlockedByCidString(cidStr)` before serving. If blocked and `denylistDefaultAction="block"`, return `451 Unavailable For Legal Reasons` with body `Content blocked by operator policy`. If `denylistDefaultAction="log"`, serve the content but record an audit event with `action="logged"` and emit `MetricsCollector.recordSecurityEvent("denylist_logged")`. Logged events do not increment `refreshErrors`.
- In `RPCHandlers.handleCat`, `handleBlockGet`, `handleDagGet`, and `handleDhtProvide`, check the denylist before processing. Return Kubo-style error JSON with `Code: 451` and `Message: Content blocked by operator policy` when blocked.
- In `DHTHandler.handleProvideRequest`, reject provider announcements for blocked CIDs. The method should not store the provider record and should log a `denylist_blocked` security event.

### 4.5 Audit and Refresh

- Denylist hits must be recorded in `DenylistService.auditLog` with a maximum size of 10,000 entries and FIFO eviction.
- On `start()`, load the initial list and schedule a refresh timer based on `denylistRefreshInterval`.
- On `stop()`, cancel the refresh timer.
- On refresh, reload the list atomically: build a new in-memory set from a complete successful parse, then swap it in. Do not drop requests during refresh.
- Partial or corrupt denylist refreshes must be rejected atomically: if any line fails parsing or exceeds the configured limits, the entire refresh is discarded and the previously loaded list remains active.
- Failed URL refreshes must increment `refreshErrors`, log a warning, and continue using the previously loaded list. They must not crash the node.
- On startup, when enabled, log a warning that includes the source path and the number of loaded entries.

---

## 5. Detailed Acceptance Criteria

- [ ] `DenylistService` is default-off and has no effect on request handling when disabled.
- [ ] Blocking a CID returns `451` on the gateway and a Kubo-style error on RPC.
- [ ] Compact multihash lists load and match correctly against CIDs with the same multihash.
- [ ] Plain text CID lists load and match correctly for backward compatibility.
- [ ] Audit log records every blocked/logged request with timestamp, source, and action.
- [ ] Refresh interval reloads the list without dropping requests or returning false negatives.
- [ ] Failed URL refreshes increment `refreshErrors` and log a warning but do not crash the node.
- [ ] No hardcoded denylist entries are shipped in the package.
- [ ] DHT provider announcements for blocked CIDs are rejected.
- [ ] `denylistDefaultAction="log"` records an audit event with `action="logged"` and does not increment `refreshErrors`.
- [ ] Denylist refreshes are atomic; a partial or corrupt refresh keeps the previous list active.
- [ ] The parser skips malformed lines, lines longer than 4096 characters, and invalid base32/base58 strings without crashing.
- [ ] `DenylistService` is registered as an `ILifecycle` service and started/stopped by `LifecycleManager`.
- [ ] The maximum denylist size (1,000,000 entries or 256 MiB) and maximum line length (4096 characters) are enforced.

---

## 6. Security Considerations

- Default-off: the denylist must be opt-in. Operators must explicitly enable it and supply a source path. No package-level blocklist is allowed.
- Privacy: the denylist service must not phone home. URL refreshes are only performed to the operator-configured URL. No telemetry about blocked requests is sent externally.
- Audit log: stored in memory with a bounded size. Operators must be aware that the audit log is volatile unless persisted by other means.
- Label safety: metrics labels must not include CIDs or file names. Use only `type` labels such as `blocked_cid`, `denylist_logged`, and `auth_failure`.
- Hostile inputs: denylist parsers must handle malformed lines, extremely long lines, and invalid base32/base58 strings without crashing. Invalid lines should be skipped and counted as a refresh warning.
- Timing: matching must be O(log n) or O(1) after loading. Linear scans are not acceptable for production lists.

---

## 7. Testing Strategy

### 7.1 Unit Tests

Target greater than or equal to 80% coverage per file:

- `DenylistService` loading from path, URL, and bytes.
- BadBits compact format parsing, including base32 multihashes, CID strings, and JSON comment lines.
- Matching logic: CID matches multihash entry, multihash matches CID entry, negative cases.
- Audit log FIFO eviction and event fields.
- Refresh timer start/stop and atomic list swap.
- Failed URL refresh handling and `refreshErrors` increment.
- Default-off behavior: no blocking when `enableDenylist` is false.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to verify:

- Gateway returns `451` for blocked CID with `denylistDefaultAction="block"`.
- Gateway returns `200` for blocked CID with `denylistDefaultAction="log"` and emits the correct metric.
- RPC `handleCat` returns Kubo-style `Code: 451` error for blocked CID.
- RPC `handleBlockGet`, `handleDagGet`, and `handleDhtProvide` return `Code: 451` for blocked CIDs.
- Non-blocked CIDs continue to work normally through gateway and RPC.

### 7.3 Interoperability Tests

- Load a BadBits-style denylist in a dart_ipfs node and verify that a CID on the list cannot be retrieved through the gateway or RPC while a sibling CID can.
- Verify that a Kubo-style `curl` command against the gateway receives `451` for a blocked CID.
- Verify that the denylist refresh reloads an updated list served from a local HTTP server.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| `SecurityConfig` | Must be extended with denylist fields. |
| `MetricsCollector` | Required for `ipfs_security_events_total` and `denylist_*` event types. |
| `CID` / multihash decoding | Required to match CIDs against multihash entries. |
| `GatewayHandler` / `RPCHandlers` / `DHTHandler` | Must call `DenylistService` before serving or providing. |

**Implementation order:**

1. Extend `SecurityConfig` with denylist fields.
2. Create `DenylistService` with load, match, refresh, and audit APIs.
3. Implement BadBits compact format parser and plain CID fallback.
4. Integrate denylist checks into `GatewayHandler.handlePath` and `handleSubdomain`.
5. Integrate denylist checks into `RPCHandlers.handleCat`, `handleBlockGet`, `handleDagGet`, and `handleDhtProvide`.
6. Integrate denylist rejection into `DHTHandler.handleProvideRequest`.
7. Add unit, contract, and interop tests.

Content blocking is a Phase 2 P1 item that can be built independently of other features, though it must be wired into gateway and RPC paths after those are stable.

---

## 9. Backward Compatibility Notes

- Denylist is default-off. Existing `SecurityConfig` constructors and JSON serialization must remain compatible; new fields are optional with defaults.
- No existing request handler changes behavior unless the operator explicitly sets `enableDenylist: true` and provides a `denylistPath`.
- The `SecurityManager` class is not replaced; the denylist service is a separate module that request handlers may call alongside `SecurityManager`.
- If a denylist source is unavailable at startup, the service logs a warning and remains inactive, rather than blocking all requests.
