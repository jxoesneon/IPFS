# Maintainer Decision — IPFSConfig Serialization and Lifecycle Wiring

**Date:** 2026-06-25
**Convened by:** project, Lord of Wisdom
**Subject:** IPFSConfig serialization completeness, canonical config file format, and lifecycle wiring for `RPCServer` / `GatewayServer` in the CLI and daemon.
**Evidence paths:**
- `lib/src/core/config/ipfs_config.dart` (lines 128-322)
- `lib/src/core/builders/ipfs_node_builder.dart` (lines 135-136)
- `lib/src/core/ipfs_node/lifecycle_manager.dart`
- `lib/src/services/rpc/rpc_server.dart`
- `lib/src/services/gateway/gateway_server.dart`
- `doc/specs/features/CLI_SPEC.md`
- `doc/specs/features/KUBERNETES_SPEC.md`
- `doc/specs/audits/MAINTAINER_AUDIT_OPERATIONS_ECOSYSTEM.md`

---

## 1. Questions Before the maintainers

1. Should the canonical config file format be YAML or JSON?
2. Which fields must be added to `IPFSConfig.toJson()` / `fromJson()` to support the CLI daemon, plugins, and metrics?
3. Should `IPFSNodeBuilder` register `RPCServer` and `GatewayServer` in the lifecycle, or should the CLI `daemon` command manage them explicitly?
4. Should the config file path default to `$IPFS_PATH/config.json` (or `.yaml`) and be overrideable by `--config`?

---

## 2. Current State Findings

### 2.1 Incomplete serialization
`IPFSConfig.toJson()` at `lib/src/core/config/ipfs_config.dart:300-322` serializes only:

- `offline`, `network`, `dht`, `storage`, `security`
- `debug`, `verboseLogging`, `enablePubSub`, `enableDHT`, `enableCircuitRelay`
- `enableContentRouting`, `enableDNSLinkResolution`, `enableIPLD`, `enableGraphsync`
- `enableMetrics`, `enableLogging`, `logLevel`, `enableQuotaManagement`
- `defaultBandwidthQuota`, `enableLibp2pBridge`, `libp2pListenAddress`

It omits:

- `gateway` (`GatewayConfig`)
- `metrics` (`MetricsConfig`)
- `keystore` (object) / `keystorePath`
- `customConfig` (plugin / arbitrary extension map)
- `ipnsCacheSize`, `enableStructuredLogging`, `garbageCollectionInterval`, `garbageCollectionEnabled`
- `datastorePath`, `blockStorePath`, `dataPath`
- `libp2pIdentitySeed`, `nodeId`
- `maxConcurrentBitswapRequests`

The constructor already accepts these fields, so `fromJson()` is lossy when `toJson()` is used for `config show` / `config replace`.

### 2.2 Format mismatch
`IPFSConfig.fromFile()` uses `loadYaml()` and round-trips YAML through JSON. The CLI and Kubernetes specs reference `config.json` as the default repository config. This creates ambiguity for Docker, K8s, and first-run CLI initialization.

### 2.3 Lifecycle wiring gap
`IPFSNodeBuilder.build()` at `lib/src/core/builders/ipfs_node_builder.dart:135-136` registers `LifecycleManager` but does not register `RPCServer` or `GatewayServer`. Both server classes already expose `start()` and `stop()` methods, but they do not implement `ILifecycle`. The CLI `daemon` command and Kubernetes readiness probes assume these services are running after `IPFSNode.start()` completes.

---

## 3. Maintainer Review

### 3.1 Question 1: Canonical config file format — YAML or JSON?

| maintainers Lens | Score | Rationale |
|--------------|-------|-----------|
| **Coherence** | 8 | Dart's `jsonEncode`/`jsonDecode` is the native transport serialization for the in-memory model. `IPFSConfig.fromJson` / `toJson` already define the runtime contract. YAML is currently only a pre-parse step. |
| **Capability** | 9 | JSON is the format assumed by `CLI_SPEC.md`, `KUBERNETES_SPEC.md`, and Docker/Kubernetes ConfigMaps. YAML would force downstream specs to convert or maintain two templates. |
| **Safety** | 7 | JSON is less prone to accidental type coercion than YAML. However, YAML must remain supported for backward compatibility. Accepting both increases parsing surface slightly; strict validation mitigates this. |
| **Efficiency** | 9 | No rewrite needed: `fromFile()` can sniff the extension, parse YAML when needed, and always produce a `Map<String, dynamic>` for `fromJson()`. JSON becomes the new default writer. |
| **Evolution** | 8 | A single canonical JSON format with YAML read-fallback is easier to document and version than two parallel schemas. Plugin settings can be stored under `customConfig` as JSON. |

**Decision:** JSON is the canonical on-disk format. YAML remains accepted as a read-only legacy/alternative format. The default file is `$IPFS_PATH/config.json`. If a file extension is `.yaml`/`.yml`, parse with `loadYaml` and round-trip to JSON as today. New CLI writes must emit JSON.

### 3.2 Question 2: Fields to add to `toJson()` / `fromJson()`

| maintainers Lens | Score | Rationale |
|--------------|-------|-----------|
| **Coherence** | 9 | Every constructor field should round-trip unless it is intentionally non-serializable. The model is already structured; the fix is additive. |
| **Capability** | 9 | CLI `config show`, `config replace`, Docker/K8s templating, and plugin settings all require `gateway`, `metrics`, `customConfig`, and path fields. |
| **Safety** | 6 | `keystore` must not be serialized as a nested key blob. Only `keystorePath` should be written; cryptographic keys remain on disk or in the encrypted keystore. `libp2pIdentitySeed` is a Uint8List and should be base64-encoded with a clear comment that it is sensitive. `customConfig` may contain plugin settings or secrets, so the CLI must reject saving API keys/tokens into it. |
| **Efficiency** | 9 | The work is limited to adding keys to the existing map literals and `fromJson` constructor calls. No new config classes are required. |
| **Evolution** | 8 | `customConfig` provides a forward-compatible extension bucket for plugin settings and future Kubo parity fields without schema changes. |

**Decision:** Extend `toJson()` and `fromJson()` to include, at minimum:

- `gateway` (`gateway.toJson()` / `GatewayConfig.fromJson`)
- `metrics` (`metrics.toJson()` / `MetricsConfig.fromJson`)
- `customConfig` (raw map, default `{}`)
- `ipnsCacheSize`
- `enableStructuredLogging`
- `garbageCollectionInterval` (serialized as integer seconds; deserialized with `Duration(seconds: ...)`)
- `garbageCollectionEnabled`
- `datastorePath`
- `keystorePath`
- `blockStorePath`
- `dataPath`
- `maxConcurrentBitswapRequests`
- `enableLogging`
- `enableLibp2pBridge`
- `libp2pListenAddress`
- `nodeId`
- `libp2pIdentitySeed` (base64 string, optional)
- `keystore` is **not** serialized directly; only `keystorePath` is persisted. The runtime `Keystore` instance is loaded from that path.

A round-trip unit test must verify that `IPFSConfig.fromJson(config.toJson())` is equivalent to the original for every public scalar and nested config section.

### 3.3 Question 3: Should `IPFSNodeBuilder` or the CLI `daemon` manage `RPCServer` and `GatewayServer`?

| maintainers Lens | Score | Rationale |
|--------------|-------|-----------|
| **Coherence** | 8 | `LifecycleManager` already exists and is the intended owner of `start()`/`stop()` order. Both `RPCServer` and `GatewayServer` already have matching `start()`/`stop()` methods. The only missing step is making them implement `ILifecycle` and registering them in the builder. |
| **Capability** | 9 | CLI `daemon`, Docker health checks, and Kubernetes readiness probes all expect the node object to bring up both services. Centralizing this in the builder gives K8s a single contract. |
| **Safety** | 7 | Registration in the builder guarantees deterministic shutdown order (reverse registration). If the CLI manages them separately, two owners can race on `stop()`. The CLI should still be able to override listen addresses via `--api-addr` and `--gateway-addr`, but lifecycle ownership remains in the builder. |
| **Efficiency** | 8 | The change is small: add `implements ILifecycle` to both server classes and register them in `IPFSNodeBuilder.build()` when their respective config sections are enabled. |
| **Evolution** | 8 | Future services (WebUI server, metrics HTTP server, TLS gateway) can follow the same pattern. The builder becomes the single source of truth for service composition. |

**Decision:** `IPFSNodeBuilder` shall register `RPCServer` and `GatewayServer` with `LifecycleManager` when the node config enables them. The CLI `daemon` command remains responsible for:

- Parsing `--api-addr`, `--gateway-addr`, and `--swarm-addr` overrides.
- Building a config that reflects those overrides (e.g., `GatewayConfig(port: ...)`).
- Calling `IPFSNode.start()` / `IPFSNode.stop()`.

The builder, not the CLI, owns the lifecycle wiring. Both server classes must formally `implement ILifecycle`.

### 3.4 Question 4: Default config path and `--config` override

| maintainers Lens | Score | Rationale |
|--------------|-------|-----------|
| **Coherence** | 9 | Matches Kubo semantics and the existing CLI/Docker/K8s specs. `$IPFS_PATH` is the natural repo root. |
| **Capability** | 9 | Required for Docker volume mounts and K8s ConfigMaps. `--config` override is standard for CLI tooling and integration tests. |
| **Safety** | 7 | Using `$IPFS_PATH` keeps repo data, keys, and config co-located, reducing the risk of mixing config files across nodes. Secrets remain in the keystore or K8s Secrets, not in the config file. |
| **Efficiency** | 9 | One new path resolution helper and a default-fallback in `bin/ipfs.dart`. The YAML fallback in `fromFile` already handles extension sniffing. |
| **Evolution** | 8 | A single `IPFS_PATH` convention supports future repo migrations, snapshots, and plugin data directories. |

**Decision:** The default config path is `$IPFS_PATH/config.json`. Resolve `$IPFS_PATH` from the environment variable; if unset, fall back to `$HOME/.dart_ipfs` on POSIX and `%USERPROFILE%\.dart_ipfs` on Windows. The CLI accepts `--config=<path>` to override. If the supplied path ends in `.yaml` or `.yml`, use YAML parsing; otherwise parse as JSON. CLI first-run initialization must create the repo directory and write a default `config.json` if none exists.

---

## 4. Final Verdict

**Verdict:** APPROVED, with the following binding design decisions:

1. **Canonical format:** JSON (`$IPFS_PATH/config.json`). YAML is accepted as a read-only legacy format when the file extension is `.yaml`/`.yml`.
2. **Serialization completeness:** `IPFSConfig.toJson()` and `fromJson()` must be made round-trip complete for all constructor fields except the runtime `Keystore` object. Add `gateway`, `metrics`, `customConfig`, and all missing scalar/path fields; serialize `libp2pIdentitySeed` as base64 and `garbageCollectionInterval` as seconds; persist only `keystorePath`, never key material.
3. **Lifecycle wiring:** `IPFSNodeBuilder` shall register `RPCServer` and `GatewayServer` with `LifecycleManager` when enabled, after making both classes implement `ILifecycle`. The CLI `daemon` command applies address overrides via config and delegates start/stop to the node lifecycle.
4. **Config path:** Default to `$IPFS_PATH/config.json` with an `--config=<path>` CLI override. The CLI must initialize a default repo and config on first run if missing.

**Implementation order:**

1. Extend `IPFSConfig.toJson()` / `fromJson()` and add round-trip unit tests.
2. Make `RPCServer` and `GatewayServer` implement `ILifecycle`.
3. Update `IPFSNodeBuilder` to conditionally register both servers with `LifecycleManager`.
4. Add `bin/ipfs.dart` CLI entry point, `$IPFS_PATH` resolution, `--config` handling, and first-run JSON generation.
5. Update `CLI_SPEC.md` and `KUBERNETES_SPEC.md` to reflect the JSON default and the builder-managed lifecycle.

---

## 5. maintainers Score Summary

| Question | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|----------|-----------|------------|--------|------------|-----------|---------|
| 1. JSON vs YAML | 8 | 9 | 7 | 9 | 8 | **JSON canonical, YAML read-fallback** |
| 2. Fields to add | 9 | 9 | 6 | 9 | 8 | **Round-trip all non-secret fields** |
| 3. Lifecycle owner | 8 | 9 | 7 | 8 | 8 | **IPFSNodeBuilder registers servers** |
| 4. Default path | 9 | 9 | 7 | 9 | 8 | **$IPFS_PATH/config.json, --config override** |

---

## 6. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Existing YAML tests break | Keep `fromFile` YAML parsing; only change the default writer to JSON. |
| Secret keys leak into config JSON | Never serialize `Keystore`; only `keystorePath`. Add a lint/test that fails if `keystore` appears in `toJson()` output. |
| CLI overrides conflict with config file | CLI flags override config values; builder receives the merged config. |
| `RPCServer`/`GatewayServer` not registered when disabled | Registration is conditional on `config.gateway.enabled` and an RPC config field (add `rpc` section to `IPFSConfig` or use defaults). |
| YAML anchors/aliases round-trip poorly | JSON output flattens aliases; this is acceptable for canonical JSON but must be documented. |
