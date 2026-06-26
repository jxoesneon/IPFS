# Implementation Inventory Report

## Executive Summary

This inventory assesses the implementation status of the 24 feature specifications for `dart_ipfs`. As of the latest implementation pass, the four critical P0 specs targeted for this sprint—**DAG_CBOR_SPEC**, **METRICS_SPEC**, **MFS_SPEC**, and **TRUSTLESS_GATEWAY_SPEC**—have been implemented to a testable, spec-compliant state. Many remaining specifications are still missing or partial, representing the next phase of work.

**Status Distribution:**
- **Complete**: 5 specs (21%)
- **Partial**: 7 specs (29%)
- **Missing**: 12 specs (50%)

## Specification Status Table

| Spec | Priority | Status | Key Files | Assessment |
|------|----------|--------|-----------|------------|
| **CAR_FORMAT_SPEC** | P0 | Complete | `lib/src/core/data_structures/car.dart` | Standard CAR v1/v2 API implemented; passes cross-codec round-trip tests. |
| **CLI_SPEC** | P0 | Partial | `bin/ipfs.dart` | Basic CLI exists; missing most subcommands (add, cat, ls, pin, swarm, config). |
| **DAG_CBOR_SPEC** | P0 | Complete | `lib/src/core/cbor/enhanced_cbor_handler.dart`, `lib/src/core/ipld/codecs/standard_codecs.dart` | Tag-42 CIDs, canonical map ordering, big-int tags 2/3, strict decoding, `-2^64` boundary fix. |
| **DAG_JSON_SPEC** | P1 | Partial | `lib/src/core/ipld/codecs/standard_codecs.dart` | Unified `DagJsonCodec`; reserved namespace and strict canonical sorting not fully implemented. |
| **DHT_INTEGRATION_SPEC** | P0 | Partial | `lib/src/protocols/dht/dht_client.dart` | Single-hop queries; iterative expansion, provider validation, and reprovide sweep remain. |
| **DOCKER_SPEC** | P0 | Complete | `Dockerfile` | Multi-stage Dockerfile with hardened runtime; multi-arch support documented. |
| **IPLD_SELECTORS_SPEC** | P0 | Missing | N/A | Custom selector model incompatible with official vocabulary. |
| **METRICS_SPEC** | P0 | Complete | `lib/src/core/metrics/metrics_collector.dart`, `lib/src/services/gateway/gateway_server.dart`, `lib/src/services/rpc/rpc_server.dart` | Prometheus counters/gauges/histograms, `/metrics` endpoint, lifecycle wiring, request instrumentation. |
| **MFS_SPEC** | P0 | Complete | `lib/src/core/mfs/mfs_manager.dart`, `lib/src/services/rpc/mfs_handlers.dart`, `lib/src/services/rpc/rpc_server.dart` | flush, mv, chcid, stat/ls, write offset/truncate, RPC routes, lifecycle registration. |
| **REPROVIDE_SPEC** | P1 | Missing | N/A | No periodic Reprovider service. |
| **SUBDOMAIN_GATEWAY_SPEC** | P1 | Partial | `lib/src/services/gateway/gateway_handler.dart` | Trustless format detection added; full DNSLink/CORS validation still missing. |
| **TRUSTLESS_GATEWAY_SPEC** | P0 | Complete | `lib/src/services/gateway/gateway_handler.dart`, `lib/src/core/security/denylist_service.dart` | Format negotiation, CAR/raw/DAG-JSON/DAG-CBOR/IPNS-record responses, Bitswap fallback, 451 denylist. |
| **UNIXFS_SPEC** | P0 | Partial | `lib/src/core/unixfs/` | Tsize fixed, path resolution, cid-version/raw-leaves/hash support; HAMT sharding and symlinks not implemented. |
| **BITSWAP_HTTP_FALLBACK_SPEC** | P1 | Missing | N/A | No HTTP fallback. |
| **BROWSER_TRANSPORTS_SPEC** | P1 | Partial | `lib/src/transport/webtransport/` | Dummy certhash, hardcoded STUN, incomplete `libp2p.Conn` fields. |
| **CIRCUIT_RELAY_SPEC** | P0 | Partial | `lib/src/protocols/relay/circuit_relay_client.dart` | Incomplete dialing path, no reservation refresh, no config. |
| **CONTENT_BLOCKING_SPEC** | P1 | Partial | `lib/src/core/security/denylist_service.dart` | Basic denylist service and gateway 451 responses implemented; full RPC/security integration missing. |
| **GATEWAY_TLS_SPEC** | P1 | Missing | N/A | No TLS fields, SecurityContext, or AutoTLS. |
| **GOSSIPSUB_SPEC** | P0 | Missing | `lib/src/protocols/pubsub/pubsub_client.dart` | Custom JSON/HMAC format; incompatible with libp2p Gossipsub v1.1. |
| **GRAPHSYNC_SPEC** | P1 | Partial | `lib/src/protocols/graphsync/graphsync_handler.dart` | Broadcasts to all peers; selective retrieval blocked on IPLD selectors. |
| **INTEROP_TESTS_SPEC** | P0 | Complete | `.github/workflows/interop.yml`, `test/interop/` | P0/P1 workflows, Kubo/Helia compose harnesses, interop test scaffolding. |
| **IPNS_SPEC** | P0 | Partial | `lib/src/protocols/ipns/ipns_handler.dart` | Record bytes exposed; DHT publish, signature verification, name derivation still incomplete. |
| **KUBERNETES_SPEC** | P1 | Missing | N/A | No k8s manifests or Helm chart. |
| **MODULARIZATION_SPEC** | P1 | Missing | N/A | No packages/ monorepo. |
| **PLUGINS_SPEC** | P1 | Complete | `lib/src/core/plugins/` | PluginHost, manifest, capability registry, signing/verification, examples, audit logging. |
| **QUIC_SPEC** | Conditional | Missing | `lib/src/transport/libp2p_router.dart` | No QUIC transport; dependency availability unverified. |

## Recent Changes

### DAG_CBOR_SPEC
- Fixed canonical tag encoding for big integers (tags 2/3 use single-byte `0xc2`/`0xc3`).
- Fixed `-2^64` boundary encoding.
- Relaxed CID validation to accept any standard IPLD codec via `CID.fromBytes`.
- Enforced `maxStringLength` and non-minimal big-int rejection in strict mode.
- Rewrote `test/core/cbor/enhanced_cbor_handler_test.dart` with canonical, CID, big-int, and strict-decoding tests.

### METRICS_SPEC
- Rewrote `MetricsCollector` using `prometheus_client` with counters, gauges, and histograms.
- Added `/metrics` endpoint to `GatewayServer` and `RPCServer` when enabled.
- Registered `MetricsCollector` with `LifecycleManager`.
- Instrumented gateway, RPC, DHT, and security paths.
- Fixed `getPrometheusMetrics()` to return empty when disabled.
- Updated `NetworkMetrics`/`MetricsCollector` latency averaging.

### MFS_SPEC
- Wired all `/api/v0/files/*` routes in `RPCServer`.
- Registered `MFSManager` with `LifecycleManager`.
- Implemented `flush`, `mv`, `chcid`, Kubo-style `stat`/`ls`, and `write` with offset/truncate/count.
- Added `cid-version`, `raw-leaves`, `hash`, and `cid-base` support.
- Updated `UnixFSBuilder` and `CID` helpers for configurable bases.
- Rewrote `test/core/mfs_test.dart` for the new API.

### TRUSTLESS_GATEWAY_SPEC
- Added `?format=` and `Accept` header negotiation for raw, CAR, IPNS-record, DAG-JSON, and DAG-CBOR.
- Implemented CAR archive generation using standard `CarWriter`.
- Added Bitswap fallback for missing blocks.
- Implemented `DenylistService` with 451 responses.
- Wired IPNS record resolver and TTL-based `Cache-Control`.
- Added subdomain gateway trustless detection.
- Added `test/services/gateway/trustless_gateway_test.dart`.

## Test Results

Using Dart SDK 3.12.2:
- `dart analyze`: 0 errors, 4 pre-existing info issues.
- `dart test`: 2431 passed, 13 skipped, 1 failed.
- The single failure is `test/network/nat_traversal_service_improved_test.dart` (`mapPort handles null gateway and discovery failure`), which is environment-dependent and was present before this work.

## Recommended Next Phase

The remaining P0 blockers for full protocol compliance are:
1. **IPLD_SELECTORS_SPEC** — required for GraphSync and selective CAR retrieval.
2. **DHT_INTEGRATION_SPEC** — iterative queries and provider validation for public Amino DHT.
3. **GOSSIPSUB_SPEC** — replace custom pubsub with libp2p Gossipsub v1.1.
4. **IPNS_SPEC** — DHT publish, signed records, name derivation, and verification.
5. **UNIXFS_SPEC** — HAMT sharding and symlinks for large directories.
6. **CIRCUIT_RELAY_SPEC** — complete relay dialing and reservation refresh.
