# dart_ipfs v2.0 Services & APIs Parity/Superiority Specification

**Document ID:** `SERVICES_APIS_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Repository:** `C:\Users\josee\IPFS`  
**Approved by:** Ciel Council of Five (2026-06-25)  
**Status:** Draft specification for implementation  

---

## 1. Overview / Goal

This specification closes the highest-impact **service and API interoperability gaps** between dart_ipfs v1.11.5 and the public IPFS ecosystem (Kubo v0.42.0+, Helia, and Iroh). It is scoped to the backlog items that were deliberated and approved by the Ciel Council of Five on 2026-06-25 and is the single source of truth for their implementation.

The goal is to make dart_ipfs a **fully credible, Kubo-compatible IPFS node** for the service layer while preserving its Dart-native architecture and cross-platform (VM/Web) constraints. The work is divided into three priority tiers:

- **P0** — Must ship in v2.0; blocks interoperability and production readiness.
- **P1** — Should ship in v2.0; important for network participation and operator control.
- **P2** — Deferred until the v2.0 foundation is production-grade.

### Council verdicts covered by this document

| Priority | Verdict | Item |
|----------|---------|------|
| P0 | APPROVED | MFS completeness: `flush`/`sync`, full `/api/v0/files/*` RPC coverage, Kubo-matching `read/write/stat/ls` semantics. |
| P1 | APPROVED | Subdomain gateway: complete stub `handleSubdomain` with strict host/CID validation and optional DNSLink resolution. |
| P0 | APPROVED | Trustless gateway full compliance: honor `Accept` and `?format=` for raw block, CAR, IPNS-record, and DAG-JSON/CBOR responses without returning HTML. |
| P0 | APPROVED | Real metrics collection: replace stub `MetricsCollector` getters with actual Prometheus-compatible counters/histograms and wire the configured endpoint. |
| P2 | DEFERRED | OpenTelemetry support: revisit after real metrics are production-grade. |
| P1 | APPROVED | Content blocking / compact denylist: operator-controlled denylist service (default-off, auditable) alongside `SecurityManager`. |
| P1 | APPROVED | Reprovide strategies: `Reprovider` service with `pinned`, `roots`, `all`, and `pinned+mfs` strategies, plus `unique`/`entities` variants. |
| P1 | APPROVED | DHT Provide Sweep optimization: XOR-ordered reprovide and proximity grouping inside the `Reprovider` service. |
| P1 | MODIFIED | On-demand provide refinement: enrich existing `/api/v0/dht/provide` and `DHTHandler.provide` with explicit `once` semantics, success/failure feedback, and optional queueing; do **not** create a separate duplicate feature. |

---

## 2. References & Standards

### 2.1 IPFS Gateway Specifications

- [IPFS HTTP Gateway Specs](https://specs.ipfs.tech/http-gateways/) — path-based, subdomain, and trustless gateway semantics.
- [IPFS Trustless Gateway Spec](https://specs.ipfs.tech/http-gateways/trustless-gateway/) — `Accept` and `?format=` negotiation for raw block, CAR, IPNS-record, DAG-JSON, and DAG-CBOR responses.
- [IPFS Subdomain Gateway Spec](https://specs.ipfs.tech/http-gateways/subdomain-gateway/) — `{cid}.ipfs.{gateway}` and `{name}.ipns.{gateway}` host parsing, origin isolation, and DNSLink support.
- [IPFS Gateway Specification - Path Gateway](https://specs.ipfs.tech/http-gateways/path-gateway/) — path routing, `index.html` handling, and response headers.

### 2.2 Kubo RPC & CLI Conventions

- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — endpoint paths, query parameters, request/response formats, and NDJSON streaming.
- [Kubo `files` command reference](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-files) — MFS semantics and flags.
- [Kubo `dht provide` reference](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-dht-provide) — on-demand provider announcement semantics.
- [Kubo `routing` / reprovide](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-routing) — reprovide strategy names and defaults.

### 2.3 Metrics & Observability Conventions

- [Prometheus Exposition Formats](https://prometheus.io/docs/instrumenting/exposition_formats/) — text format, metric naming, label escaping, and histogram conventions.
- [Prometheus Metric and Label Naming](https://prometheus.io/docs/practices/naming/) — `ipfs_<subsystem>_<unit>` style, base units, `_total`, `_bytes`, `_seconds`, `_count`, `_sum`.
- [OpenTelemetry](https://opentelemetry.io/docs/) — deferred for v2.0; reserved for future mapping once metrics are solid.

### 2.4 Content Blocking & Denylist References

- [BadBits Denylist](https://badbits.dwebops.pub/) — community CID/multihash denylist format and tooling.
- [IPFS Gateway Content Blocking](https://specs.ipfs.tech/http-gateways/) operator guidance — default-off, auditable, and privacy-preserving blocking.

### 2.5 Internal References

- `lib/src/core/mfs/mfs_manager.dart` — existing MFS implementation.
- `lib/src/services/gateway/gateway_handler.dart` — `GatewayHandler` and `handleSubdomain` stub.
- `lib/src/services/gateway/gateway_server.dart` — gateway routing and middleware.
- `lib/src/services/gateway/content_type_handler.dart` — content type handling (currently converts CAR to HTML).
- `lib/src/core/metrics/metrics_collector.dart` — stub metrics collector.
- `lib/src/core/metrics/network_metrics.dart` — per-peer/protocol metrics skeleton.
- `lib/src/core/config/metrics_config.dart` — metrics configuration.
- `lib/src/services/rpc/rpc_handlers.dart` / `rpc_server.dart` — RPC handler registration and middleware.
- `lib/src/protocols/dht/dht_handler.dart` / `dht_client.dart` — DHT operations and provider announcement.
- `lib/src/core/security/security_manager.dart` — security and authentication.
- `lib/src/core/config/security_config.dart` — security configuration.
- `lib/src/core/config/dht_config.dart` — DHT configuration.
- `lib/src/core/data_structures/pin_manager.dart` — pin tracking.
- `ROADMAP.md` — v2.0 parity backlog section.

---

## 3. Current-State Gaps in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| **MFS core** | `MFSManager` has `read`, `write`, `stat`, `ls`, `cp`, `mkdir`, `rm`. | No `flush`/`sync` semantics; no RPC handlers for `/api/v0/files/*`; `stat` lacks Kubo fields (`with-local`, `hash`, `size`); directory sizes are not cumulative. |
| **Subdomain gateway** | `GatewayHandler.handleSubdomain` is a partial stub at lines 270–289; not wired into `GatewayServer`. | No strict host/CID validation, no IPNS/DNSLink support, no origin isolation, no path routing. |
| **Trustless gateway** | `GatewayHandler` always renders directories/CARs as HTML; `ContentTypeHandler._processCarArchive` returns HTML. | Does not honor `Accept` or `?format=` for raw block, CAR, IPNS-record, DAG-JSON, or DAG-CBOR; fails Kubo/Helia interop for programmatic clients. |
| **Metrics** | `MetricsCollector` returns stub zeros; `NetworkMetrics` increments null entries; `MetricsConfig.enablePrometheusExport` is unwired. | No real counters/histograms; no `/metrics` endpoint; operators cannot observe node health. |
| **OpenTelemetry** | No OTel dependencies or design. | Deferred until metrics foundation is solid. |
| **Content blocking** | `SecurityManager` only blocks auth clients; no denylist module. | No operator-controlled CID/multihash denylist; no BadBits-style compact format support. |
| **Reprovide strategies** | No periodic `Reprovider`; `DHTHandler.provide` only announces a single CID once. | No `pinned`, `roots`, `all`, `pinned+mfs`, `unique`, or `entities` strategies. |
| **DHT Provide Sweep** | `DHTClient.addProvider` sends to the closest 20 peers without XOR ordering or batching. | Wastes bandwidth, misses proximity grouping, and lacks reprovide sweep optimization. |
| **On-demand provide** | `/api/v0/dht/provide` returns only `{Success: true}` with no feedback. | No explicit `once` semantics, no success/failure counts, no optional queueing. |

---

## 4. Detailed Per-Item Specification

All items below must be implemented **without expanding scope** beyond what is specified. Any deviation requires a new Ciel Council deliberation.

---

### 4.1 P0 APPROVED — MFS Completeness

#### 4.1.1 Goal

Complete the Mutable File System (MFS) layer so that `MFSManager` supports Kubo-compatible `flush`, `sync`, and the full `/api/v0/files/*` RPC surface. Ensure `read`, `write`, `stat`, and `ls` semantics match Kubo.

#### 4.1.2 Internal API Additions

Extend `MFSManager` in `lib/src/core/mfs/mfs_manager.dart` with the following methods. All operations must continue to persist the root CID in `/mfs/root` after any mutation.

```text
MFSManager
├── flush({String? path})                → Future<CID>
├── flushAll()                           → Future<CID>
├── sync()                               → Future<void>
├── stat(String path, {bool withLocal = false}) → Future<MFSStat>
├── ls(String path, {bool long = false, bool u = false}) → Future<List<MFSListEntry>>
├── read(String path, {int? offset, int? count}) → Future<Stream<List<int>>>
├── write(String path, Stream<List<int>> data, {bool create = true, int? offset, bool truncate = true}) → Future<void>
├── cp(String src, String dst)           → Future<void>
├── mv(String src, String dst)           → Future<void>
├── rm(String path, {bool recursive = false, bool force = false}) → Future<void>
├── mkdir(String path, {bool recursive = false, bool parents = false}) → Future<void>
└── chcid(String path, {String? cid, String? hash = 'sha2-256'}) → Future<void>
```

**Semantics:**

- `flush([path])`: ensures the current MFS state is persisted and returns the current root CID. The existing implementation persists the root CID after every mutation (`_modifyPath` in `lib/src/core/mfs/mfs_manager.dart`), so `flush` is effectively a synchronous root-CID accessor that may return the existing root without re-hashing. If a future implementation introduces a write-back cache, `flush` must force any pending mutations to the blockstore and persist the root CID before returning.
- `flushAll()`: equivalent to `flush('/')`.
- `sync()`: wait for all in-flight MFS operations to complete and persist the root CID; returns `void` (no new CID guaranteed if no writes are pending).
- `stat`: return Kubo-compatible metadata including `Hash`, `Size`, `CumulativeSize`, `Blocks`, `Type`, `WithLocal` (if requested), and `Local`.
- `ls`: return entries with `Name`, `Type`, `Size`, `Hash`, and optional `Mode`/`Mtime` when `long=true`.
- `write`: support `offset` for partial writes (Kubo `offset` parameter); `truncate=true` replaces existing content; `truncate=false` with `offset=0` requires existing file. Throws `ArgumentError` if offset is beyond file size and `truncate=false`. For `truncate=false`, the implementation must read the existing UnixFS file, replace the affected byte range, and re-chunk only the modified segment if possible, preserving unmodified chunk CIDs where the chunking algorithm allows.
- `chcid`: re-hashes the CID for a path (or the whole MFS root if `path='/'`) using the requested multihash function. The current `CID.fromContent` only supports `sha2-256`; changing to any other hash function requires a full re-encode/re-layout pass of the affected DAG.

#### 4.1.3 Data Models

```text
MFSStat
  Hash: string (CID)
  Size: int (file bytes, 0 for directories)
  CumulativeSize: int (UnixFS cumulative size)
  Blocks: int (link count)
  Type: string ("file" | "directory" | "raw")
  WithLocal: bool?
  Local: bool?
  Mode: int? (optional, UNIX mode)
  Mtime: int? (optional, seconds since epoch)

MFSListEntry
  Name: string
  Type: int (Kubo: 0=raw, 1=directory, 2=file)
  Size: int
  Hash: string
  Mode: int? (when long=true)
  Mtime: int? (when long=true)
```

#### 4.1.4 RPC Endpoints

Register the following handlers in `lib/src/services/rpc/rpc_handlers.dart` and wire them in `RPCServer`:

| Method | Endpoint | Kubo-compatible parameters |
|--------|----------|-----------------------------|
| POST | `/api/v0/files/ls` | `arg` (path), `long`, `U` (unsorted) |
| POST | `/api/v0/files/stat` | `arg`, `with-local`, `size` (hash only), `cid-base` |
| POST | `/api/v0/files/read` | `arg`, `offset`, `count` |
| POST | `/api/v0/files/write` | `arg` (multipart file body), `create`, `offset`, `truncate`, `count`, `raw-leaves`, `cid-version` |
| POST | `/api/v0/files/mkdir` | `arg`, `parents`/`recursive`, `cid-version`, `hash` |
| POST | `/api/v0/files/cp` | `arg` (source), `arg` (destination) — two `arg` params |
| POST | `/api/v0/files/mv` | `arg` (source), `arg` (destination) |
| POST | `/api/v0/files/rm` | `arg`, `recursive`, `force` |
| POST | `/api/v0/files/flush` | `arg` (default `/`) |
| POST | `/api/v0/files/chcid` | `arg`, `cid-version`, `hash` |

**Response formats:**

- `files/ls`: returns a single JSON object with `Entries` array and `Hash`.

```json
{
  "Entries": [
    {"Name": "foo.txt", "Type": 2, "Size": 12, "Hash": "Qm..."}
  ],
  "Hash": "Qm..."
}
```

- `files/stat`: returns Kubo-style JSON.

```json
{
  "Hash": "Qm...",
  "Size": 12,
  "CumulativeSize": 256,
  "Blocks": 1,
  "Type": "file"
}
```

- `files/read`: returns raw bytes with `Content-Type: application/octet-stream`.

- `files/write`: returns `200 OK` with empty body on success; supports multipart body identical to `/api/v0/add`.

- `files/flush`: returns JSON `{ "Hash": "<root-cid>" }`.

- `files/cp`, `files/mv`, `files/rm`, `files/mkdir`, `files/chcid`: return `200 OK` with empty body on success, or a Kubo-style error JSON on failure.

#### 4.1.5 Acceptance Criteria

- [ ] `MFSManager` passes a Kubo parity test matrix for `write/read/stat/ls/cp/mv/rm/mkdir/flush` on files and directories.
- [ ] `flush` persists the root CID and returns the correct root CID.
- [ ] All `/api/v0/files/*` endpoints listed above are registered and return Kubo-compatible JSON.
- [ ] Path validation rejects traversal outside the MFS root (`../` must be normalized and blocked at root).
- [ ] Multipart `files/write` supports the same file-size limits and boundary parsing as `handleAdd`.
- [ ] No existing MFS public API signatures are removed; only additive changes are allowed.
- [ ] `flush` on an already-persistent MFS returns the same root CID idempotently.
- [ ] `MFSManager` remains usable without RPC (internal API tests are standalone).

---

### 4.2 P1 APPROVED — Subdomain Gateway

#### 4.2.1 Goal

Complete `GatewayHandler.handleSubdomain` so that requests to `{cid}.ipfs.{gateway}` and `{name}.ipns.{gateway}` are served correctly, with strict host/CID validation, optional DNSLink resolution, and proper routing in `GatewayServer`.

#### 4.2.2 Host Parsing Rules

Given the configured `gatewayDomain` (e.g., `localhost` for local development, or `ipfs.example.com` for production), the handler must parse the request `Host` header:

| Host pattern | Namespace | Identifier | Subpath |
|--------------|-----------|------------|---------|
| `<cid>.ipfs.<gatewayDomain>` | ipfs | base32-encoded CIDv1 (CIDv0 must be converted to CIDv1 base32) | `request.url.path` |
| `<cid>.ipfs.localhost` | ipfs | base32-encoded CIDv1 | `request.url.path` |
| `<name>.ipns.<gatewayDomain>` | ipns | PeerId, DNSLink domain, or IPNS key | `request.url.path` |

Requirements:

- The host must contain exactly one namespace label (`ipfs` or `ipns`) immediately before the configured domain/TLD.
- DNS labels are case-insensitive and cannot contain CIDv0 base58btc characters, so the leftmost `ipfs` label must be a CIDv1 encoded in base32. CIDv0 or other encodings must return `400 Bad Request` with `Content-Type: text/plain; charset=utf-8` and body `Invalid CID in subdomain`.
- Production deployments require a wildcard DNS record (`*.ipfs.<gatewayDomain>` and `*.ipns.<gatewayDomain>`) and a TLS certificate covering that wildcard (or per-subdomain certificates). `localhost` development uses `*.ipfs.localhost` and does not require TLS.
- For `ipns`, the leftmost label must be either a valid PeerId (base58btc), a DNSLink-compatible DNS name (e.g., `docs.ipfs.io`), or an IPNS key resolved via the configured IPNS resolver. Invalid names return `400 Bad Request`.
- The gateway must reject requests to bare `<gatewayDomain>` that do not match a subdomain namespace; fallback to path gateway remains handled by the existing `/ipfs/<path|.*>` and `/ipns/<path|.*>` routes.
- Localhost subdomain requests (`*.ipfs.localhost`) must be supported regardless of the configured `gatewayDomain`.

#### 4.2.3 Configuration Additions

Extend `GatewayConfig` in `lib/src/core/config/gateway_config.dart` with:

```text
GatewayConfig
  gatewayDomain: String?          // e.g. "ipfs.example.com"; null means subdomain gateway disabled except localhost
  enableSubdomainGateway: bool   // default false
  subdomainDNSLinkResolver: bool  // default true
  subdomainTLSRedirect: bool      // default false; operators must opt in explicitly
```

`GatewayServer` must pass these values to `GatewayHandler`.

#### 4.2.4 Internal API Additions

```text
GatewayHandler
  handleSubdomain(Request request) → Future<Response>
  _parseSubdomainHost(String host) → SubdomainRequest?   // returns null if not a subdomain request
  _validateSubdomainCid(String cidStr) → CID?
  _resolveSubdomainIpns(String name) → Future<String>   // returns CID string or throws
```

```text
SubdomainRequest
  namespace: "ipfs" | "ipns"
  identifier: string
  subPath: string
  gatewayDomain: string
```

#### 4.2.5 Routing and Response Semantics

- After resolving the identifier to a CID, delegate to the existing `_serveContent(cid, subPath, request)` path, preserving all trustless gateway response logic (§4.3).
- Set response headers `Access-Control-Allow-Origin: *` (or configured CORS) for subdomain origins.
- Add `X-IPFS-Path: /ipfs/<cid>` or `/ipns/<name>` to responses.
- For IPNS names, add `Cache-Control: public, max-age=<ttl>` where TTL is the resolved IPNS record TTL (default 1 minute if unavailable).
- For DNSLink domains, add `X-IPFS-DNSLink: <domain>` header.
- `subdomainTLSRedirect` is `false` by default. When explicitly set to `true`, `gatewayDomain` is non-null, and the domain is not `localhost`/`127.0.0.1`, HTTP requests may be redirected to HTTPS with a `301 Moved Permanently` and `Location: https://<same-host><path>`. TLS redirect must never be enabled for `localhost` or unspecified domains.

#### 4.2.6 Security / Origin Isolation

- Subdomain responses must not leak path-gateway cookies or local storage; `Access-Control-Allow-Credentials` must remain `false` for subdomain origins.
- `gatewayDomain` must be validated against a configurable allow-list to prevent arbitrary `Host` header injection attacks.

#### 4.2.7 Acceptance Criteria

- [ ] `handleSubdomain` is registered in `GatewayServer` for all incoming requests before path-gateway fallback.
- [ ] Valid CID subdomains return the requested content.
- [ ] Invalid CID subdomains return `400 Bad Request`.
- [ ] IPNS subdomains resolve through the configured IPNS resolver and serve content.
- [ ] DNSLink subdomains resolve via `DNSLinkResolver` and serve content.
- [ ] Path-gateway fallback remains unchanged for non-subdomain hosts.
- [ ] All existing gateway tests continue to pass.
- [ ] Requests to `Host: <gatewayDomain>` (bare domain) fall back to the path gateway and are not treated as a subdomain error.
- [ ] CORS headers on subdomain responses do not include `Access-Control-Allow-Credentials: true`.
- [ ] DNSLink resolution failures return `400` or `502` consistently and do not crash the gateway.

---

### 4.3 P0 APPROVED — Trustless Gateway Full Compliance

#### 4.3.1 Goal

Make the gateway honor `Accept` request headers and `?format=` query parameters for trustless retrievals, returning raw block, CAR, IPNS-record, DAG-JSON, and DAG-CBOR responses without rendering HTML.

#### 4.3.2 Supported Formats and Content Types

| Format | `?format=` value | `Accept` media type | Response `Content-Type` | Notes |
|--------|------------------|---------------------|-------------------------|-------|
| Raw block | `raw` | `application/vnd.ipfs.raw-block` | `application/vnd.ipfs.raw-block` | Single block bytes; only valid for CID that is a raw block or UnixFS leaf. |
| CAR | `car` | `application/vnd.ipfs.car` | `application/vnd.ipfs.car` | CAR v1 archive of the DAG rooted at the requested CID. |
| IPNS record | `ipns-record` | `application/vnd.ipfs.ipns-record` | `application/vnd.ipfs.ipns-record` | For `/ipns/<name>` paths; returns the signed IPNS record bytes. |
| DAG-JSON | `dag-json` | `application/vnd.ipld.dag-json` | `application/vnd.ipld.dag-json` | DAG node serialized as DAG-JSON. |
| DAG-CBOR | `dag-cbor` | `application/vnd.ipld.dag-cbor` | `application/vnd.ipld.dag-cbor` | DAG node serialized as DAG-CBOR. |

Default (no format negotiation): continue existing path-gateway behavior (HTML directory listings, detected MIME types, etc.).

#### 4.3.3 Negotiation Precedence

1. `?format=<format>` query parameter (highest precedence).
2. `Accept` header media type matching one of the supported media types.
3. Default path-gateway behavior.

If both `?format=` and `Accept` are present, `?format=` wins. If `Accept` contains multiple supported media types, use the first supported match in the header order.

#### 4.3.4 CAR Response Requirements

- Generate a **CAR v1** archive using the standard `CarWriter` from `CAR_FORMAT_SPEC.md`, with a single root CID equal to the requested CID.
- Include all blocks reachable from the root CID through the requested sub-path (if any) up to the full DAG.
- Use varint-prefixed CID+block frames per the CAR v1 spec.
- Set `Content-Disposition: attachment; filename="<cid>.car"`.
- Do **not** convert CAR data to HTML under any trustless request.
- CAR traversal must be bounded by a configurable maximum DAG depth and/or total block count; when a bound is exceeded, return `416` or `413` per the implementation policy.

#### 4.3.5 Raw Block Response Requirements

- Return the exact block bytes for the requested CID.
- If the CID points to a directory, return the raw encoded DAG-PB bytes (not an HTML listing).
- If the block is not found locally, attempt Bitswap retrieval before returning `404 Not Found`.

#### 4.3.6 IPNS Record Response Requirements

- Only applicable to `/ipns/<name>` paths or `ipns-record` format requests.
- Return the signed IPNS record protobuf bytes (the value stored in the DHT / IPNS store).
- If no record is found, return `404 Not Found` with body `IPNS record not found`.

#### 4.3.7 DAG-JSON / DAG-CBOR Response Requirements

- Decode the requested CID block using the appropriate codec and re-encode as DAG-JSON or DAG-CBOR.
- For UnixFS DAG-PB nodes, return the structured DAG-PB representation (`Data`, `Links`) rather than the raw protobuf bytes.
- For DAG-CBOR nodes, return the re-encoded DAG-CBOR bytes.

#### 4.3.8 Internal API Additions

```text
GatewayHandler
  _detectTrustlessFormat(Request request) → TrustlessFormat?
  _serveRawBlock(CID cid, Request request) → Response
  _serveCar(CID cid, String subPath, Request request) → Future<Response>
  _serveIpnsRecord(String name, Request request) → Future<Response>
  _serveDagJson(CID cid, Request request) → Future<Response>
  _serveDagCbor(CID cid, Request request) → Future<Response>

ContentTypeHandler
  must remove _processCarArchive HTML conversion for trustless formats
```

```text
TrustlessFormat
  raw | car | ipnsRecord | dagJson | dagCbor
```

#### 4.3.9 Acceptance Criteria

- [ ] `?format=raw` returns raw block bytes for files and directories.
- [ ] `?format=car` returns a valid CAR v1 archive with the correct root CID.
- [ ] `?format=ipns-record` returns the signed IPNS record bytes for `/ipns/` paths.
- [ ] `?format=dag-json` and `?format=dag-cbor` return spec-compliant encoded data.
- [ ] `Accept` header negotiation works for all supported media types.
- [ ] CAR files are never converted to HTML when a trustless format is requested.
- [ ] Directory listings continue to render HTML only when no trustless format is requested.
- [ ] Interop test passes against Kubo `curl -H "Accept: application/vnd.ipfs.car" http://localhost:8080/ipfs/<cid>`.

---

### 4.4 P0 APPROVED — Real Metrics Collection

#### 4.4.1 Goal

Replace the stub `MetricsCollector` getters and broken `NetworkMetrics` increment logic with real Prometheus-compatible counters and histograms, and expose them on the configured `/metrics` endpoint.

#### 4.4.2 Existing Issues to Fix

- `MetricsCollector.getMessagesSent`, `getMessagesReceived`, `getBytesSent`, `getBytesReceived`, and `getAverageLatency` all return hardcoded `0`.
- `NetworkMetrics.recordMessageSent` does `peerMetrics[peer]?.messagesSent++` on a null entry, which has no effect.
- `MetricsConfig.enablePrometheusExport` and `prometheusEndpoint` are not consumed by `GatewayServer` or `RPCServer`.

#### 4.4.3 Metric Catalog

The following metrics must be maintained. All metric names follow Prometheus conventions. All counters are monotonically increasing; all gauges reflect current state; histograms use seconds.

| Name | Type | Labels | Description |
|------|------|--------|-------------|
| `ipfs_messages_sent_total` | Counter | `protocol` | Total P2P messages sent. |
| `ipfs_messages_received_total` | Counter | `protocol` | Total P2P messages received. |
| `ipfs_bytes_sent_total` | Counter | `protocol` | Total bytes sent. |
| `ipfs_bytes_received_total` | Counter | `protocol` | Total bytes received. |
| `ipfs_latency_seconds` | Histogram | `protocol` | Round-trip latency distribution. |
| `ipfs_peers_connected` | Gauge | — | Number of currently connected peers. |
| `ipfs_routing_table_size` | Gauge | — | Number of peers in the Kademlia routing table. |
| `ipfs_blockstore_blocks` | Gauge | — | Number of blocks in the local blockstore. |
| `ipfs_blockstore_bytes` | Gauge | — | Total bytes stored in the local blockstore. |
| `ipfs_gateway_requests_total` | Counter | `namespace`, `method`, `status` | Total HTTP gateway requests. |
| `ipfs_gateway_request_duration_seconds` | Histogram | `namespace`, `method` | Gateway request latency. |
| `ipfs_rpc_requests_total` | Counter | `method`, `endpoint`, `status` | Total RPC API requests. |
| `ipfs_rpc_request_duration_seconds` | Histogram | `endpoint` | RPC request latency. |
| `ipfs_dht_provides_total` | Counter | `status` | Total provider announcements attempted. |
| `ipfs_dht_reprovide_runs_total` | Counter | `strategy`, `status` | Total reprovide runs. |
| `ipfs_dht_reprovide_duration_seconds` | Histogram | `strategy` | Reprovide run duration. |
| `ipfs_security_events_total` | Counter | `type` | Security events (rate limit, blocked CID, auth failure). |

#### 4.4.4 Internal API Additions

```text
MetricsCollector
  recordMessageSent(protocol, bytes) → void
  recordMessageReceived(protocol, bytes) → void
  recordLatency(protocol, Duration) → void
  recordPeerConnected() → void
  recordPeerDisconnected() → void
  recordRoutingTableSize(int) → void
  recordBlockstoreStats(int blocks, int bytes) → void
  recordGatewayRequest(String namespace, String method, int status, Duration duration) → void
  recordRpcRequest(String endpoint, String method, int status, Duration duration) → void
  recordDhtProvide(bool success) → void
  recordReprovide(String strategy, bool success, Duration duration) → void
  recordSecurityEvent(String type) → void
  getPrometheusMetrics() → Future<String>   // Prometheus text format
  reset() → void                         // test-only
```

Use the existing `prometheus_client` dependency (already in `pubspec.yaml` at line 38).

The existing `metricsStream` broadcast stream remains a legacy/secondary event channel; production telemetry should use the Prometheus exposition endpoint and the new `record*` methods. The `method` parameter in `recordRpcRequest` is retained for logging/debugging but is not included in the `ipfs_rpc_request_duration_seconds` histogram; only the `endpoint` label is used there.

#### 4.4.5 Endpoint Wiring

- In `GatewayServer`, when `MetricsConfig.enablePrometheusExport` is true, register:
  - `GET /metrics` → `MetricsCollector.getPrometheusMetrics()` with `Content-Type: text/plain; version=0.0.4; charset=utf-8`.
- In `RPCServer`, optionally expose the same endpoint on the same port if the RPC server is configured to do so (configurable via `MetricsConfig`, default only on gateway port to avoid duplication).
- The `MetricsCollector` must be registered as an `ILifecycle` service in `LifecycleManager`.

#### 4.4.6 Collection Intervals

- When `IPFSConfig.metrics.enabled` is true, start a periodic collection timer in `MetricsCollector.start()` with `collectionIntervalSeconds`.
- The timer must collect blockstore and routing table statistics, and update gauges.
- The timer must be cancelled in `stop()`.

#### 4.4.7 Acceptance Criteria

- [ ] `MetricsCollector` no longer returns hardcoded zeros; all getters return real accumulated values.
- [ ] `NetworkMetrics` initializes `PeerMetrics` and `ProtocolMetrics` on first record.
- [ ] `GET /metrics` returns valid Prometheus text format when enabled.
- [ ] `ipfs_gateway_requests_total` and `ipfs_rpc_requests_total` increment on every request.
- [ ] Histograms have default buckets `[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]`.
- [ ] Metrics collection does not block request handling; all increments are O(1).
- [ ] Disabled metrics (`IPFSConfig.metrics.enabled=false`) imposes zero overhead beyond a single boolean check.
- [ ] The `/metrics` body parses without error using the official `prometheus_client` parser.
- [ ] `LifecycleManager` calls `start()` and `stop()` on `MetricsCollector`, and the periodic collection timer is cancelled cleanly in `stop()`.
- [ ] No metric label contains `\n`, `\`, or `"` characters after sanitization.

---

### 4.5 P2 DEFERRED — OpenTelemetry Support

#### 4.5.1 Rationale

OpenTelemetry is deferred because:

- No OTel infrastructure or dependencies exist today.
- The Prometheus metrics foundation must be proven production-grade before adding tracing/OTLP export complexity.
- A lightweight Dart OTel path needs to be selected (no official OTel SDK exists for Dart).

#### 4.5.2 Revisit Criteria

OpenTelemetry may be revisited when:

- `MetricsCollector` is fully implemented and the `/metrics` endpoint has been running in production tests for at least one release cycle.
- A stable Dart OTel package or vendor integration is available.
- A concrete use case (e.g., distributed tracing for gateway requests) is defined.

---

### 4.6 P1 APPROVED — Content Blocking / Compact Denylist

#### 4.6.1 Goal

Add an operator-controlled content denylist service that can block CID or multihash retrieval at the gateway and RPC layers. It must be **default-off**, auditable, and independent from the existing authentication rate-limiting in `SecurityManager`.

#### 4.6.2 Configuration Additions

Extend `SecurityConfig` in `lib/src/core/config/security_config.dart` with:

```text
SecurityConfig
  enableDenylist: bool              // default false
  denylistPath: String?              // local file path or HTTP(S) URL
  denylistRefreshInterval: Duration // default 1 hour
  denylistCompactFormat: bool        // default true (BadBits-style)
  denylistDefaultAction: "block" | "log" // default "block"
```

#### 4.6.3 Denylist Service API

Create a new `DenylistService` (location TBD by implementer, recommended `lib/src/core/security/denylist_service.dart`):

```text
DenylistService implements ILifecycle
  DenylistService(SecurityConfig, MetricsCollector)
  start() → Future<void>   // loads initial list and starts refresh timer
  stop() → Future<void>    // cancels timer
  isBlocked(CID cid) → bool
  isBlockedByMultihash(String multihash) → bool
  isBlockedByCidString(String cidStr) → bool
  loadFromPath(String path) → Future<void>
  loadFromUrl(String url) → Future<void>
  loadCompactBytes(Uint8List bytes) → void
  getStats() → DenylistStats
  getAuditLog() → List<DenylistAuditEvent>
```

```text
DenylistStats
  loadedEntries: int
  lastRefresh: DateTime?
  refreshErrors: int

DenylistAuditEvent
  timestamp: DateTime
  cidOrMultihash: String
  action: "blocked" | "logged" | "allowed"
  source: "gateway" | "rpc" | "dht"
  reason: String?         // optional operator-provided reason from list metadata
```

#### 4.6.4 Compact Denylist Format

Support the BadBits-style compact format:

- A text file with one entry per line.
- The parser must classify each line in this exact order:
  1. Skip empty lines and lines that begin with a plain `#` comment.
  2. If a line begins with `#` and the remainder is valid JSON, parse it as a JSON comment containing metadata such as `{"reason": "...", "cid": "..."}`.
  3. Attempt to decode the line as a CID string.
  4. Attempt to decode the line as a base32-encoded multihash (lowercase).
  5. If none of the above succeed, skip the line and count it as a refresh warning.
- When `denylistCompactFormat=true`, entries may be sorted and deduplicated for binary-search lookup.
- Also support plain text lists of CID strings for backward compatibility.
- Maximum line length: 4096 characters; longer lines are skipped and counted as a refresh warning.
- Maximum denylist size: 1,000,000 entries or 256 MiB; exceeding this fails the refresh atomically and keeps the previous list active.

#### 4.6.5 Gateway and RPC Integration

- In `GatewayHandler.handlePath` and `GatewayHandler.handleSubdomain`, check `DenylistService.isBlockedByCidString(cidStr)` before serving. If blocked and `defaultAction="block"`, return `451 Unavailable For Legal Reasons` with body `Content blocked by operator policy`. If `defaultAction="log"`, serve the content but record an audit event with `action="logged"` and emit `MetricsCollector.recordSecurityEvent("denylist_logged")`. Logged events do not increment `refreshErrors`.
- In `RPCHandlers.handleCat`, `handleBlockGet`, `handleDagGet`, and `handleDhtProvide`, check the denylist before processing. Return Kubo-style error JSON with `Code: 451` and `Message: Content blocked by operator policy` when blocked.
- In `DHTHandler.handleProvideRequest`, reject provider announcements for blocked CIDs.

#### 4.6.6 Audit and Misuse Prevention

- Denylist hits must be recorded in `DenylistService.auditLog` with a maximum size (default 10,000 entries; FIFO eviction).
- The denylist must be **default-off**; enabling it requires explicit operator configuration.
- No hardcoded denylist entries are allowed in the package.
- The service must log a warning on startup when enabled, including the source path and entry count.
- Refreshes must be atomic: a new in-memory set is built from a complete successful parse, then swapped in. Partial or corrupt refreshes are discarded and the previously loaded list remains active.

#### 4.6.7 Acceptance Criteria

- [ ] `DenylistService` is default-off and has no effect on request handling when disabled.
- [ ] Blocking a CID returns `451` on the gateway and a Kubo-style error on RPC.
- [ ] Compact multihash lists load and match correctly.
- [ ] Audit log records every blocked/logged request with timestamp and source.
- [ ] Refresh interval reloads the list without dropping requests.
- [ ] Failed URL refreshes increment `refreshErrors` and log a warning but do not crash the node.
- [ ] `denylistDefaultAction="log"` records an audit event with `action="logged"` and does not increment `refreshErrors`.
- [ ] Denylist refreshes are atomic; a partial or corrupt refresh keeps the previous list active.
- [ ] `DenylistService` is registered as an `ILifecycle` service and started/stopped by `LifecycleManager`.
- [ ] The maximum denylist size (1,000,000 entries or 256 MiB) and maximum line length (4096 characters) are enforced.

---

### 4.7 P1 APPROVED — Reprovide Strategies

#### 4.7.1 Goal

Implement a `Reprovider` service that periodically announces local content to the DHT using pluggable strategies. The service must integrate with the existing `DHTHandler`/`DHTClient` and be controllable via configuration.

#### 4.7.2 Strategies

| Strategy | Description | CIDs Announced |
|----------|-------------|----------------|
| `pinned` | Reprovide all recursively pinned CIDs. | All recursive pins. |
| `roots` | Reprovide only the root CIDs of pinned DAGs. | Top-level recursive pins only. |
| `all` | Reprovide every CID in the local blockstore. | All local blocks. |
| `pinned+mfs` | Reprovide recursive pins plus the current MFS root. | Recursive pins + `MFSManager.rootCid`. |
| `unique` | Same as `pinned` but deduplicates CIDs before providing. | Deduplicated set of recursive pins. |
| `entities` | Reprovide root-level entities only (pins + MFS root + any explicit content roots). | Union of `roots` and MFS root. |

Default strategy: `pinned`.

#### 4.7.3 Configuration Additions

Extend `DHTConfig` in `lib/src/core/config/dht_config.dart` with:

```text
DHTConfig
  reproviderEnabled: bool        // default true when DHT server mode
  reproviderInterval: Duration   // default 12 hours
  reproviderStrategy: String      // default "pinned"
  reproviderBatchSize: int        // default 100
  reproviderConcurrency: int       // default 10
```

#### 4.7.4 Internal API Additions

```text
Reprovider implements ILifecycle
  Reprovider(DHTConfig, DHTHandler, PinManager, MFSManager, MetricsCollector)
  start() → Future<void>          // schedules periodic runs
  stop() → Future<void>            // cancels timer and waits for in-flight runs
  trigger({bool wait = false}) → Future<ReproviderResult>  // manual run
  getStatus() → ReproviderStatus
  setStrategy(String strategy) → void  // validates against supported list

ReproviderResult
  strategy: String
  attempted: int
  succeeded: int
  failed: int
  duration: Duration
  errors: List<String>
  groupedCids: Map<PeerId, List<CID>>?  // populated when sweep optimization enabled

ReproviderStatus
  lastRun: DateTime?
  lastResult: ReproviderResult?
  nextRun: DateTime?
  strategy: String
  running: bool
```

#### 4.7.5 Reprovide Run Semantics

1. Collect CIDs according to the selected strategy.
2. Deduplicate CIDs (all strategies must deduplicate).
3. If DHT Provide Sweep optimization is enabled (§4.8), group CIDs by proximity to the same closest peers.
4. For each CID, call `DHTHandler.provide(CID)` or the optimized batch equivalent.
5. Record metrics: `ipfs_dht_reprovide_runs_total`, `ipfs_dht_reprovide_duration_seconds`, and `ipfs_dht_provides_total`.
6. Return `ReproviderResult`.

#### 4.7.6 Acceptance Criteria

- [ ] All six strategies are selectable via configuration.
- [ ] Default strategy `pinned` reprovides all recursive pins.
- [ ] `pinned+mfs` includes the MFS root.
- [ ] `all` reprovides every block in the local blockstore without duplication.
- [ ] Periodic runs respect the configured interval.
- [ ] Manual `trigger()` returns accurate `attempted`, `succeeded`, and `failed` counts.
- [ ] The service is registered in `LifecycleManager` and starts/stops cleanly.

---

### 4.8 P1 APPROVED — DHT Provide Sweep Optimization

#### 4.8.1 Goal

Optimize the reprovide process inside the `Reprovider` service by ordering CIDs by XOR distance to peer IDs and grouping nearby CIDs so each DHT `ADD_PROVIDER` request can cover multiple CIDs when the target peers are the same.

#### 4.8.2 XOR-Ordered Reprovide

- For each CID to be reprovided, compute the DHT routing key: `SHA256(multihash)`.
- Sort the CID list by XOR distance from the local peer ID to enable routing-table locality.
- This ordering does not change which CIDs are announced; it only improves batching and reduces routing-table churn.

#### 4.8.3 Proximity Grouping

- For each CID, identify the `K` closest peers from the local routing table (`K = DHTConfig.bucketSize`, default 20).
- Group CIDs that share the same closest peer set (or a high overlap threshold, e.g., ≥80% of peers in common).
- For each group, send a single `ADD_PROVIDER` message per peer with the group of CIDs, instead of one message per CID per peer.
- If the wire protocol does not support multiple keys per `ADD_PROVIDER` message, batch at the transport layer by sending sequential `ADD_PROVIDER` messages over the same open stream/connection.

#### 4.8.4 Internal API Additions

```text
Reprovider
  _sweepOptimizedProvide(List<CID> cids) → Future<ReproviderResult>
  _groupByClosestPeers(List<CID> cids, double overlapThreshold) → List<CidGroup>
  _xorDistance(PeerId a, PeerId b) → Uint8List

CidGroup
  cids: List<CID>
  peers: List<PeerId>
```

#### 4.8.5 DHTClient Additions

Extend `DHTClient` with:

```text
DHTClient
  addProviders(List<CID> cids, String providerId) → Future<void>
```

Implementation must:

- Compute the closest peers for each CID once.
- Group by target peer.
- Send `ADD_PROVIDER` messages for the batch.
- Return when all messages are acknowledged or timed out.

#### 4.8.6 Acceptance Criteria

- [ ] Reprovide runs group CIDs by closest-peer overlap.
- [ ] The number of DHT messages sent for a reprovide run is measurably lower than the naive one-message-per-CID approach in unit tests (use a mock router to assert message count).
- [ ] XOR ordering does not change which CIDs are announced or which peers receive them.
- [ ] Optimization is enabled by default when `reproviderEnabled` is true; can be disabled via config flag `reproviderSweepOptimization=false` if added.

---

### 4.9 P1 MODIFIED — On-Demand Provide Refinement

#### 4.9.1 Goal

Enrich the existing `/api/v0/dht/provide` endpoint and `DHTHandler.provide` with explicit `once` semantics, success/failure feedback, and optional queueing. Do **not** create a separate duplicate feature.

#### 4.9.2 Endpoint Changes

The existing endpoint `POST /api/v0/dht/provide` remains. Extend it with the following query parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `arg` | string | required | CID to provide. |
| `recursive` | bool | false | For directory DAGs, recursively provide all child blocks. |
| `queue` | bool | false | If true and the node is busy, queue the provide instead of failing immediately. |
| `timeout` | string | "30s" | Max time to wait for the operation. |
| `record` | bool | true | Whether to record the result in metrics/audit log. |

#### 4.9.3 Response Format

Replace the current `{ "Success": true }` response with:

```json
{
  "ID": "<local-peer-id>",
  "CID": "<cid>",
  "Success": true,
  "Attempts": 20,
  "Successes": 18,
  "Failures": 2,
  "Errors": ["timeout: peer12D3...", "peer not reachable: peer12D3..."],
  "Queued": false
}
```

- `Attempts` = number of peers contacted.
- `Successes` = number of peers that accepted the provider record.
- `Failures` = number of peers that did not.
- `Errors` = array of human-readable error strings (max 20 entries).
- `Queued` = true if the operation was queued and will run asynchronously.

If the operation was queued, the response should be `202 Accepted` with:

```json
{
  "CID": "<cid>",
  "Queued": true,
  "QueuePosition": 3
}
```

#### 4.9.4 Internal API Changes

Modify `DHTHandler.provide`:

```text
DHTHandler.provide(CID cid, {bool recursive = false, Duration? timeout}) → Future<ProvideResult>

ProvideResult
  cid: CID
  attempts: int
  successes: int
  failures: int
  errors: List<String>
  duration: Duration
```

- `recursive=true`: enumerate all blocks reachable from `cid` and call `provide` for each.
- `timeout`: if provided, abort remaining peer attempts after the timeout and return partial results.
- The method must not swallow exceptions; it must return a `ProvideResult` with `failures` and `errors` populated.

Add a provide queue in `DHTHandler` or `DHTClient`:

```text
DHTHandler
  final Queue<PendingProvide> _provideQueue;
  Future<ProvideResult> _processQueue() → Future<void>

PendingProvide
  cid: CID
  recursive: bool
  timeout: Duration
  completer: Completer<ProvideResult>
```

- The queue is only used when the RPC request includes `queue=true` or when the node is in a high-load state.
- Max queue size: 1000 pending provides; when full, return `503 Service Unavailable` with message `Provide queue full`.

#### 4.9.5 Metrics Integration

- Record `ipfs_dht_provides_total{status="success"}` for each successful peer announcement.
- Record `ipfs_dht_provides_total{status="failure"}` for each failed peer announcement.
- Record `ipfs_dht_reprovide_runs_total{strategy="on-demand", status="..."}` for the whole on-demand operation.

#### 4.9.6 Acceptance Criteria

- [ ] `/api/v0/dht/provide` returns the new detailed response format.
- [ ] `recursive=true` provides all blocks in a DAG.
- [ ] `queue=true` returns `202 Accepted` and processes the provide asynchronously.
- [ ] `timeout` aborts pending peer attempts and returns partial results.
- [ ] No separate duplicate feature is created; all logic lives in `DHTHandler.provide` and the existing endpoint.
- [ ] Existing callers of `DHTHandler.provide(CID)` continue to compile and work (add optional named parameters, do not change required signature).

---

## 5. Implementation Sequence

The following order minimizes rework, satisfies P0 dependencies first, and keeps the P1 items additive.

### Phase 1 — P0 Foundation (parallelizable)

1. **Trustless gateway** (§4.3) — foundational for all gateway interop; unblocks CAR/HTTP client tests.
2. **Real metrics collection** (§4.4) — instrumentation needed by every other item for acceptance criteria.
3. **MFS completeness** (§4.1) — RPC surface expansion; depends on existing MFS core.

### Phase 2 — P1 Network & Operator Features

4. **Subdomain gateway** (§4.2) — depends on trustless gateway response logic.
5. **On-demand provide refinement** (§4.9) — depends on DHT client; provides building blocks for reprovide.
6. **Reprovider service + strategies** (§4.7) — uses refined provide logic and pin/MFS managers.
7. **DHT Provide Sweep optimization** (§4.8) — inside Reprovider; requires routing table proximity.
8. **Content blocking / compact denylist** (§4.6) — wraps gateway and RPC; can be built independently.

### Phase 3 — P2 Deferred

9. **OpenTelemetry support** (§4.5) — revisit after v2.0 metrics are production-grade.

---

## 6. Testing Strategy

### 6.1 Unit Tests (target ≥80% coverage per file)

- `MFSManager`: test `flush`, `sync`, `stat`, `ls`, `write` with offset/truncate, and all error paths.
- `GatewayHandler`: test trustless format detection, raw block, CAR generation, IPNS record, DAG-JSON/CBOR responses, and subdomain parsing.
- `MetricsCollector`: test counter increments, histogram buckets, gauge updates, and Prometheus text output format.
- `DenylistService`: test loading, matching, audit log, and refresh behavior.
- `Reprovider`: test each strategy, deduplication, and status reporting.
- `DHTHandler.provide`: test success/failure counts, recursive enumeration, timeout, and queueing.

### 6.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to test request/response contracts without starting a real HTTP server:

- All `/api/v0/files/*` endpoints return Kubo-compatible JSON.
- Gateway `Accept` and `?format=` negotiation returns correct `Content-Type` and body.
- Subdomain gateway returns `400` for invalid CIDs and `451` for blocked content.
- `/metrics` returns valid Prometheus text when enabled and `404` when disabled.
- `/api/v0/dht/provide` returns new detailed response format and `202` when queued.

### 6.3 Interoperability Tests

Spin up Kubo (v0.42.0+) and dart_ipfs nodes in CI and verify:

- Kubo can retrieve a file from dart_ipfs via `/ipfs/<cid>` and trustless `?format=car`.
- dart_ipfs can retrieve a file from Kubo via the same paths.
- Kubo `ipfs dht findprovs` finds the dart_ipfs node after `/api/v0/dht/provide`.
- dart_ipfs `files/write` and `files/flush` produce CIDs that Kubo can `cat`.
- MFS `files/ls` and `files/stat` output matches Kubo field names and types.
- Blocked CIDs return `451` on the gateway and are not retrievable by Kubo via the dart_ipfs gateway.

### 6.4 Metrics and Load Tests

- Verify that enabling metrics does not regress request throughput by more than 5% in a load test.
- Verify that histogram buckets and counter labels are valid Prometheus format (parse with `prometheus_client` parser in tests).

---

## 7. Security Considerations

### 7.1 Denylist Misuse

- The denylist must be **default-off** and opt-in via `SecurityConfig.enableDenylist`.
- No package-level hardcoded denylist entries are allowed.
- The audit log must be bounded to prevent unbounded memory growth.
- Operators must be warned in logs when enabling the denylist, including the source path and count.
- Blocked responses must use HTTP `451` for legal/policy reasons, not `403`, to distinguish from authentication failures.

### 7.2 Gateway Path Validation

- All CID strings in paths and subdomains must be validated before lookup to prevent malformed input from reaching the blockstore or DHT.
- Subdomain hosts must be validated against the configured `gatewayDomain` or `*.ipfs.localhost`; reject unknown gateway hosts to prevent DNS rebinding and cache poisoning.
- Path traversal (`../`) must be normalized and blocked at the MFS root.
- Directory HTML listings must continue HTML-escaping file names (SEC-005).

### 7.3 Authentication and Authorization

- `RPCServer` API key authentication (SEC-003) remains unchanged; all write RPC endpoints require `X-API-Key` when configured.
- The gateway `writable` flag in `GatewayConfig` remains `false` by default; no POST/PUT/DELETE gateway write methods are added in this specification.
- The denylist operates independently of authentication: it can block content for authenticated users if the operator enables it.
- Rate limiting (SEC-007) in `GatewayServer` and `SecurityManager` must continue to apply and must be observable in the new metrics.

### 7.4 DHT Security

- Reprovider and on-demand provide must respect the existing `maxProvidersPerCid` and `maxProviderAnnouncementsPerMinute` limits (SEC-010).
- The optimized sweep must not bypass provider verification; it is only a batching optimization.
- Blocked CIDs must not be announced as providers to the DHT.

---

## 8. Backward Compatibility / Migration Notes

### 8.1 API Surface

- All changes are **additive** to the public Dart API. Existing methods keep their current signatures; new parameters are optional and named.
- `MFSManager.write`, `read`, `stat`, and `ls` signatures remain unchanged; new overloads or named parameters are added.
- `DHTHandler.provide(CID)` remains valid; new optional named parameters are added.
- `GatewayHandler.handlePath` and `handleSubdomain` signatures remain unchanged.

### 8.2 Configuration

- New `GatewayConfig`, `SecurityConfig`, `DHTConfig`, and `MetricsConfig` fields have safe defaults that preserve v1.11.5 behavior:
  - `enableSubdomainGateway: false`
  - `enableDenylist: false`
  - `enablePrometheusExport: false`
  - `reproviderEnabled: true` (but only runs when DHT is enabled)
  - `reproviderStrategy: "pinned"`
- Existing config files will load with default values for missing fields.

### 8.3 Behavior Changes

- Trustless gateway requests will no longer receive HTML; clients that previously relied on HTML for CAR or directory responses will now receive the correct binary or JSON format when `Accept` or `?format=` is set. This is a fix, not a breaking change, because it aligns with the IPFS spec.
- The `/api/v0/dht/provide` response format changes from `{Success: true}` to a detailed result object. Clients that parse the old field will see `Success: true` still present, plus additional fields, so JSON parsing remains compatible if they ignore unknown fields.

### 8.4 Migration Steps for Operators

1. Review new `MetricsConfig` fields and enable `/metrics` if desired.
2. Review new `SecurityConfig` denylist fields if content blocking is required; leave disabled if not.
3. If running a public gateway, set `GatewayConfig.enableSubdomainGateway=true` and `gatewayDomain` to the production domain.
4. Verify that existing RPC clients tolerate additional fields in `dht/provide` and `files/*` responses.

---

## 9. Open Questions / Future Council Items

The following are explicitly **out of scope** for v2.0 and require a separate Council deliberation if needed:

- Web UI gateway management of denylist.
- Fine-grained per-user allow/deny rules (ACLs).
- Content policy engine beyond CID/multihash blocking.
- WASM-specific metrics collection (OTel deferred).
- FUSE mount for MFS.

---

*End of specification.*
