# Engineering Notes — dart_ipfs

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
Run the full suite. As of 2026-07-09: 3478 passed, 8 skipped. The skipped tests are Docker-dependent interop scenarios that run with `dart test --preset interop` inside `test/interop/docker-compose`; all host unit tests now pass. The CLI test group uses a `cli` tag with `timeout: 2x` to stay stable under coverage instrumentation.

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

**Release gate (since 1.16.0):** after implementation and before publishing or tagging, new and changed code must be at ~100% line coverage. Scope the check to the diff: run `dart test --coverage=coverage` over the affected test trees, then compute per-file coverage for the files changed in the release. Close any gaps with focused tests before tagging; do not publish with uncovered new lines.

**Merging coverage from multiple runs:** `format_coverage` emits one `SF` record per VM JSON input rather than combining hits — concatenating JSON files and re-formatting produces duplicate source-file records that the changed-line gate reads as uncovered. Worse, a targeted run emits `DA:<line>,0` rows for lines the full suite never instrumented (lazy compilation differences — e.g. class declaration lines), so naive per-line `max()` merging manufactures false uncovered lines. Correct merge: the full suite's `DA` row set is authoritative — for each `SF`, keep the base rows and apply `hits = max(base, delta)`; add delta rows only when `hits > 0` (a positive hit proves the line coverable); drop delta-only zero-hit rows. See `tool/changed_line_coverage.dart` consumers before rerunning partial coverage.

**Release sign-off:** tagging/publishing requires a maintainer review sign-off on the release diff — correctness, coverage, security-sensitive surface (key material handling, auth, transport changes), and changelog accuracy. Record the sign-off in the PR or release notes before tagging. Checklist addition: verify new test files are actually tracked (`git check-ignore -v <file>` must return nothing) — an unanchored gitignore pattern once excluded test sources.

### Release surfaces

`version` in `pubspec.yaml` is the single source of truth. `tool/release_surfaces.dart` manages every version-bearing file — after bumping pubspec run `make release-sync`, and gate releases with `make release-check` (also runs as the `release-gate` job in `publish.yml`, including tag-vs-pubspec verification for `v*`, `core-v*`, and `quic-v*` tags).

Automated surfaces (do not hand-edit versions in these):

- `lib/src/version.dart` (`packageVersion`; `agentVersion` derives from it and feeds the CLI, RPC `/api/v0/version`, gateway `Version`, identify, libp2p user agent, and health check — never hardcode `dart_ipfs/x.y.z` literals, the gate rejects them)
- `docker-compose.yml`, `docker-compose.debug.yml` (image tags)
- `helm/dart-ipfs/Chart.yaml` (`appVersion`), `helm/dart-ipfs/README.md`
- `k8s/base/deployment.yaml`, `k8s/base/kustomization.yaml`, `k8s/overlays/production/kustomization.yaml`
- `README.md` (install snippet + "(current: vX.Y.Z)" marker), `ROADMAP.md` (current version fields)
- `CHANGELOG.md` must contain a `## [X.Y.Z]` section for the release version (presence is gated; content is authored)

Still manual on each publish: the CHANGELOG entry itself, README "What's New" narrative, ROADMAP prose, the git tag, the coverage gate above, and maintainer sign-off. Pushing a `v*` tag publishes to pub.dev and creates the GitHub Release with notes extracted from the tag's CHANGELOG section (`github-release` job in `publish.yml`); `core-v*`/`quic-v*` tags publish only their package, no release. Sub-packages (`dart_ipfs_core`, `dart_ipfs_quic`) are versioned independently — their tags only gate their own `pubspec.yaml` + `CHANGELOG.md`.

## Work-Package Boundaries

When planning recovery or implementation work, scope each effort to one work-package and forbid broad import sweeps:

- WP-08 — spec compliance (gateway content/directory/trustless handlers, UnixFS HAMT sharding, DHT rate limiter, pubsub gossipsub stubs). **Completed 2026-07-09**, with small remaining gaps: HAMT shard root recursive listing and explicit trustless response handler paths.
- WP-09 — competitor parity (IPNI client, Reframe routing client, circuit relay HOP/STOP client). **Completed 2026-07-09**.
- WP-06 — autonat + DCUtR + peering lifecycle integration. **Completed 2026-07-09**.
- WP-07 — core modularization redesign. **Abandoned by the maintainers (2026-07-09)** in favor of an adoption-first strategy (docs, examples, community outreach, lightweight HTTP API wrapper). Do not perform raw import replacement. Revisit modularization only when dart_ipfs has at least five pub.dev dependents or a concrete use case for protocol-agnostic core primitives emerges. If revisited, the original WP-07 design is not viable: any `dart_ipfs_core` must be protobuf-free, and `CID.fromProto`/`toProto` must remain in protocol-specific or umbrella packages.

## Known Traps

- Do not replace local `lib/src/core/cid.dart` imports with `package:dart_ipfs_core/dart_ipfs_core.dart`. The umbrella CID has `fromProto`/`toProto`/`computeForData`/`hashType`/`version` that the core package lacks. This is a known architectural inconsistency: the CID spec and reference implementations (go-cid, js-multiformats, rust-cid) keep protobuf serialization out of core. If modularization is ever revisited, protobuf methods must stay in protocol/umbrella packages, not move into `dart_ipfs_core`.
- Test files must use `package:dart_ipfs/src/...` imports, not relative `../../../lib/src/...` imports, to avoid library URI mismatches.
- Restoring files with `git show HEAD:path > file` on Windows can corrupt them to UTF-16; use `git checkout HEAD -- <path>` instead.
- Full `dart test` runs can exhaust local resources: with a low `ulimit -n` (e.g. 1024) expect `errno = 24` failures (`Too many open files`, `Failed to start /bin/sh`) mid-suite, and on a small `/tmp` tmpfs expect `errno = 28` (`No space left on device`) during kernel compilation. Run with `ulimit -n 65536` and `TMPDIR=<dir on disk>`; CI runners are unaffected.
- IPNS V2 signatures are computed over `ipns-signature:` + the raw DAG-CBOR `data` bytes (Kubo/boxo v0.40+). When verifying a decoded record, use the original serialized `data` bytes because CBOR key ordering/integer encoding must match exactly. The verifier should accept both prefixed and raw V2 signatures for interop with different record producers.
