# Project Review — Comprehensive Gap Audit Verdict

## Scope

Full-project gap audit of `dart_ipfs` v1.11.5 against (a) all official IPFS/libp2p specs and (b) all major competitors (Kubo, Helia, rust-ipfs/iroh, Nabu). Goal: spec compliance and competitor parity on all aspects.

- `dart_ipfs` at commit `842425b` (master, post-quic_lib 1.13.0 canonicalization)
- Five seats deliberated in parallel: Spec Compliance, Competitor Parity, Code Quality & Architecture, Security & Testing, Docs/Examples/Release Hygiene

## Top-level verdict

**NOT READY for full Kubo/Helia wire interoperability. Production-ready for embedded Dart/Flutter, gateway, and RPC use cases.**

| Dimension | Score | Status |
| --- | --- | --- |
| Spec compliance | PARTIAL | Core data layer compliant; critical libp2p protocols missing |
| Competitor parity (vs Kubo) | 74% | PARTIAL — behind on advanced DHT, pinning, CLI |
| Competitor parity (vs Helia) | 77% | PARITY — ahead on Flutter, behind on WASM/ecosystem |
| Code quality & architecture | C+ | MEDIUM-HIGH RISK — spec/impl gap on modularization |
| Security | 6.5/10 | MODERATE — modern crypto, but no fuzz testing |
| Testing | 7.5/10 | GOOD — 100+ test files, but 13 skipped interop tests |
| Docs/examples/release | PASS w/ CRITICAL fixes | Strong docs, repo URL inconsistency blocks publishing |

## Consolidated gap register (ranked by severity)

### CRITICAL (blocks interop or release)

| # | Gap | Seat | Evidence |
| --- | --- | --- | --- |
| C1 | Identify protocol not implemented | 1 | No handler found; cannot exchange peer info/protocols/addresses |
| C2 | QUIC TLS 1.3 libp2p handshake incomplete | 1 | `packages/dart_ipfs_quic/lib/src/quic_transport.dart:238-246`; peer ID binding missing |
| C3 | Umbrella package does not use `dart_ipfs_core` | 3 | 0 imports of dart_ipfs_core in lib/src; violates MODULARIZATION_SPEC.md:119-123 |
| C4 | Pervasive deep imports (100+) violate deprecation policy | 3 | CHANGELOG.md:26-27 deprecates `package:dart_ipfs/src/...` |
| C5 | No fuzz testing for parsers (CBOR, CID, multihash, protobuf) | 4 | grep for fuzz/property.test returned 0 results |
| C6 | Repository URL inconsistency in `dart_ipfs_quic` pubspec | 5 | `packages/dart_ipfs_quic/pubspec.yaml:4-5` points to `joseerrojas/dart_ipfs`, root uses `jxoesneon/IPFS` |
| C7 | Missing `pubspec.lock` (in `.gitignore`) — non-reproducible builds | 5 | `.gitignore:10` |

### HIGH (significant functional or security gaps)

| # | Gap | Seat | Evidence |
| --- | --- | --- | --- |
| H1 | Autonat protocol not implemented (heuristic only) | 1 | `lib/src/core/ipfs_node/auto_nat_handler.dart` — no dialback protocol |
| H2 | Peer records not implemented | 1 | No signed peer record envelope handling |
| H3 | RSA/ECDSA peer ID support missing (Ed25519 only) | 1 | `lib/src/transport/libp2p_router.dart:136-144` |
| H4 | Circuit Relay STOP endpoint missing (HOP client only) | 1 | `lib/src/transport/circuit_relay_client_io.dart` |
| H5 | StreamController resource leaks (60 instances, some uncleaned) | 3 | `lib/src/transport/libp2p_router.dart:71` |
| H6 | Crypto dependency sprawl (4 libs: crypto, pointycastle, sodium, cryptography) | 3,4 | `pubspec.yaml:23-24,73-74` |
| H7 | Dependency overrides undocumented (`xml`, `dart_udx`) | 3,4 | `pubspec.yaml:101-103` |
| H8 | Unbounded rate limiter queue (memory exhaustion DoS) | 4 | `lib/src/protocols/dht/rate_limiter.dart:20` |
| H9 | No property-based testing | 4 | No QuickCheck/property.test found |
| H10 | 13 skipped interop tests | 4 | `test/interop/test/*.dart` (CAR, IPNS, DHT, Helia, gateway, bitswap) |
| H11 | Dead wiki link in README | 5 | `README.md:27` → 404 |
| H12 | Missing `CODE_OF_CONDUCT.md` | 5 | Not found in repo |
| H13 | Version drift README vs pub.dev (README says ^1.11.5, pub.dev latest 1.11.4) | 5 | `README.md:155` |
| H14 | No CI coverage workflow despite "90% Coverage" claim | 5 | No coverage.yml in `.github/workflows/` |
| H15 | Type safety: unsafe dynamic casts | 3 | `lib/src/core/ipfs_node/ipfs_node.dart:553-554` |

### MEDIUM (performance, completeness, polish)

| # | Gap | Seat | Evidence |
| --- | --- | --- | --- |
| M1 | UnixFS HAMT sharding incomplete (large dirs won't match Kubo CIDs) | 1 | `lib/src/core/unixfs/unixfs_hamt.dart` not integrated |
| M2 | DAG-CBOR canonical key ordering not enforced | 1 | `packages/dart_ipfs_core/lib/src/codec/dag_cbor_codec.dart` |
| M3 | Bitswap v1.4 features missing (session manager) | 1 | `lib/src/protocols/bitswap/bitswap_handler.dart:60` (v1.2.0 only) |
| M4 | WebTransport RFC 9220 incomplete (Extended CONNECT, datagrams) | 1 | `lib/src/transport/webtransport/` |
| M5 | Delegated routing / Reframe / IPNI not implemented | 1,2 | No reframe/IPNI; delegated routing partial |
| M6 | Accelerated DHT / Optimistic Provide missing | 2 | No impl; Kubo 0.39+ ships it |
| M7 | Remote Pinning Service API missing | 2 | No `ipfs pin remote` |
| M8 | IPFS Cluster equivalent missing | 2 | No distributed pinning |
| M9 | DCUtR not implemented | 1,2 | No impl |
| M10 | Peering service missing | 2 | No persistent connection management |
| M11 | CLI completeness (10 vs Kubo 50+ commands) | 2 | `bin/ipfs.dart:24-34` |
| M12 | WASM support missing (planned v3.0) | 2 | `ROADMAP.md:283` |
| M13 | Incomplete AutoTLS (ACME HTTP-01 TODO) | 4 | `lib/src/services/gateway/gateway_tls_manager.dart:83` |
| M14 | No CSP headers on gateway | 4 | `lib/src/services/gateway/gateway_handler.dart` |
| M15 | Outdated SECURITY.md (wrong override versions) | 4 | `lib/SECURITY.md:60-62` vs `pubspec.yaml:101-103` |
| M16 | Large files need decomposition (gateway_handler 1266+ lines) | 3 | `lib/src/services/gateway/gateway_handler.dart` |
| M17 | Error swallowing in non-critical DHT paths | 3 | `lib/src/protocols/dht/dht_handler.dart:117-120` |
| M18 | `build.yml` references non-existent `example/main.dart` | 5 | `.github/workflows/build.yml:29` |
| M19 | No pana score check in publish CI | 5 | `.github/workflows/publish.yml` |
| M20 | No CodeQL for Dart (JS only) | 4 | `.github/workflows/codeql.yml:27` |

### LOW (polish, debt)

| # | Gap | Seat |
| --- | --- | --- |
| L1 | Limited multicodec registry (13 vs full table) | 1 |
| L2 | IPNS PubSub notification is stub | 1 |
| L3 | Floodsub not implemented (deprecated) | 1 |
| L4 | Cuttlefish v2 not implemented | 1 |
| L5 | Ping protocol not implemented | 1 |
| L6 | Commented debug code (network_handler_io.dart:116-166) | 3 |
| L7 | Test secrets hardcoded ('secret', 'secret-key') | 4 |
| L8 | Some tests exist only for coverage | 4 |
| L9 | Missing troubleshooting guide / FAQ | 5 |
| L10 | 10 TODO/FIXME in production code | 3,5 |

## Where dart_ipfs is AHEAD of competitors

1. Flutter integration (no competitor has it)
2. Multi-platform native (Dart VM + Web + Flutter)
3. MFS implementation (ahead of Helia, rust-ipfs, Nabu)
4. Prometheus metrics built-in (ahead of Helia, rust-ipfs, Nabu)
5. DagJose codec (ahead of Kubo, rust-ipfs, Nabu)
6. WebRTC transport (ahead of Kubo, rust-ipfs, Nabu)
7. Kubernetes/Helm charts (ahead of Helia, rust-ipfs, Nabu)
8. Bitswap HTTP fallback (ahead of rust-ipfs, Nabu)
9. Subdomain gateway + AutoTLS (ahead of Helia, rust-ipfs, Nabu)
10. Kubo interop tests in CI (ahead of rust-ipfs, Nabu)

## Maintainer Review
### Seat 1 — Spec Compliance (Verdict: NOT READY for wire interop)

Core data structures (CID, multihash, multibase) are spec-compliant. Bitswap 1.2.0, Gossipsub v1.1, IPNS, GraphSync, Kademlia DHT all implemented. However, **identify, peer records, autonat protocol, DCUtR, and ping are missing**, and **QUIC TLS 1.3 libp2p handshake is incomplete** — these block Kubo/Helia interop for peer discovery, NAT traversal, and secure QUIC connections.

### Seat 2 — Competitor Parity (Verdict: 74% vs Kubo, 77% vs Helia)

At parity on core protocols, trustless gateway, CAR, IPLD selectors, and operations. Behind Kubo on: Optimistic Provide, remote pinning, IPFS Cluster, DCUtR, peering, CLI completeness (10 vs 50+), IPNI/Reframe. Behind Helia on: modular package ecosystem, WASM, IPNI/Reframe. Ahead on: Flutter, MFS, Prometheus, DagJose, WebRTC, K8s/Helm, multi-platform.

### Seat 3 — Code Quality & Architecture (Verdict: C+, MEDIUM-HIGH RISK)

Architecture is sound on paper (documented layering, well-defined interfaces, IPFSNode is a facade not a god object). **Critical implementation gap**: umbrella package doesn't use `dart_ipfs_core` (violates MODULARIZATION_SPEC), 100+ deep imports violate the deprecation policy. Type safety issues with dynamic, StreamController leak risk, crypto dependency sprawl.

### Seat 4 — Security & Testing (Verdict: MODERATE 6.5/10, GOOD 7.5/10)

Modern cryptography (Ed25519, AES-256-GCM, PBKDF2 100k iterations), constant-time comparisons, comprehensive input validation with resource limits, path traversal protection, rate limiting. **Critical gap**: no fuzz testing for parsers. No property-based testing. 13 skipped interop tests. Dependency overrides undocumented. Unbounded rate limiter queue. AutoTLS incomplete.

### Seat 5 — Docs/Examples/Release (Verdict: PASS with CRITICAL fixes)

Strong documentation (26 specs, 7 ADRs, 7556 doc comments, hosted dartdocs). Functional examples (CLI dashboard, Flutter dashboard, 4 standalone). Comprehensive CI (10 workflows). **Critical**: repo URL inconsistency in dart_ipfs_quic pubspec (joseerrojas vs jxoesneon), missing pubspec.lock, dead wiki link, missing CODE_OF_CONDUCT.md, version drift, no coverage workflow.

## Recommended remediation roadmap

### P0 — Before next release (blocks interop/release)
1. Fix repo URL inconsistency in `dart_ipfs_quic` pubspec (C6)
2. Implement identify protocol (C1)
3. Complete QUIC TLS 1.3 libp2p handshake (C2)
4. Commit `pubspec.lock` or document exclusion (C7)
5. Add fuzz testing for CBOR/CID/multihash/protobuf parsers (C5)

### P1 — Next sprint
6. Migrate umbrella package to use `dart_ipfs_core` (C3)
7. Eliminate deep imports, enforce barrel exports (C4)
8. Implement peer records (H2)
9. Implement autonat protocol (H1)
10. Add RSA/ECDSA peer ID support (H3)
11. Implement Circuit Relay STOP (H4)
12. Add property-based testing (H9)
13. Implement skipped interop tests (H10)
14. Add CODE_OF_CONDUCT.md, fix wiki link, fix version drift (H11-H13)
15. Add CI coverage workflow (H14)
16. Document dependency overrides (H7)
17. Bound rate limiter queue (H8)

### P2 — Next quarter
18. Implement Accelerated DHT / Optimistic Provide (M6)
19. Add Remote Pinning Service API (M7)
20. Implement DCUtR (M9)
21. Add IPNI/Reframe (M5)
22. Expand CLI to 30+ commands (M11)
23. Complete WebTransport RFC 9220 (M4)
24. Upgrade Bitswap to v1.4 (M3)
25. Fix DAG-CBOR canonical encoding (M2)
26. Integrate UnixFS HAMT sharding (M1)
27. Add WASM build (M12)
28. Consolidate crypto dependencies (H6)
29. Audit StreamController lifecycles (H5)
30. Add CSP headers, complete AutoTLS (M13-M14)

## Dissenting notes

- Seat 2 notes the IMPLEMENTATION_INVENTORY.md claims 26/26 specs complete, but Seat 1 found several of those (autonat, identify, peer records) are stubs or heuristic-only — **inventory overstates completeness**.
- Seat 3 notes the modularization gap is the root cause of much technical debt — fixing C3/C4 would cascade-improve maintainability.
- Seat 4 notes the lack of fuzz testing is the single highest-risk security gap given the amount of binary parsing (CBOR, protobuf, multihash, CID, bitswap messages).

## Verification commands (Iron Law)

```
dart pub get                          # dependency resolution
dart analyze                          # static analysis
dart test                             # full test suite
dart test --coverage=coverage         # coverage
dart pub publish --dry-run            # publishability
dart pub global activate pana && pana .  # pub.dev score
```

---

**Audit date:** 2026-07-07
**Maintainers:** project maintainers
**Status:** OPEN — remediation roadmap P0 items must close before next release
