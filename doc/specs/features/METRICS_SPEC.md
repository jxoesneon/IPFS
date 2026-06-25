# Real Metrics Collection Specification

**Document ID:** `METRICS_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P0 (must ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.4

---

## 1. Goal and Scope

The goal of this specification is to replace the stub `MetricsCollector` and broken `NetworkMetrics` implementation with a real, Prometheus-compatible metrics pipeline that operators can scrape and use to monitor node health. This is a foundational P0 feature because almost every other v2.0 feature depends on metrics for its acceptance criteria and production observability.

Scope includes:

- Real counters, gauges, and histograms for P2P messages, bytes, latency, peers, routing table, blockstore, gateway requests, RPC requests, DHT provides/reprovides, and security events.
- A `/metrics` endpoint on the gateway port (and optionally the RPC port) when `MetricsConfig.enablePrometheusExport` is true.
- Periodic background collection of blockstore and routing-table statistics.
- Fixing the null-entry increment bug in `NetworkMetrics`.
- O(1) metric increments and zero overhead when metrics are disabled.

Out of scope: OpenTelemetry (deferred to a future release), custom dashboards, and push-based exporters.

---

## 2. Official References

- [Prometheus Exposition Formats](https://prometheus.io/docs/instrumenting/exposition_formats/) — text format, metric naming, label escaping, and histogram conventions.
- [Prometheus Metric and Label Naming](https://prometheus.io/docs/practices/naming/) — `ipfs_<subsystem>_<unit>` style, base units, `_total`, `_bytes`, `_seconds`, `_count`, `_sum`.
- [OpenTelemetry](https://opentelemetry.io/docs/) — deferred for v2.0; reserved for future mapping once metrics are solid.
- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — RPC request patterns that must be instrumented.
- [IPFS HTTP Gateway Specs](https://specs.ipfs.tech/http-gateways/) — gateway request patterns that must be instrumented.

---

## 3. Current State in dart_ipfs

The current metrics implementation spans three files:

- `lib/src/core/metrics/metrics_collector.dart` — `MetricsCollector` implements `ILifecycle` but all getter methods (`getMessagesSent`, `getMessagesReceived`, `getBytesSent`, `getBytesReceived`, `getAverageLatency`) return hardcoded `0`. It only emits a broadcast stream of ad-hoc maps and logs events.
- `lib/src/core/metrics/network_metrics.dart` — `NetworkMetrics` has `Map<LibP2PPeerId, PeerMetrics>` and `Map<String, ProtocolMetrics>` but `recordMessageSent` does `peerMetrics[peer]?.messagesSent++` on a null entry, which has no effect. The same bug applies to bytes and protocol counters.
- `lib/src/core/config/metrics_config.dart` — `MetricsConfig` already defines `enablePrometheusExport`, `prometheusEndpoint`, and `collectionIntervalSeconds`, but these values are not consumed by `GatewayServer` or `RPCServer`.

In addition, the `prometheus_client` package is already listed in `pubspec.yaml` (`prometheus_client: ^1.0.0+1`) but is not used by the current implementation.

---

## 4. Target State / Requirements

### 4.1 Metric Catalog

The following metrics must be maintained. All metric names follow Prometheus conventions. Counters are monotonically increasing; gauges reflect current state; histograms use seconds.

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

Histograms must use the default Prometheus bucket set: `[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]`.

### 4.2 Internal API

Extend `MetricsCollector` in `lib/src/core/metrics/metrics_collector.dart` with the following methods:

```text
MetricsCollector
  recordMessageSent(String protocol, int bytes) → void
  recordMessageReceived(String protocol, int bytes) → void
  recordLatency(String protocol, Duration latency) → void
  recordPeerConnected() → void
  recordPeerDisconnected() → void
  recordRoutingTableSize(int size) → void
  recordBlockstoreStats(int blocks, int bytes) → void
  recordGatewayRequest(String namespace, String method, int status, Duration duration) → void
  recordRpcRequest(String endpoint, String method, int status, Duration duration) → void
  recordDhtProvide(bool success) → void
  recordReprovide(String strategy, bool success, Duration duration) → void
  recordSecurityEvent(String type) → void
  Future<String> getPrometheusMetrics() → Future<String>
  reset() → void   // test-only
```

All methods must be O(1) and thread-safe. When `MetricsConfig.enabled == false`, every method should perform at most a single boolean check and return immediately.

### 4.3 Endpoint Wiring

- In `GatewayServer`, when `MetricsConfig.enablePrometheusExport` is true, register:
  - `GET /metrics` → `MetricsCollector.getPrometheusMetrics()` with `Content-Type: text/plain; version=0.0.4; charset=utf-8`.
- In `RPCServer`, optionally expose the same endpoint on the same port if the RPC server is configured to do so (configurable via `MetricsConfig`, default only on the gateway port to avoid duplication).
- `MetricsCollector` must be registered as an `ILifecycle` service in `LifecycleManager`.

### 4.4 Collection Intervals

- When `MetricsConfig.enabled` is true, `MetricsCollector.start()` starts a periodic timer with `collectionIntervalSeconds`.
- The timer collects blockstore statistics and routing table size, then updates the corresponding gauges.
- The timer is cancelled in `MetricsCollector.stop()`.

### 4.5 NetworkMetrics Fix

- `NetworkMetrics.recordMessageSent` and `recordMessageReceived` must initialize `PeerMetrics` and `ProtocolMetrics` on first record using `putIfAbsent`.
- The same fix applies to byte accounting.

---

## 5. Detailed Acceptance Criteria

- [ ] `MetricsCollector` no longer returns hardcoded zeros; all legacy getters return real accumulated values.
- [ ] `NetworkMetrics` initializes `PeerMetrics` and `ProtocolMetrics` on first record.
- [ ] `GET /metrics` returns valid Prometheus text format when `enablePrometheusExport` is true and returns `404` when disabled.
- [ ] `ipfs_gateway_requests_total` and `ipfs_rpc_requests_total` increment on every request with correct labels.
- [ ] Histograms use the default buckets `[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]`.
- [ ] Metrics collection does not block request handling; all increments are O(1).
- [ ] Disabled metrics (`MetricsConfig.enabled=false`) imposes zero overhead beyond a single boolean check.
- [ ] `recordSecurityEvent` covers `rate_limit`, `blocked_cid`, and `auth_failure` types.
- [ ] `recordDhtProvide` increments both `success` and `failure` labels.
- [ ] `recordReprovide` records both `status` and `strategy` labels.

---

## 6. Security Considerations

- The `/metrics` endpoint must not expose peer IDs, CIDs, file paths, or any other privacy-sensitive labels. Labels must be limited to protocol names, endpoint names, namespaces, status codes, and strategies.
- The endpoint should be bound to the configured gateway/RPC address. If the gateway is public, operators should be aware that `/metrics` exposes node health data; future work may add IP allow-listing or authentication, but that is out of scope for this specification.
- Metric names and labels must be sanitized to avoid Prometheus injection (e.g., no newlines or backslashes in label values). Use the `prometheus_client` package's escaping rules.
- The `reset()` method is test-only and must not be exposed via RPC or the gateway.

---

## 7. Testing Strategy

### 7.1 Unit Tests

Target greater than or equal to 80% coverage per file:

- `MetricsCollector`: counter increments, histogram bucket placement, gauge updates, Prometheus text output format, `reset()`, and disabled-state overhead.
- `NetworkMetrics`: first-record initialization, message/byte counters, and average latency updates.
- `MetricsConfig`: JSON serialization round-trip with new fields.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or mock servers to verify:

- `GET /metrics` returns `200 OK` with `Content-Type: text/plain; version=0.0.4; charset=utf-8` when enabled.
- `GET /metrics` returns `404` when `enablePrometheusExport` is false.
- The Prometheus body contains all required metric names and no duplicate `HELP`/`TYPE` lines for the same metric.
- Label values are correctly escaped.

### 7.3 Interoperability Tests

Spin up a dart_ipfs node and scrape its `/metrics` endpoint with the Prometheus Go client or a simple parser. Verify:

- The parser does not reject the output.
- Counters increment after sending P2P messages and RPC requests.
- Gauges reflect the actual blockstore size and routing table state.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| `prometheus_client` package (already in `pubspec.yaml`) | Provides counters, gauges, histograms, and text exposition. |
| `GatewayServer` / `RPCServer` | Hosts the `/metrics` endpoint. |
| `LifecycleManager` | Must register `MetricsCollector` as an `ILifecycle` service. |
| `IBlockStore` / `RoutingTable` | Sources for blockstore and routing table gauges. |
| Network layer | Must call `recordMessageSent`/`recordMessageReceived` for each P2P message. |

**Implementation order:**

1. Fix `NetworkMetrics` null-entry initialization.
2. Implement real metrics in `MetricsCollector` using `prometheus_client`.
3. Wire `/metrics` endpoint in `GatewayServer` and optionally `RPCServer`.
4. Register `MetricsCollector` in `LifecycleManager` and start periodic collection.
5. Instrument gateway, RPC, DHT, and security paths.
6. Add unit and contract tests.

Real metrics collection is a Phase 1 P0 foundation item and must be completed before or in parallel with the other P0 and P1 items that rely on it.

---

## 9. Backward Compatibility Notes

- The existing `metricsStream` broadcast stream on `MetricsCollector` may be retained for backward compatibility, but the primary output becomes the Prometheus exposition endpoint.
- Legacy getter methods (`getMessagesSent`, `getMessagesReceived`, `getBytesSent`, `getBytesReceived`, `getAverageLatency`) must be reimplemented to return real values, not zeros. Their signatures must not change.
- `MetricsConfig` fields already exist and must be consumed as specified. No new required configuration fields are introduced.
- When `MetricsConfig.enabled` is false, the existing public API must continue to behave as no-ops, but the implementation must guarantee near-zero overhead rather than allocating maps or timers.
