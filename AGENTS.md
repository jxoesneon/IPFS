# Agent Notes — dart_ipfs

## Local Verification Commands

### Analysis
```bash
dart analyze
```
Target: 0 errors. Warnings/infos are tolerated only if pre-existing and outside the current work-package scope.

### Unit Tests
```bash
dart test --reporter=compact
```
Spin-up the full suite. As of 2026-07-09: 3478 passed, 8 skipped. The skipped tests are Docker-dependent interop scenarios that run with `dart test --preset interop` inside `test/interop/docker-compose`; all host unit tests now pass. The CLI test group uses a `cli` tag with `timeout: 2x` to stay stable under coverage instrumentation.

### Interop Tests
```bash
cd test/interop
docker compose up -d --build
docker compose exec -T test-runner sh -c "cd /app && dart test --preset interop test/interop"
```
As of 2026-07-09: all interop tests pass (Bitswap, CAR exchange, DHT provide/find, IPNS, Helia CAR exchange with Kubo/Helia).

### Coverage
```bash
dart test --coverage=coverage
 dart pub global activate coverage
 dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
```
Then compute the percentage from `coverage/lcov.info`:
```bash
# Sum all LF: (lines found) and LH: (lines hit) records
awk '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END {printf "%.2f%%\n", lh/lf*100}' coverage/lcov.info
```
Target: 80% line coverage. As of 2026-07-09: 85.79% achieved.

## Subagent Work-Package Boundaries

When launching recovery/implementation subagents, scope them to one WP and forbid broad import sweeps:

- WP-08 — spec compliance (gateway content/directory/trustless handlers, UnixFS HAMT sharding, DHT rate limiter, pubsub gossipsub stubs). **Completed 2026-07-09**, with small remaining gaps: HAMT shard root recursive listing and explicit trustless response handler paths.
- WP-09 — competitor parity (IPNI client, Reframe routing client, circuit relay HOP/STOP client). **Completed 2026-07-09**.
- WP-06 — autonat + DCUtR + peering lifecycle integration. **Completed 2026-07-09**.
- WP-07 — core modularization redesign. **Abandoned by Council of Five final decision (2026-07-09)**. The project follows an adoption-first strategy (docs, examples, community outreach, lightweight HTTP API wrapper). Do not perform raw import replacement. Revisit modularization only when dart_ipfs has ≥5 pub.dev dependents or a concrete use case for protocol-agnostic core primitives emerges. If revisited, the original WP-07 design is discredited: any `dart_ipfs_core` must be protobuf-free, and `CID.fromProto`/`toProto` must remain in protocol-specific or umbrella packages.

## Known Traps

- Do not replace local `lib/src/core/cid.dart` imports with `package:dart_ipfs_core/dart_ipfs_core.dart`. The umbrella CID has `fromProto`/`toProto`/`computeForData`/`hashType`/`version` that the core package lacks. This is an acknowledged architectural inconsistency: the CID spec and reference implementations (go-cid, js-multiformats, rust-cid) keep protobuf serialization out of core. If modularization is ever revisited, protobuf methods must stay in protocol/umbrella packages, not move into `dart_ipfs_core`.
- Test files must use `package:dart_ipfs/src/...` imports, not relative `../../../lib/src/...` imports, to avoid library URI mismatches.
- Restoring files with `git show HEAD:path > file` on Windows can corrupt them to UTF-16; use `git checkout HEAD -- <path>` instead.
- IPNS V2 signatures are computed over `ipns-signature:` + the raw DAG-CBOR `data` bytes (Kubo/boxo v0.40+). When verifying a decoded record, use the original serialized `data` bytes because CBOR key ordering/integer encoding must match exactly. The verifier should accept both prefixed and raw V2 signatures for interop with different record producers.
