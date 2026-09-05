# RFC: Migration from `ipfs_libp2p` (0.5.6) to `dart_libp2p` (1.0.3)

- **Author**: CIEL Council of Five
- **Status**: Proposed / High-Tier RFC
- **Target Release**: `dart_ipfs` v1.15.0+
- **Date**: 2026-09-05

---

## 1. Executive Summary

Upstream maintainer Stephan February has evolved the Dart libp2p networking stack from `ipfs_libp2p` (last published as `0.5.6` on 2026-02-03) to the official **`dart_libp2p`** package (published as `1.0.0` through `1.0.3` on 2026-02-22).

`dart_ipfs` currently pins `ipfs_libp2p: ^0.5.6` with a mandatory `dependency_override` on `dart_udx: ^2.0.3`. While the current setup is stable and passes all 3,478 unit tests and Docker interop suites, maintaining a 7-month-old pre-1.0 dependency creates technical debt and prevents adopting modern libp2p capabilities.

This document establishes the formal architectural analysis, breaking-change assessment, and phased execution DAG for safely migrating `dart_ipfs` to `dart_libp2p: ^1.0.3`.

---

## 2. Upstream Ecosystem Evolution

### 2.1 Package Renaming and Ownership
- **Legacy Hosted**: `ipfs_libp2p` (`0.5.6` max, abandoned namespace on pub.dev)
- **Active Hosted**: `dart_libp2p` (`1.0.3` current on pub.dev)
- **Repository**: [`https://github.com/stephanfeb/dart_libp2p`](https://github.com/stephanfeb/dart_libp2p)

### 2.2 Key Features in `dart_libp2p` 1.0.x
1. **Circuit Relay v2**: Full relay implementation with end-to-end relayed handshakes, connection reuse, and parallel dialing.
2. **AmbientAutoNATv2**: AutoNAT v2 client/server with delimited protobuf message framing (`pbio.NewDelimitedReader`/`Writer`), matching `go-libp2p`.
3. **Native UDX 2.0.3 Integration**: Upstream depends directly on `dart_udx: ^2.0.3`, fixing control-only stream packet (WindowUpdate) sequence stalls on payloads >60 KB.
4. **Hole Punching & DCUtR**: Standardized NAT traversal tested against live Go peers.
5. **Typed Exceptions**: Introduces `IdentifyTimeoutException` and structured error handling.

---

## 3. Impact Assessment on `dart_ipfs`

### 3.1 Direct Dependents in Repository
1. **Root `IPFS/pubspec.yaml`**:
   ```yaml
   # Current:
   ipfs_libp2p: ^0.5.6
   # Target:
   dart_libp2p: ^1.0.3
   ```
2. **`packages/dart_ipfs_quic/pubspec.yaml`**:
   ```yaml
   # Current:
   ipfs_libp2p: ^0.5.6
   # Target:
   dart_libp2p: ^1.0.3
   ```

### 3.2 Dependency Overrides Elimination
In `IPFS/pubspec.yaml`:
```yaml
# Under ipfs_libp2p: ^0.5.6, this override was mandatory:
dependency_overrides:
  dart_udx: ^2.0.3
```
Under `dart_libp2p: ^1.0.3`, `dart_udx: ^2.0.3` is declared upstream as a standard dependency, allowing removal of the security-sensitive override.

### 3.3 Breaking API Surfaces to Audit
- **Host & Options Factory**: `p2p_config.Libp2p.new_(options)` signature and option types.
- **Swarm / Connection Manager**: Stream closing and half-close semantics.
- **AutoNAT / Relay**: Migration from legacy NAT stubs to `AmbientAutoNATv2` and `CircuitRelayV2`.
- **PeerID / Multiaddr**: Import URI updates from `package:ipfs_libp2p/...` to `package:dart_libp2p/...`.

---

## 4. Phased Execution DAG

```
[Phase 1: Isolated Branch] ──> [Phase 2: Import Sweeps & Compile] ──> [Phase 3: Unit Test Suite] ──> [Phase 4: Interop & Docker] ──> [Phase 5: Release v1.15.0]
```

### Phase 1: Branch Isolation
- Create worktree/branch: `git checkout -b feat/dart-libp2p-1.0-migration`.
- Update `pubspec.yaml` in root and `packages/dart_ipfs_quic`.
- Remove `dart_udx` from `dependency_overrides`.

### Phase 2: Import Sweep & Structural Refactor
- Search-replace `package:ipfs_libp2p/` with `package:dart_libp2p/`.
- Resolve any renamed classes, constructors, or moved export barrels.
- Run `dart analyze` to ensure zero compilation or type errors.

### Phase 3: Unit Verification Gate
- Run full host test suite:
  ```bash
  dart test --reporter=compact
  ```
- Target: 0 failures across all 3,478 tests.

### Phase 4: Docker / Kubo Interop Gate
- Run integration tests inside Docker harness:
  ```bash
  cd test/interop
  docker compose up -d --build
  docker compose exec -T test-runner sh -c "cd /app && dart test --preset interop test/interop"
  ```
- Verify Bitswap, CAR exchange, and DHT provide/find with Kubo/Helia nodes.

### Phase 5: Documentation & Release
- Update `CHANGELOG.md` in `IPFS` and `dart_ipfs_quic`.
- Remove legacy warnings in `SECURITY.md` regarding libp2p transitive dependencies.
- Tag and release `dart_ipfs v1.15.0` and `dart_ipfs_quic v0.3.0`.

---

## 5. Risk Assessment & Safety Governance

| Risk | Severity | Mitigation |
| :--- | :--- | :--- |
| **Stream Multiplexing Incompatibilities** | High | Yamux framing tests verified against Go-libp2p test harness. |
| **DHT Routing Table Drift** | Medium | Covered by interop suite tests in `test/interop/`. |
| **Breaking API Changes in `dart_ipfs_quic`** | Medium | `QuicTransport` interface conformance tests in `packages/dart_ipfs_quic/test/`. |
| **Flutter Web Compatibility Regression** | Low | `dart_libp2p` maintains existing mobile/desktop/server platform constraints. |

---

## 6. Conclusion

Migrating to `dart_libp2p: ^1.0.3` is the logical next evolutionary milestone for `dart_ipfs`. By preserving `ipfs_libp2p: ^0.5.6` in the current production release and executing this RFC during the v1.15.0 sprint, stability is preserved while providing an uncompromising path toward modern libp2p compliance.
