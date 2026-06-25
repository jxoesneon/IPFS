# dart_ipfs Cross-Implementation Interoperability Test Suite Specification

**Document ID:** `INTEROP_TESTS_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Status:** Draft specification for implementation  
**Council Priority:** P0 APPROVED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.4

---

## 1. Goal and Scope

The goal of this specification is to ensure that `dart_ipfs` behaves correctly when interacting with other IPFS implementations at the wire level. The v2.2 interoperability test suite will run automatically in CI, spin up reference peer nodes, and verify that the highest-risk protocols behave identically across implementations.

Scope for v2.2:

- Automated interoperability tests against **Kubo** for CAR exchange, Bitswap fetch, gateway retrieval, DHT provide/find, and IPNS resolution.
- A Docker Compose network that includes a `dart_ipfs` node and a pinned Kubo node.
- Dart test harnesses under `test/interop/` with thin RPC clients for both implementations.
- CI job that blocks PRs touching protocol or service code when P0 scenarios fail.
- Helia (Node.js) test jobs scaffolded as P1+; they may report results but are allowed to fail until stabilized.

Out of scope for v2.2:

- Exhaustive conformance against every IPFS implementation.
- Browser-based interop tests (filed under P2 WASM/web).
- Long-running soak tests or performance benchmarks.

---

## 2. Official References

- Kubo CLI reference: https://docs.ipfs.tech/reference/kubo/cli/
- Kubo RPC API (`/api/v0/*`): https://docs.ipfs.tech/reference/kubo/rpc/
- IPFS gateway specifications: https://specs.ipfs.tech/http-gateways/
- IPNS record spec: https://specs.ipfs.tech/ipns/ipns-record/
- Bitswap specification: https://specs.ipfs.tech/bitswap/
- libp2p specifications: https://docs.libp2p.io/
- CAR v1/v2 format: https://ipld.io/specs/transport/car/
- Helia documentation: https://github.com/ipfs/helia
- IPFS testing best practices: https://docs.ipfs.tech/community/
- Dart testing: https://dart.dev/guides/testing
- Docker Compose: https://docs.docker.com/compose/

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Interop tests | No automated CI tests against other IPFS implementations. | Risk of drifting from Kubo/Helia wire behavior (Bitswap, CAR, DHT, IPNS). |
| Test harness | No shared helper library for cross-impl RPC clients. | Every scenario would require ad-hoc shell scripting. |
| Kubo pinning | No pinned Kubo version file or Renovate tracking. | Tests may break unpredictably on new Kubo releases. |
| Docker network | No `test/interop/docker-compose.yml`. | Cannot stand up a reproducible multi-impl network in CI. |
| Failure artifacts | No log or packet capture retention. | Debugging flaky interop failures is difficult. |

Key files to create or extend:

- `test/interop/docker-compose.yml`
- `test/interop/bin/setup.dart`
- `test/interop/test/car_test.dart`
- `test/interop/test/bitswap_test.dart`
- `test/interop/test/gateway_test.dart`
- `test/interop/test/dht_test.dart`
- `test/interop/test/ipns_test.dart`
- `test/interop/lib/kubo_client.dart`
- `test/interop/lib/dart_ipfs_client.dart`
- `test/interop/lib/cid_matcher.dart`
- `test/interop/.kubo-version`
- `.github/workflows/interop.yml`

---

## 4. Target State / Requirements

### 4.1 Test Matrix

| Scenario | dart_ipfs Role | Peer(s) | Verdict | Test Steps |
|----------|----------------|---------|---------|------------|
| **CAR exchange** | exporter / importer | Kubo | P0 | 1. Add file to dart_ipfs. 2. Kubo `ipfs dag export` vs. dart_ipfs `/api/v0/dag/export`. 3. Compare CID roots and block contents. 4. Import Kubo CAR into dart_ipfs and verify. |
| **Bitswap fetch** | provider / requester | Kubo | P0 | 1. Add file to dart_ipfs. 2. Kubo `ipfs block get <cid>` and `ipfs cat <cid>`. 3. Reverse direction. 4. Assert bytes match. |
| **Gateway retrieval** | gateway / client | Kubo or `curl` | P0 | 1. Add file to dart_ipfs. 2. `curl http://dart-ipfs-gateway:8080/ipfs/<cid>` returns correct bytes and content type. 3. Test `?format=raw` and `?format=car` trustless modes. |
| **DHT provide / find** | provider / finder | Kubo | P0 | 1. dart_ipfs provides a CID. 2. Kubo `ipfs dht findprovs <cid>` lists the dart_ipfs peer. 3. Reverse direction. 4. Timeout < 60 s in CI. |
| **IPNS resolution** | publisher / resolver | Kubo | P0 | 1. dart_ipfs publishes signed IPNS record to DHT. 2. Kubo `ipfs name resolve <ipns-key>` returns the CID. 3. Reverse direction. |
| **Helia Bitswap** | requester / provider | Helia (Node.js) | P1+ | Repeat Bitswap scenario with a Helia node. Optional for v2.2 but CI job must be scaffolded. |
| **Helia CAR** | exporter / importer | Helia | P1+ | Repeat CAR scenario with Helia. Optional for v2.2. |

### 4.2 CI Architecture

- Create `.github/workflows/interop.yml` triggered:
  - On every PR touching `lib/src/protocols/`, `lib/src/services/`, or `bin/`.
  - Nightly against `main`.
- Run a lightweight Docker network in CI:
  - `docker compose -f test/interop/docker-compose.yml up -d` with dart_ipfs, Kubo, and optionally Helia services.
  - Wait for health checks.
  - Execute the Dart test suite in `test/interop/`.
- Pin the Kubo version in `test/interop/.kubo-version` and track updates via Renovate or Dependabot.
- Default to a recent stable Kubo release at the time of implementation.
- Helia tests run in a separate job matrix entry and are allowed to fail (`continue-on-error: true`) until stabilized.

### 4.3 Test Harness Layout

```
test/interop/
├── docker-compose.yml       # defines dart_ipfs, kubo, helia services
├── .kubo-version            # pinned Kubo version
├── bin/
│   └── setup.dart           # waits for peers and bootstraps connectivity
├── lib/
│   ├── kubo_client.dart   # thin RPC client for Kubo /api/v0/*
│   ├── dart_ipfs_client.dart # thin RPC client for dart_ipfs /api/v0/*
│   └── cid_matcher.dart     # deterministic CID comparison helpers
└── test/
    ├── car_test.dart
    ├── bitswap_test.dart
    ├── gateway_test.dart
    ├── dht_test.dart
    └── ipns_test.dart
```

### 4.4 Retry and Timeout Policy

| Scenario | Success Criteria | Retry/Timeout Policy |
|----------|------------------|----------------------|
| CAR export/import | Byte-exact CAR; root CID matches. | 3 retries, 60 s timeout. |
| Bitswap | Both directions return exact bytes. | 3 retries, 120 s timeout. |
| Gateway | Correct body, headers, trustless format. | 10 retries, 30 s timeout. |
| DHT provide/find | Peer ID appears in provider list. | 5 retries, 120 s timeout. |
| IPNS | Resolved CID matches published record. | 5 retries, 180 s timeout. |
| Helia Bitswap | Same as Kubo Bitswap. | Allowed to fail. |
| Helia CAR | Same as Kubo CAR. | Allowed to fail. |

---

## 5. Detailed Acceptance Criteria

1. Interop CI passes against Kubo for all P0 scenarios before the v2.2 release.
2. Test failures block merging of PRs that modify protocol or service code.
3. Helia jobs exist in CI and report results even if allowed to fail.
4. Every scenario asserts the exact bytes match between implementations, not just CID equality.
5. Logs and packet captures are retained as CI artifacts on failure.
6. Kubo version is pinned in `test/interop/.kubo-version` and documented in release notes.
7. The Docker Compose network starts both nodes and a health check succeeds before tests run.
8. The Dart test harness provides clear, actionable failure messages per scenario.
9. A pinned version of Kubo is used; Renovate or Dependabot tracks updates.
10. IPNS tests publish and resolve in both directions and verify the returned CID.

---

## 6. Security Considerations

- The interop network must be isolated in CI. Use a dedicated Docker Compose network; do not expose host ports unnecessarily.
- Do not use production keys, bootstrap secrets, or real-world data in tests.
- Pin all container images used in the test network (Kubo, Helia, test runners) by digest or semver tag to avoid supply-chain drift.
- Tests must not require privileged containers or host networking.
- Packet captures retained as artifacts must be purged according to repository retention policies and must not contain real user data.
- RPC API endpoints used in tests should be bound to the test network only.

---

## 7. Testing Strategy

### 7.1 Unit Helpers

- `kubo_client.dart` and `dart_ipfs_client.dart` provide typed wrappers for common `/api/v0/*` endpoints used in tests.
- `cid_matcher.dart` provides deterministic comparison helpers that ignore encoding differences (e.g., CIDv0 vs CIDv1 with the same multihash).
- `setup.dart` waits for both peers to be ready, checks peer IDs, and bootstraps mutual connectivity.

### 7.2 Scenario Tests

- **CAR exchange:** Add content to both nodes, export CARs, compare roots and block payloads, then import across implementations and verify retrieval.
- **Bitswap:** Add content to one node, request from the other, assert byte-exact payload. Run both directions.
- **Gateway:** Add content to the dart_ipfs gateway, request via HTTP, assert correct body, `Content-Type`, and trustless `?format=raw` / `?format=car` responses.
- **DHT:** Provide a CID from one node, find providers from the other. Assert the provider list contains the expected PeerID. Reverse direction.
- **IPNS:** Publish a signed IPNS record from one node, resolve from the other. Assert the resolved CID matches the published value. Reverse direction.

### 7.3 CI Pipeline

- `.github/workflows/interop.yml` runs:
  - Docker Compose network up and health checks.
  - Kubo P0 test suite (release-blocking).
  - Helia P1 test suite (non-blocking, report only).
- On failure, upload container logs and packet captures as artifacts.
- Nightly runs detect drift against the pinned Kubo version.

### 7.4 Release Gating

- All P0 interop scenarios must pass before a release tag is pushed.
- The pinned Kubo version must be documented in `CHANGELOG.md` and release notes.
- Docker images used in interop tests must be signed and published before release (see `DOCKER_SPEC.md`).

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - CLI binary (`bin/ipfs.dart`) from `CLI_SPEC.md` to operate the dart_ipfs node in the network.
  - Docker image from `DOCKER_SPEC.md` to run the dart_ipfs node in the Compose network.
  - Stable protocol implementations: Bitswap, DHT, gateway, IPNS, and CAR handling.
- **Order:** Interop tests are a P0 foundation item started in the alpha phase, alongside the CLI and Docker work. They stabilize in the beta phase as protocol discrepancies are fixed.
- **Downstream consumers:**
  - Release gating criteria (see `OPERATIONS_ECOSYSTEM_SPEC` section 9).
  - Future v3.0 work to add Helia and other implementations as first-class peers.

---

## 9. Backward Compatibility Notes

- Interop tests are additive and do not change the public API.
- Pinned Kubo versions may change between v2.2.x patch releases; test matrix updates should be documented in `CHANGELOG.md`.
- The test harness itself is not a published package; internal helper APIs may evolve without a compatibility promise.
- As the test suite matures, Helia jobs may be promoted from `continue-on-error` to release-blocking in a future release.
