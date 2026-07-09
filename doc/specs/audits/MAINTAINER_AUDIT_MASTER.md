# Project Review — Master Audit Report

**Subject:** Per-feature specifications for dart_ipfs v2.0+ parity and superiority backlog  
**Audit date:** 2026-06-25  
**Audited specs:** 26 files in `doc/specs/features/`  
**Reviewers:** Coherence, Capability, Safety, Efficiency, Evolution  
**Pass rule:** ≥3/5 scores ≥ 6 and Safety > 3; Safety ≤ 3 is a hard veto.  

---

## 1. Executive Summary

All 26 per-feature specifications were audited by the maintainers. The specs are **directionally sound and mostly release-ready**, but **none passed unconditionally**. Every spec was marked **PASS (conditional)** or **CONDITIONAL** because of one or more of the following cross-cutting issues:

1. **File-path drift in current-state descriptions.** Many specs reference `lib/src/codec/...` paths that do not exist; the actual code lives under `lib/src/core/...`.
2. **Unresolved dependency on the non-standard CAR class.** The existing `lib/src/core/data_structures/car.dart` implements a custom protobuf-based CAR format, which blocks trustless gateway, MFS import/export, and standard CAR work until it is replaced.
3. **Protobuf-generated `IPLDNode` model not acknowledged.** The codecs and selectors must map onto the mutable protobuf `IPLDNode` in `lib/src/proto/generated/ipld/data_model.pb.dart`.
4. **IPFSConfig / lifecycle model gaps.** The CLI, Docker, and plugin specs assume configuration and lifecycle wiring that is incomplete in the current codebase.
5. **A few specs over-promise for v2.0/v2.1.** AutoTLS full ACME, WebTransport native listener, and plugin sandboxing are either premature or mischaracterized.

No spec was rejected (Safety > 3 everywhere). The highest-scoring specs are **METRICS_SPEC.md**, **GOSSIPSUB_SPEC.md**, **DHT_INTEGRATION_SPEC.md**, **CIRCUIT_RELAY_SPEC.md**, **BITSWAP_HTTP_FALLBACK_SPEC.md**, and **GATEWAY_TLS_SPEC.md**, all of which are close to unconditional PASS after minor corrections.

---

## 2. Per-Spec Verdict Matrix

| Spec | Category | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|------|----------|-----------|------------|--------|------------|-----------|---------|
| CAR_FORMAT_SPEC.md | Core Data | 5 | 9 | 8 | 8 | 9 | CONDITIONAL |
| UNIXFS_SPEC.md | Core Data | 6 | 9 | 8 | 8 | 9 | CONDITIONAL |
| DAG_CBOR_SPEC.md | Core Data | 6 | 9 | 8 | 8 | 9 | CONDITIONAL |
| DAG_JSON_SPEC.md | Core Data | 6 | 7 | 8 | 7 | 7 | CONDITIONAL |
| IPLD_SELECTORS_SPEC.md | Core Data | 6 | 9 | 8 | 7 | 9 | CONDITIONAL |
| MFS_SPEC.md | Services | 7 | 9 | 7 | 7 | 9 | PASS (conditional) |
| METRICS_SPEC.md | Services | 9 | 9 | 7 | 8 | 9 | PASS |
| SUBDOMAIN_GATEWAY_SPEC.md | Services | 8 | 8 | 8 | 7 | 8 | PASS (conditional) |
| TRUSTLESS_GATEWAY_SPEC.md | Services | 5 | 9 | 7 | 6 | 9 | CONDITIONAL |
| CONTENT_BLOCKING_SPEC.md | Services | 8 | 8 | 9 | 8 | 8 | PASS (conditional) |
| REPROVIDE_SPEC.md | Networking | 7 | 8 | 6 | 7 | 9 | PASS |
| QUIC_SPEC.md | Networking | 5 | 8 | 6 | 7 | 9 | CONDITIONAL |
| GOSSIPSUB_SPEC.md | Networking | 7 | 9 | 8 | 8 | 9 | PASS |
| DHT_INTEGRATION_SPEC.md | Networking | 7 | 9 | 7 | 7 | 9 | PASS |
| IPNS_SPEC.md | Networking | 6 | 9 | 8 | 8 | 9 | CONDITIONAL |
| CIRCUIT_RELAY_SPEC.md | Networking | 7 | 9 | 7 | 7 | 8 | PASS |
| BROWSER_TRANSPORTS_SPEC.md | Networking | 6 | 7 | 8 | 6 | 8 | CONDITIONAL |
| GRAPHSYNC_SPEC.md | Networking | 6 | 7 | 7 | 7 | 7 | CONDITIONAL |
| BITSWAP_HTTP_FALLBACK_SPEC.md | Networking | 7 | 8 | 7 | 7 | 7 | PASS |
| GATEWAY_TLS_SPEC.md | Networking | 7 | 8 | 8 | 7 | 8 | PASS |
| CLI_SPEC.md | Operations | 7 | 8 | 7 | 7 | 8 | PASS |
| DOCKER_SPEC.md | Operations | 7 | 8 | 8 | 7 | 8 | PASS |
| KUBERNETES_SPEC.md | Operations | 7 | 7 | 8 | 7 | 7 | PASS |
| INTEROP_TESTS_SPEC.md | Operations | 6 | 9 | 6 | 6 | 9 | CONDITIONAL |
| MODULARIZATION_SPEC.md | Operations | 7 | 6 | 8 | 6 | 7 | CONDITIONAL |
| PLUGINS_SPEC.md | Operations | 6 | 7 | 6 | 6 | 7 | CONDITIONAL |

**Verdict totals:**
- PASS (unconditional): 2 (METRICS, GOSSIPSUB)
- PASS (conditional): 9
- CONDITIONAL: 15
- REJECTED: 0
- DEFERRED: 0

---

## 3. Category Summaries

### 3.1 Core Data Layer (5 specs)

All specs are strong on capability and evolution but weakened by **Coherence** due to stale paths and current-state descriptions.

**Top blockers:**
- `lib/src/codec/...` path drift in CAR_FORMAT_SPEC, DAG_CBOR_SPEC, DAG_JSON_SPEC, IPLD_SELECTORS_SPEC.
- `UNIXFS_SPEC.md` claims directory logic exists under `lib/src/core/unixfs/`; only `unixfs_builder.dart` (file chunking) exists there.
- The existing protobuf `CAR`/`CarHeader`/`CarIndex` classes in `lib/src/core/data_structures/car.dart` collide with the proposed standard `CarReader`/`CarWriter` API.
- Two competing `IPLDCodec` interfaces (`lib/src/core/ipld/codecs/ipld_codec.dart` vs `lib/src/core/ipld/dag_json_codec.dart`) are not reconciled in `DAG_JSON_SPEC.md`.
- `DagPbCodec` sets `mtime = DateTime.now().millisecondsSinceEpoch`, which breaks CID determinism and must be fixed before UnixFS acceptance tests.
- `IPLDNode` is a protobuf-generated mutable model; the specs do not explain how the new codecs and selectors will use it.

**Fastest path to PASS:**
1. Fix all file paths to actual `lib/src/core/...` locations.
2. Rewrite current-state sections to describe the real code.
3. Add a CAR migration plan (delete/rename/refactor existing `CAR` classes).
4. Reconcile `IPLDCodec` interfaces.
5. Remove non-deterministic `mtime` from `DagPbCodec`.

See: <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_CORE_DATA_LAYER.md" />

### 3.2 Services & APIs (5 specs)

This is the strongest category. METRICS_SPEC is essentially ready. TRUSTLESS_GATEWAY_SPEC is the only one held back by the non-standard CAR dependency.

**Top blockers:**
- `TRUSTLESS_GATEWAY_SPEC.md` assumes the existing `lib/src/core/data_structures/car.dart` can produce standard CAR output; it cannot.
- `MFS_SPEC.md` describes `flush`/`sync` as materializing an in-memory delta, but `MFSManager` already persists the root CID after every mutation (`_modifyPath` at line 272). Flush/sync semantics need clarification.
- `SUBDOMAIN_GATEWAY_SPEC.md` needs explicit rules for `localhost` precedence and TLS redirect defaults.
- `CONTENT_BLOCKING_SPEC.md` needs clearer parser rules for base32 multihash vs CID and comment formats.

**Fastest path to PASS:**
1. Make TRUSTLESS gateway depend on the standard CAR encoder (CAR_FORMAT_SPEC).
2. Clarify MFS flush/sync semantics or introduce a real delta buffer.
3. Add localhost/DNSLink precedence rules to subdomain spec.

See: <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_SERVICES_APIS.md" />

### 3.3 Networking, Naming & P2P (10 specs)

Several specs are ready to implement (GOSSIPSUB, DHT_INTEGRATION, CIRCUIT_RELAY, BITSWAP_HTTP_FALLBACK, GATEWAY_TLS). The weaker ones are blocked by dependency uncertainty or false premises.

**Top blockers:**
- `QUIC_SPEC.md` assumes `package:ipfs_libp2p` provides a QUIC transport without verification. A dependency spike is required before implementation.
- `IPNS_SPEC.md` needs `PeerId` base36 primitives (`toBase36`, `fromBase36`) that are missing in `lib/src/core/types/peer_id.dart`.
- `BROWSER_TRANSPORTS_SPEC.md` calls for a native `WebTransportListener` that is unrealistic; the `Conn` metadata section does not match the actual `libp2p.Conn` interface.
- `GRAPHSYNC_SPEC.md` incorrectly states that `RouterInterface` does not support unicast; `sendMessage` exists. The spec is also hard-blocked on the P0 IPLD selector implementation.
- `REPROVIDE_SPEC.md` references DHT server/client modes and a denylist service that are not yet modeled.
- `DHT_INTEGRATION_SPEC.md` overlaps with `REPROVIDE_SPEC.md` on the reprovide sweep; duplicate `storeValue`/`getValue` surface vs `DHTHandler` needs clarification.

**Fastest path to PASS:**
1. Verify `ipfs_libp2p` QUIC transport availability or define a fallback plan.
2. Add `PeerId` base36 support before IPNS implementation.
3. Scope browser transport hardening to achievable items (web dialer, STUN/TURN config, cert hash validation).
4. Remove the false unicast premise from GraphSync spec; clarify dependency on IPLD selectors.

See: <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_NETWORKING_P2P_1.md" /> and <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_NETWORKING_P2P_2.md" />

### 3.4 Operations, Modularity & Ecosystem (6 specs)

CLI, Docker, and Kubernetes specs are ready for implementation. Interop, modularization, and plugins are conditional because they depend on stabilizing other layers or over-promise sandboxing.

**Top blockers:**
- `IPFSNodeBuilder` (`lib/src/core/builders/ipfs_node_builder.dart:135-136`) registers `LifecycleManager` but not `RPCServer` or `GatewayServer`; the CLI `daemon` command must manage these explicitly.
- `IPFSConfig.toJson()` (`lib/src/core/config/ipfs_config.dart:300-322`) omits gateway, metrics, keystore, and customConfig, breaking CLI `config` commands and plugin settings.
- `IPFSConfig.fromFile` reads YAML, but CLI/Docker examples reference `config.json`.
- Version string drift: `rpc_handlers.dart` and `gateway_server.dart` hard-code `dart_ipfs/0.1.0`; `pubspec.yaml` is `1.11.5`; `Dockerfile` is `1.2.4-secure`.
- `pubspec.yaml` includes `sodium: ^4.0.2+1`, which wraps `libsodium`. The Docker spec's proposed distroless base will fail unless a glibc base is chosen or libsodium is statically linked.
- `PLUGINS_SPEC.md` incorrectly claims Dart Isolates provide a security sandbox; they share the same OS process and can use FFI/network/filesystem.
- `PLUGINS_SPEC.md` proposes committing `tool/plugin_dev_key.pem` to the repo; this must never be committed.
- `INTEROP_TESTS_SPEC.md` makes DHT provide/find and IPNS resolution P0 release-blocking, but those protocols are still stabilizing. They should be P1 allowed-to-fail until networking specs are proven.
- `MODULARIZATION_SPEC.md` should be a v2.2.x/rc deliverable, not a v2.2.0 blocker, and needs a workspace tooling decision (Melos vs native `pubspec_overrides.yaml`).

**Fastest path to PASS:**
1. Fix IPFSConfig serialization and lifecycle wiring.
2. Unify version string source (use `pubspec.yaml`).
3. Correct plugin security model (do not claim Isolates are a sandbox; do not commit dev keys).
4. Move interop DHT/IPNS tests to P1 allowed-to-fail.
5. Choose monorepo tooling before extraction begins.

See: <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_OPERATIONS_ECOSYSTEM.md" />

---

## 4. Cross-Cutting Blockers

The following issues affect multiple specs and should be resolved before implementation begins:

| Issue | Affected Specs | Action |
|-------|---------------|--------|
| Non-standard `CAR` class in `lib/src/core/data_structures/car.dart` | CAR_FORMAT, TRUSTLESS_GATEWAY, MFS, GRAPHSSYNC | Define migration plan and implement standard CAR encoder first. |
| Stale `lib/src/codec/...` paths in specs | CAR_FORMAT, DAG_CBOR, DAG_JSON, IPLD_SELECTORS | Fix all paths to `lib/src/core/...`. |
| Two competing `IPLDCodec` interfaces | DAG_JSON, IPLD_SELECTORS | Reconcile or eliminate the duplicate interface before implementation. |
| Non-deterministic `mtime` in `DagPbCodec` | UNIXFS, CAR_FORMAT | Remove `DateTime.now()` from DAG-PB encoding. |
| Protobuf-generated `IPLDNode` model | DAG_CBOR, DAG_JSON, IPLD_SELECTORS, GRAPHSSYNC | Document how codecs/selectors map onto the mutable protobuf model. |
| Missing `PeerId` base36 primitives | IPNS, SUBDOMAIN_GATEWAY | Add `toBase36`/`fromBase36` to `PeerId`. |
| IPFSConfig incomplete serialization | CLI, DOCKER, KUBERNETES, PLUGINS | Fix `toJson`/`fromFile` and add missing config sections. |
| Lifecycle wiring for RPC/Gateway servers | CLI, DOCKER, KUBERNETES | Extend `IPFSNodeBuilder` lifecycle or document CLI daemon management. |
| `libsodium` native dependency conflicts with distroless base | DOCKER, KUBERNETES | Choose glibc base or remove/inline libsodium dependency. |
| Version string drift across codebase | CLI, DOCKER, INTEROP_TESTS | Use a single source of truth (pubspec.yaml). |

---

## 5. Recommended Action Plan

### Immediate (before any implementation)

1. Fix file paths and current-state descriptions in all Core Data specs.
2. Define the CAR migration plan and reconcile `IPLDCodec` interfaces.
3. Remove non-deterministic `mtime` from `DagPbCodec`.
4. Fix `IPFSConfig` serialization and add missing sections.
5. Unify version string source.
6. Correct plugin security model and remove committed dev key proposal.

### Before P0 implementation starts

7. Verify `ipfs_libp2p` QUIC transport or define fallback.
8. Add `PeerId` base36 primitives.
9. Decide monorepo tooling (Melos vs native).
10. Re-audit the 15 CONDITIONAL specs after corrections; target ≥20 unconditional PASS specs.

### Implementation priority order (after audit corrections)

1. **Standard CAR v1/v2** (blocks trustless gateway, MFS, GraphSync)
2. **Spec-compliant DAG-CBOR** (blocks CAR v2, IPLD selectors)
3. **UnixFS basic directories** (foundational for file system parity)
4. **IPLD selectors** (blocks GraphSync)
5. **Real metrics** (ready now)
6. **Gossipsub compliance** (ready now)
7. **DHT integration** (foundational for IPNS, reprovide)
8. **IPNS DHT-first signing** (after DHT + PeerId base36)
9. **MFS completeness** (after clarifying flush semantics)
10. **Trustless gateway** (after standard CAR)
11. **CLI / daemon** (after config/lifecycle fixes)
12. **Docker images** (after libsodium base decision)
13. **Interop tests** (after P0 networking stabilizes)

---

## 6. Audit Report Files

Detailed findings, scores, and recommendations are in the per-category reports:

- <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_CORE_DATA_LAYER.md" />
- <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_SERVICES_APIS.md" />
- <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_NETWORKING_P2P_1.md" />
- <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_NETWORKING_P2P_2.md" />
- <ref_file file="C:\Users\josee\IPFS\doc\specs\audits\MAINTAINER_AUDIT_OPERATIONS_ECOSYSTEM.md" />

---

**Audit completed by:** project maintainers  
**Date:** 2026-06-25
