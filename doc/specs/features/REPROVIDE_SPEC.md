# Reprovide Strategies, DHT Provide Sweep, and On-Demand Provide Specification

**Document ID:** `REPROVIDE_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P1 (should ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.7, §4.8, and §4.9

---

## 1. Goal and Scope

The goal of this specification is to bring dart_ipfs in line with Kubo and other production IPFS nodes for content announcement and provider record maintenance. The work covers three related areas:

1. **Reprovide strategies** — a periodic `Reprovider` service that announces local content to the DHT using pluggable strategies (`pinned`, `roots`, `all`, `pinned+mfs`, `unique`, `entities`).
2. **DHT Provide Sweep optimization** — XOR-ordered reprovide and proximity grouping inside the `Reprovider` service to reduce DHT message volume and routing-table churn.
3. **On-demand provide refinement** — enriching the existing `/api/v0/dht/provide` endpoint and `DHTHandler.provide` with explicit `once` semantics, success/failure feedback, optional queueing, and metrics integration. This is explicitly a modification of the existing feature, not a new duplicate.

Scope includes:

- The `Reprovider` service as an `ILifecycle` component.
- Configuration additions to `DHTConfig` for reprovider strategy, interval, batching, and concurrency.
- Extensions to `DHTHandler.provide` and `DHTClient.addProviders` for detailed feedback and batching.
- Updates to the existing `/api/v0/dht/provide` RPC handler for new parameters and response format.
- Metrics integration for all provide and reprovide operations.

Out of scope: delegated routing (e.g., cid.contact), Amino DHT record signing changes, and provider record revalidation protocols beyond reprovide.

---

## 2. Official References

- [Kubo `routing` / reprovide command reference](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-routing) — reprovide strategy names and defaults.
- [Kubo `dht provide` reference](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-dht-provide) — on-demand provider announcement semantics.
- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — endpoint paths, query parameters, and response formats.
- [IPFS DHT / Kademlia specification](https://specs.ipfs.tech/dht/) — routing key computation, XOR distance, and `ADD_PROVIDER` semantics.
- [IPFS Kademlia DHT specification](https://specs.ipfs.tech/dht/kademlia/) — closest peer lookup and routing table operations.
- [Prometheus Metric and Label Naming](https://prometheus.io/docs/practices/naming/) — metric conventions used for `ipfs_dht_*` counters and histograms.

---

## 3. Current State in dart_ipfs

The current DHT and provide implementation is in `lib/src/protocols/dht/dht_handler.dart`, `lib/src/protocols/dht/dht_client.dart`, and `lib/src/services/rpc/rpc_handlers.dart`.

- There is no periodic `Reprovider` service. `DHTHandler.provide` only announces a single CID once when called.
- `DHTClient.addProvider(String cid, String providerId)` sends a single `ADD_PROVIDER` message per closest peer without any batching or XOR ordering. There is no `addProviders(List<CID> cids, String providerId)` method.
- `/api/v0/dht/provide` in `RPCHandlers.handleDhtProvide` calls `node.dhtClient.addProvider(cid, node.peerId)` and returns only `{ "Success": true }` with no feedback about attempts, successes, or failures.
- `DHTConfig` in `lib/src/core/config/dht_config.dart` has no reprovider fields (`reproviderEnabled`, `reproviderInterval`, `reproviderStrategy`, `reproviderBatchSize`, `reproviderConcurrency`).
- `PinManager` in `lib/src/core/data_structures/pin_manager.dart` tracks recursive and direct pins and can enumerate them.
- `MFSManager` in `lib/src/core/mfs/mfs_manager.dart` exposes `rootCid` after initialization.
- `MetricsCollector` currently returns stub values, so DHT provide/reprovide metrics are not recorded today.

---

## 4. Target State / Requirements

### 4.1 Reprovider Strategies

Implement a `Reprovider` service that periodically announces local content to the DHT using the following strategies:

| Strategy | Description | CIDs Announced |
|----------|-------------|----------------|
| `pinned` | Reprovide all recursively pinned CIDs. | All recursive pins. |
| `roots` | Reprovide only the root CIDs of pinned DAGs. | Top-level recursive pins only. |
| `all` | Reprovide every CID in the local blockstore. | All local blocks. |
| `pinned+mfs` | Reprovide recursive pins plus the current MFS root. | Recursive pins + `MFSManager.rootCid`. |
| `unique` | Same as `pinned` but deduplicates CIDs before providing. | Deduplicated set of recursive pins. |
| `entities` | Reprovide root-level entities only (pins + MFS root + any explicit content roots). | Union of `roots` and MFS root. |

Default strategy: `pinned`.

### 4.2 Configuration Additions

Extend `DHTConfig` in `lib/src/core/config/dht_config.dart` with:

```text
DHTConfig
  bool reproviderEnabled          // default true when DHT server mode
  Duration reproviderInterval     // default 12 hours
  String reproviderStrategy       // default "pinned"
  int reproviderBatchSize         // default 100
  int reproviderConcurrency       // default 10
  bool reproviderSweepOptimization // default true
```

### 4.3 Reprovider Internal API

```text
Reprovider implements ILifecycle
  Reprovider(DHTConfig, DHTHandler, PinManager, MFSManager, MetricsCollector)
  Future<void> start()                 // schedules periodic runs
  Future<void> stop()                  // cancels timer and waits for in-flight runs
  Future<ReproviderResult> trigger({bool wait = false})  // manual run
  ReproviderStatus getStatus()
  void setStrategy(String strategy)    // validates against supported list

ReproviderResult
  String strategy
  int attempted
  int succeeded
  int failed
  Duration duration
  List<String> errors
  Map<PeerId, List<CID>>? groupedCids  // populated when sweep optimization enabled

ReproviderStatus
  DateTime? lastRun
  ReproviderResult? lastResult
  DateTime? nextRun
  String strategy
  bool running
```

### 4.4 Reprovide Run Semantics

1. Collect CIDs according to the selected strategy.
2. Deduplicate CIDs (all strategies must deduplicate).
3. If `reproviderSweepOptimization` is true, group CIDs by proximity to the same closest peers (see §4.5).
4. For each CID or group, call `DHTHandler.provide(CID)` or the optimized batch equivalent.
5. Record metrics:
   - `ipfs_dht_reprovide_runs_total{strategy, status}`
   - `ipfs_dht_reprovide_duration_seconds{strategy}`
   - `ipfs_dht_provides_total{status}` for each individual peer announcement.
6. Return `ReproviderResult`.

Periodic runs must respect the configured interval. Manual `trigger()` may run immediately and optionally wait for completion. Only one reprovide run should execute at a time; overlapping calls queue or return a busy status.

### 4.5 DHT Provide Sweep Optimization

Optimize the reprovide process inside `Reprovider` by ordering CIDs by XOR distance to peer IDs and grouping nearby CIDs so that each DHT `ADD_PROVIDER` request can cover multiple CIDs when target peers are the same.

#### 4.5.1 XOR-Ordered Reprovide

- For each CID to be reprovided, compute the DHT routing key: `SHA256(multihash)`.
- Sort the CID list by XOR distance from the local peer ID to enable routing-table locality.
- This ordering does not change which CIDs are announced; it only improves batching and reduces routing-table churn.

#### 4.5.2 Proximity Grouping

- For each CID, identify the `K` closest peers from the local routing table (`K = DHTConfig.bucketSize`, default 20).
- Group CIDs that share the same closest peer set (or a high overlap threshold, e.g., greater than or equal to 80% of peers in common).
- For each group, send a single `ADD_PROVIDER` message per peer with the group of CIDs, instead of one message per CID per peer.
- If the wire protocol does not support multiple keys per `ADD_PROVIDER` message, batch at the transport layer by sending sequential `ADD_PROVIDER` messages over the same open stream/connection.

#### 4.5.3 DHTClient Additions

Extend `DHTClient` in `lib/src/protocols/dht/dht_client.dart` with:

```text
DHTClient
  Future<void> addProviders(List<CID> cids, String providerId)
```

Implementation must:

- Compute the closest peers for each CID once.
- Group by target peer.
- Send `ADD_PROVIDER` messages for the batch.
- Return when all messages are acknowledged or timed out.

### 4.6 On-Demand Provide Refinement

The existing endpoint `POST /api/v0/dht/provide` remains. Extend it with the following query parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `arg` | String | required | CID to provide. |
| `recursive` | bool | false | For directory DAGs, recursively provide all child blocks. |
| `queue` | bool | false | If true and the node is busy, queue the provide instead of failing immediately. |
| `timeout` | String | "30s" | Max time to wait for the operation. |
| `record` | bool | true | Whether to record the result in metrics/audit log. |

#### 4.6.1 Response Format

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

#### 4.6.2 Internal API Changes

Modify `DHTHandler.provide`:

```text
DHTHandler.provide(CID cid, {bool recursive = false, Duration? timeout}) → Future<ProvideResult>

ProvideResult
  CID cid
  int attempts
  int successes
  int failures
  List<String> errors
  Duration duration
```

- `recursive=true`: enumerate all blocks reachable from `cid` and call `provide` for each. The top-level result aggregates counts across all recursive calls.
- `timeout`: if provided, abort remaining peer attempts after the timeout and return partial results.
- The method must not swallow exceptions; it must return a `ProvideResult` with `failures` and `errors` populated.

Add a provide queue in `DHTHandler` or `DHTClient`:

```text
DHTHandler
  final Queue<PendingProvide> _provideQueue
  Future<void> _processQueue()

PendingProvide
  CID cid
  bool recursive
  Duration timeout
  Completer<ProvideResult> completer
```

- The queue is used when the RPC request includes `queue=true` or when the node is in a high-load state (operator-defined threshold).
- Max queue size: 1000 pending provides; when full, return `503 Service Unavailable` with body `Provide queue full`.

#### 4.6.3 Metrics Integration

- Record `ipfs_dht_provides_total{status="success"}` for each successful peer announcement.
- Record `ipfs_dht_provides_total{status="failure"}` for each failed peer announcement.
- Record `ipfs_dht_reprovide_runs_total{strategy="on-demand", status="..."}` for the whole on-demand operation.

---

## 5. Detailed Acceptance Criteria

### Reprovider strategies

- [ ] All six strategies are selectable via configuration.
- [ ] Default strategy `pinned` reprovides all recursive pins.
- [ ] `pinned+mfs` includes the MFS root.
- [ ] `all` reprovides every block in the local blockstore without duplication.
- [ ] Periodic runs respect the configured interval.
- [ ] Manual `trigger()` returns accurate `attempted`, `succeeded`, and `failed` counts.
- [ ] The service is registered in `LifecycleManager` and starts/stops cleanly.

### DHT Provide Sweep optimization

- [ ] Reprovide runs group CIDs by closest-peer overlap.
- [ ] The number of DHT messages sent for a reprovide run is measurably lower than the naive one-message-per-CID approach in unit tests (use a mock router to assert message count).
- [ ] XOR ordering does not change which CIDs are announced or which peers receive them.
- [ ] Optimization is enabled by default when `reproviderEnabled` is true; can be disabled via `reproviderSweepOptimization=false`.

### On-demand provide refinement

- [ ] `/api/v0/dht/provide` returns the new detailed response format.
- [ ] `recursive=true` provides all blocks in a DAG.
- [ ] `queue=true` returns `202 Accepted` and processes the provide asynchronously.
- [ ] `timeout` aborts pending peer attempts and returns partial results.
- [ ] No separate duplicate feature is created; all logic lives in `DHTHandler.provide` and the existing endpoint.
- [ ] Existing callers of `DHTHandler.provide(CID)` continue to compile and work (add optional named parameters, do not change required signature).

---

## 6. Security Considerations

- Rate limiting: provider announcements must continue to respect the existing rate limits in `DHTHandler` (e.g., `maxProviderAnnouncementsPerMinute`).
- Sybil resistance: `DHTHandler.handleProvideRequest` must verify provider records before storing them; the reprovide service does not bypass this verification.
- Queue exhaustion: the 1000-item provide queue limit prevents memory exhaustion from a flood of RPC requests. Operators should be able to configure this limit in the future, but it is fixed for this release.
- Recursive provide limits: `recursive=true` must enumerate the DAG but should not traverse beyond local blocks. If a block is missing locally, the recursive walk should stop and record a failure rather than trying to fetch arbitrary content from the network.
- Denylist: when the content blocking service is enabled, `DHTHandler.handleProvideRequest` must reject provider announcements for blocked CIDs. The reprovider must also skip blocked CIDs before announcing them.
- Metrics safety: never include peer IDs, CIDs, or file names in metric labels. Use only `strategy`, `status`, `protocol`, `method`, `endpoint`, and `namespace` labels.

---

## 7. Testing Strategy

### 7.1 Unit Tests

Target greater than or equal to 80% coverage per file:

- `Reprovider`: each strategy collection, deduplication, `trigger()` with `wait=true/false`, periodic scheduling, and status reporting.
- `Reprovider._sweepOptimizedProvide`: XOR distance sorting, grouping, and `ReproviderResult.groupedCids`.
- `DHTClient.addProviders`: batching, mock routing table, message count reduction, and timeout behavior.
- `DHTHandler.provide`: success/failure counts, recursive enumeration, timeout, and exception handling.
- Provide queue: enqueue, dequeue, `202 Accepted`, queue-full `503`, and result delivery via `Completer`.
- `MetricsCollector`: `recordDhtProvide`, `recordReprovide`, and on-demand strategy labels.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to verify:

- `POST /api/v0/dht/provide?arg=<cid>` returns the new detailed JSON with `ID`, `CID`, `Attempts`, `Successes`, `Failures`, `Errors`, and `Queued`.
- `POST /api/v0/dht/provide?arg=<cid>&queue=true` returns `202 Accepted` with `QueuePosition`.
- `POST /api/v0/dht/provide?arg=<cid>&recursive=true` returns aggregated counts for the DAG.
- `POST /api/v0/dht/provide?arg=<cid>&timeout=5s` returns partial results within the timeout.
- Queue-full returns `503 Service Unavailable` with body `Provide queue full`.

### 7.3 Interoperability Tests

Spin up a Kubo v0.42.0+ node and a dart_ipfs node in CI and verify:

- Kubo `ipfs dht findprovs <cid>` finds the dart_ipfs node after `/api/v0/dht/provide`.
- dart_ipfs `Reprovider` with `pinned` strategy makes pinned CIDs discoverable by Kubo.
- The DHT Provide Sweep optimization sends fewer messages than the naive approach while reaching the same peers (assert via mock router or packet capture).
- Timeout and recursive provide behavior match Kubo semantics for comparable commands.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| `DHTHandler` / `DHTClient` | Core provider announcement logic must be extended for feedback and batching. |
| `PinManager` | Provides the set of recursive and direct pins for strategies. |
| `MFSManager` | Provides the MFS root for `pinned+mfs` and `entities` strategies. |
| `MetricsCollector` | Required for `ipfs_dht_provides_total`, `ipfs_dht_reprovide_runs_total`, and `ipfs_dht_reprovide_duration_seconds`. |
| `DHTConfig` | Must be extended with reprovider fields. |
| `RoutingTable` / Kademlia tree | Required for XOR distance computation and closest-peer grouping. |
| Content blocking / Denylist (P1) | Reprovider must skip blocked CIDs; DHT handler must reject blocked provider announcements. |

**Implementation order:**

1. Refine `DHTHandler.provide` and `ProvideResult` for success/failure feedback.
2. Add the on-demand provide queue and update `/api/v0/dht/provide` handler.
3. Extend `DHTConfig` with reprovider fields.
4. Create `Reprovider` service with all strategies and `ILifecycle` integration.
5. Implement DHT Provide Sweep optimization: `_sweepOptimizedProvide`, `_groupByClosestPeers`, and `_xorDistance`.
6. Extend `DHTClient` with `addProviders(List<CID>, String)` batch method.
7. Add denylist checks for provided and reprovided CIDs.
8. Add unit, contract, and interop tests.

Reprovider and DHT Provide Sweep are Phase 2 P1 items that depend on the refined on-demand provide logic and the DHT client. On-demand provide refinement is also Phase 2 P1 and is the building block for the other two.

---

## 9. Backward Compatibility Notes

- `DHTHandler.provide(CID cid)` must remain a valid call. The new parameters (`recursive`, `timeout`) must be optional with defaults `false` and `null`.
- `DHTClient.addProvider(String cid, String providerId)` must remain unchanged and continue to work. The new `addProviders(List<CID>, String)` is an additive overload.
- `DHTConfig` new fields are optional with defaults that preserve existing behavior (no periodic reprovider unless DHT server mode is active).
- The existing `/api/v0/dht/provide` endpoint path and `arg` parameter are unchanged. The response format is extended; clients that only checked `Success` will still find it.
- No new mandatory configuration is introduced. If `reproviderEnabled` is not set, it defaults to `true` only when the node is in DHT server mode; in client mode it remains `false`.
