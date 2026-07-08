# dart_ipfs v2.2 Operations, Modularity & Ecosystem Specification

**Document ID:** `OPERATIONS_ECOSYSTEM_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Repository:** `C:\Users\josee\IPFS`  
**Approved by:** Ciel Council of Five (2026-06-25)  
**Status:** Draft specification for implementation  

---

## 1. Overview / Goal

The v2.2 Operations, Modularity & Ecosystem backlog transforms `dart_ipfs` from a library-only package into a runnable, deployable, and interoperable IPFS node. The goal is to deliver:

1. A first-class **CLI / daemon binary** (`bin/ipfs.dart`) that can be used directly, shipped in a container, and orchestrated in Kubernetes.
2. **Production-grade Docker & Kubernetes artifacts** with multi-arch image support, automated CI builds, and supply-chain hardening.
3. A **cross-implementation interoperability test suite** that verifies dart_ipfs against Kubo (and later Helia) for CAR exchange, Bitswap, gateway retrieval, DHT provide/find, and IPNS resolution.
4. A **stable monorepo core** (`dart_ipfs_core`) extracted into `packages/` while preserving umbrella re-exports for backward compatibility.
5. A **hardened plugin API** with capability manifests, lifecycle hooks, and signed in-repo examples, without opening a public registry until v3.0.
6. Cleanly **deferred or modified** items (WASM production node, FUSE mount, separate productized WebUI) so they do not block v2.2 while remaining on the roadmap.

This specification is the single source of truth for scope, acceptance criteria, implementation order, testing, security, and migration.

---

## 2. References & Standards

### 2.1 Docker & Kubernetes Best Practices

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) (multi-stage, minimal final image, non-root user, pinned base tags).
- [OCI Image Specification](https://github.com/opencontainers/image-spec) for labels, annotations, and multi-platform manifests.
- [Docker Content Trust / Notary](https://docs.docker.com/engine/security/trust/) and [cosign](https://github.com/sigstore/cosign) for image signing.
- [Kubernetes Basics](https://kubernetes.io/docs/concepts/) and [Helm Best Practices](https://helm.sh/docs/chart_best_practices/).
- [Distroless / Chainguard Images](https://github.com/GoogleContainerTools/distroless) as the preferred hardening target for runtime images.
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) and [NSA/CISA Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF).
- [OpenSSF Scorecard](https://github.com/ossf/scorecard) criteria for dependency pinning, SLSA provenance, and token least-privilege.

### 2.2 Dart Package Conventions

- [Dart Package Layout Conventions](https://dart.dev/tools/pub/package-layout) (especially `bin/`, `lib/`, `example/`, and `packages/` for monorepos).
- [Dart Command-Line Tool Conventions](https://dart.dev/tutorials/server/cmdline) and `package:args` for CLI parsing.
- [pubspec.yaml](https://dart.dev/tools/pub/pubspec) dependency management, `publish_to`, and workspace support (`pubspec_overrides.yaml` or `melos`).
- [Effective Dart](https://dart.dev/effective-dart) for style and API design.
- [pub.dev publishing](https://dart.dev/tools/pub/publishing) and version constraints for backward compatibility.

### 2.3 Kubo CLI Conventions

- [Kubo command-line reference](https://docs.ipfs.tech/reference/kubo/cli/) for command names, flags, and exit codes.
- [IPFS HTTP API spec](https://docs.ipfs.tech/reference/kubo/rpc/) for `/api/v0/*` endpoints.
- [IPFS Gateway Specs](https://specs.ipfs.tech/http-gateways/) for path, subdomain, and trustless gateway behavior.
- [IPNS spec](https://specs.ipfs.tech/ipns/ipns-record/) for record format, signatures, and resolution.
- [Bitswap spec](https://specs.ipfs.tech/bitswap/) and [libp2p specs](https://docs.libp2p.io/) for interoperability targets.
- [CAR format](https://ipld.io/specs/transport/car/) for import/export and trustless responses.

### 2.4 Internal References

- `pubspec.yaml` (repository root) — current package metadata and dependencies.
- `Dockerfile` / `docker-compose.yml` (repository root) — existing container definitions.
- `lib/src/core/ipfs_node.dart` and `lib/src/services/*` — services the CLI must wrap.
- `example/ipfs_dashboard/` and `web/` — reference WebUI candidates.
- `ROADMAP.md` and `CHANGELOG.md` — release planning.

---

## 3. Current-State Gaps in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| **CLI binary** | No `bin/ipfs.dart`; users must embed the library directly. | No standalone daemon, ad-hoc block tools, or Kubo-compatible UX. |
| **Docker** | `Dockerfile` and `docker-compose.yml` exist but the image tag is stale and no CI build/publish exists. | Cannot reliably pull `latest` or `v2.x` images; no multi-arch; no provenance/signing. |
| **Kubernetes** | No manifests or Helm chart. | Cannot deploy to clusters declaratively. |
| **Interoperability tests** | No automated CI tests against other IPFS implementations. | Risk of drifting from Kubo/Helia wire behavior (Bitswap, CAR, DHT, IPNS). |
| **Monorepo** | Single umbrella package `lib/`. | Core primitives cannot be consumed without pulling the full protocol/service stack. |
| **Plugins** | Plugin API is not hardened or documented. | No capability model, no signing, no lifecycle guarantees, no examples. |
| **WASM** | Web code exists but is not validated as wasm-clean. | No production WASM build; unknown web compatibility. |
| **FUSE** | No implementation. | Missing local filesystem mount. |
| **WebUI** | `example/ipfs_dashboard` and `web/` exist but are not promoted as maintained reference UIs. | No CI web build, no docs, no clear status. |

---

## 4. Detailed Per-Item Specification

All items are tagged with the Council priority and verdict (APPROVED, MODIFIED, DEFERRED). Implementation is **not** allowed to expand scope beyond what is specified here unless a new Council deliberation is held.

---

### 4.1 P0 APPROVED — CLI / Daemon Binary (`bin/ipfs.dart`)

#### 4.1.1 Goal
Provide a Kubo-compatible command-line interface that wraps the existing `IPFSNode`, gateway, RPC, and protocol services. It must be runnable with `dart run bin/ipfs.dart` and compilable to a native executable.

#### 4.1.2 Subcommands & Acceptance Criteria

| Subcommand | Description | Required Flags / Arguments | Exit Codes |
|------------|-------------|---------------------------|------------|
| `daemon` | Start the IPFS node (libp2p, gateway, RPC, DHT, Bitswap). | `--config=<path>`, `--api-addr`, `--gateway-addr`, `--swarm-addr`, `--enable-metrics`, `--enable-pprof` | 0 = clean shutdown, 1 = config error, 2 = bind failure, 130 = SIGINT |
| `add <path>` | Add a file or directory to the local blockstore and return the root CID. | `--recursive`, `--chunker`, `--cid-version`, `--hash`, `--pin`, `--quieter`, `--wrap-with-directory` | 0 = success, 1 = I/O error, 3 = invalid argument |
| `cat <cid>` | Stream a CID (file or raw block) to stdout. | `--output=<path>`, `--offset`, `--length` | 0 = success, 1 = not found, 2 = timeout |
| `ls <cid>` | List directory entries of a CID. | `--resolve-type`, `--size` | 0 = success, 1 = not found / not a directory |
| `pin <subcommand>` | `add`, `rm`, `ls`, `verify`. Pin root CIDs locally. | `--recursive` | 0 = success, 1 = CID missing / not pinned |
| `id` | Print node identity (PeerID, public key, addresses, agent version). | `--format` | 0 = success |
| `swarm <subcommand>` | `peers`, `connect`, `disconnect`, `addrs`, `filters`. | `--listen` (for `addrs`) | 0 = success, 1 = peer not found / connection refused |
| `config <subcommand>` | `show`, `edit`, `get`, `set`, `replace`, `profile`. | `--json`, `--bool` | 0 = success, 1 = invalid key, 2 = I/O error |
| `version` | Print `dart_ipfs` version and supported protocol versions. | `--commit`, `--repo`, `--number`, `--all` | 0 = success |

#### 4.1.3 Non-Goals for v2.2
- Full Kubo flag parity (only the flags listed above are required).
- `ipfs files`, `ipfs name`, `ipfs dht`, `ipfs bitswap`, `ipfs block`, `ipfs object`, `ipfs dag` subcommands may be added as thin wrappers that call existing RPC services, but are **not** required to ship in v2.2.
- Interactive shell / REPL (deferred).

#### 4.1.4 Implementation Notes
- Use `package:args` with a command runner.
- Share code with `/api/v0/*` RPC handlers wherever possible; the CLI is a local client of the in-process node.
- Default repository path: `$IPFS_PATH` or `$HOME/.dart_ipfs` (mirroring Kubo).
- Default configuration file: `config.json` inside the repo path, merging with the existing `Config` model.
- Emit logs to stderr; command output to stdout; JSON output mode supported via `--enc=json` where practical.
- Add a `tool/compile_cli.dart` (optional) that invokes `dart compile exe bin/ipfs.dart -o build/ipfs` for release builds.

#### 4.1.5 Acceptance Criteria
- `dart run bin/ipfs.dart daemon` starts and binds the configured API/gateway ports.
- `dart run bin/ipfs.dart add <file>` returns a parseable CID string.
- `dart run bin/ipfs.dart cat <cid>` streams raw bytes matching the original file.
- `dart run bin/ipfs.dart id` outputs a JSON object containing `ID`, `PublicKey`, `Addresses`, and `AgentVersion`.
- All subcommands exit with documented codes and respect `--help`.
- Docker image is updated to invoke `bin/ipfs.dart` (or its compiled `ipfs` binary) as the entrypoint.

---

### 4.2 P0 APPROVED — Docker & Multi-Arch Images

#### 4.2.1 Goal
Deliver reproducible, hardened, multi-architecture Docker images with automated CI builds, publishing, and provenance.

#### 4.2.2 Image Variants & Tags

| Variant | Tag Pattern | Base | Purpose | Notes |
|---------|-------------|------|---------|-------|
| `runtime` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>` | `gcr.io/distroless/base` or `chainguard/static` | Production daemon | Non-root, no shell, minimal attack surface. |
| `runtime` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-<arch>` | Same as above | Per-arch digest | Used by multi-arch manifest. |
| `builder` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-builder` | `dart:stable-sdk` or pinned `dart:<version>` | CI / build verification | Contains Dart SDK, protoc, build tools. Not for production. |
| `debug` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-debug` | `gcr.io/distroless/base:debug` or `chainguard/bash` | Troubleshooting in production | Includes shell; must not be default. |
| `latest` | `ghcr.io/dart-ipfs/dart-ipfs:latest` | Multi-arch runtime | Rolling pointer to latest release | Updated only on stable releases, not every CI build. |
| `edge` | `ghcr.io/dart-ipfs/dart-ipfs:edge` | Multi-arch runtime | Latest successful `main` build | Mutable; for early adopters. |

#### 4.2.3 Multi-Architecture
- Build for at least `linux/amd64` and `linux/arm64`.
- Use `docker buildx` with a single multi-platform manifest.
- Avoid QEMU-only cross-compilation for Dart native binaries if possible; prefer Dart AOT snapshot + native runtime compilation inside the target arch stage, or use `buildx` with native runners where available.

#### 4.2.4 Supply-Chain Hardening
- Pin all base image digests (`gcr.io/distroless/base@sha256:...`) and track updates via `renovate` or `dependabot`.
- Sign images with `cosign` (keyless or project key) and attach SBOMs (e.g., `syft`/`trivy`).
- Publish SLSA provenance where feasible using `slsa-github-generator`.
- Run `trivy` or `grype` container scans in CI and block releases on CRITICAL/HIGH findings.
- Do not run the container as root; use `USER` directive (e.g., `uid=1000`, `gid=1000`).
- Disable setuid binaries and remove package managers from runtime images.
- Expose only documented ports (`4001/tcp/udp` swarm, `5001` API, `8080` gateway, `8081` metrics if enabled).

#### 4.2.5 Dockerfile Changes
- Fix the stale image tag in the existing `Dockerfile`.
- Use a multi-stage build: `build` → `test` (optional) → `runtime`.
- Copy the compiled CLI binary (or AOT snapshot) into the final stage.
- Set `ENTRYPOINT ["/app/ipfs"]` and `CMD ["daemon"]`.
- Add OCI labels: `org.opencontainers.image.source`, `.version`, `.revision`, `.description`, `.license`.
- `docker-compose.yml` must reference the new image and include health checks (`ipfs id` or `/api/v0/id`).

#### 4.2.6 Acceptance Criteria
- `docker buildx build --platform linux/amd64,linux/arm64 -t dart-ipfs:v2.2.0 .` succeeds.
- Runtime image has no shell and no root user.
- `docker run --rm dart-ipfs:v2.2.0 version` prints the correct version.
- `docker run --rm dart-ipfs:v2.2.0 daemon --api-addr /ip4/0.0.0.0/tcp/5001` starts and responds to `curl http://localhost:5001/api/v0/id`.
- CI publishes to `ghcr.io` on every release and `edge` tag on every `main` merge.
- Images are signed and SBOMs are attached.

---

### 4.3 P1 APPROVED — Kubernetes Manifests & Helm Chart

#### 4.3.1 Goal
Provide declarative Kubernetes deployment artifacts that build on the Docker CI work. Priority is P1: must start **after** Docker CI is complete and images are auto-published.

#### 4.3.2 Artifact Layout (`k8s/`)

```
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml              # default config.json
│   ├── secret.yaml                 # optional keys / bootstrap secrets
│   ├── serviceaccount.yaml
│   ├── rbac.yaml                   # minimal Role/RoleBinding if needed
│   ├── deployment.yaml             # single-node StatefulSet or Deployment
│   ├── service.yaml                # API, gateway, swarm (LoadBalancer/ClusterIP)
│   ├── headless-service.yaml         # for peer discovery
│   └── ingress.yaml                # optional gateway ingress
├── overlays/
│   ├── production/
│   ├── staging/
│   └── minikube/
└── helm/
    ├── dart-ipfs/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   ├── values-production.yaml
    │   └── templates/
    │       ├── _helpers.tpl
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── ingress.yaml
    │       ├── configmap.yaml
    │       ├── secret.yaml
    │       ├── pdb.yaml
    │       ├── hpa.yaml
    │       └── serviceaccount.yaml
    └── README.md
```

#### 4.3.3 Helm Chart Values (Excerpt)

| Value | Default | Description |
|-------|---------|-------------|
| `image.repository` | `ghcr.io/dart-ipfs/dart-ipfs` | Image registry/name. |
| `image.tag` | ` Chart appVersion` | Image tag. |
| `image.pullPolicy` | `IfNotPresent` | Pull policy. |
| `replicaCount` | `1` | dart_ipfs is not yet horizontally clustered; keep 1. |
| `service.api.port` | `5001` | RPC API port. |
| `service.gateway.port` | `8080` | Gateway port. |
| `service.swarm.port` | `4001` | libp2p swarm TCP/UDP. |
| `persistence.enabled` | `true` | PVC for repo path. |
| `persistence.size` | `10Gi` | Initial storage size. |
| `persistence.storageClass` | `""` | Cluster default. |
| `ingress.enabled` | `false` | Optional gateway ingress. |
| `podSecurityContext` | `runAsNonRoot: true`, `fsGroup: 1000` | Security baseline. |
| `securityContext` | `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` | Hardening. |
| `resources` | `{}` | CPU/memory limits. |
| `nodeSelector` | `{}` | Arch-specific node selection (e.g., `kubernetes.io/arch: arm64`). |
| `affinity` | `{}` | Anti-affinity rules. |
| `metrics.enabled` | `false` | Prometheus ServiceMonitor. |

#### 4.3.4 Constraints
- Single-node StatefulSet is acceptable for v2.2; clustering beyond one replica is explicitly **not** required.
- Use a `PersistentVolumeClaim` for the IPFS repo path; avoid `emptyDir` for production overlays.
- Gateway ingress may be path-based or subdomain-based; path-based is required, subdomain-based is optional.
- Do not run privileged containers; FUSE mount is deferred and therefore does not influence the manifest.

#### 4.3.5 Acceptance Criteria
- `kubectl apply -k k8s/overlays/minikube/` deploys a working node.
- `helm install dart-ipfs k8s/helm/dart-ipfs --set image.tag=edge` deploys a working node.
- Helm chart passes `helm lint` and `helm template` in CI.
- Kustomize overlays pass `kustomize build` in CI.
- Pod `readinessProbe` uses `ipfs id` or `/api/v0/id` and succeeds before the pod is marked ready.
- Nodes in different clusters can dial each other via the published swarm port.

---

### 4.4 P0 APPROVED — Interoperability Test Suite

#### 4.4.1 Goal
Add CI jobs that spin up Kubo (and later Helia) nodes and verify wire-level compatibility with dart_ipfs across the highest-risk protocols.

#### 4.4.2 Test Matrix

| Scenario | dart_ipfs Role | Peer(s) | Verdict | Test Steps |
|----------|----------------|---------|---------|------------|
| **CAR exchange** | exporter / importer | Kubo | P0 | 1. Add file to dart_ipfs. 2. Kubo `ipfs dag export` vs. dart_ipfs `api/v0/dag/export`. 3. Compare CID roots and block contents. 4. Import Kubo CAR into dart_ipfs and verify. |
| **Bitswap fetch** | provider / requester | Kubo | P0 | 1. Add file to dart_ipfs. 2. Kubo `ipfs block get <cid>` and `ipfs cat <cid>`. 3. Reverse direction. 4. Assert bytes match. |
| **Gateway retrieval** | gateway / client | Kubo or `curl` | P0 | 1. Add file to dart_ipfs. 2. `curl http://dart-ipfs-gateway:8080/ipfs/<cid>` returns correct bytes and content type. 3. Test `?format=raw` and `?format=car` trustless modes. |
| **DHT provide / find** | provider / finder | Kubo | P0 | 1. dart_ipfs provides a CID. 2. Kubo `ipfs dht findprovs <cid>` lists the dart_ipfs peer. 3. Reverse direction. 4. Timeout < 60 s in CI. |
| **IPNS resolution** | publisher / resolver | Kubo | P0 | 1. dart_ipfs publishes signed IPNS record (`ipfs name publish`) to DHT. 2. Kubo `ipfs name resolve <ipns-key>` returns the CID. 3. Reverse direction. |
| **Helia Bitswap** | requester / provider | Helia (Node.js) | P1+ | Repeat Bitswap scenario with a Helia node. Optional for v2.2 but CI job must be scaffolded. |
| **Helia CAR** | exporter / importer | Helia | P1+ | Repeat CAR scenario with Helia. Optional for v2.2. |

#### 4.4.3 CI Architecture
- Use a dedicated GitHub Actions workflow `.github/workflows/interop.yml` (or equivalent) triggered:
  - On every PR touching `lib/src/protocols/`, `lib/src/services/`, or `bin/`.
  - Nightly against `main`.
- Run a lightweight Docker network in CI:
  - `docker compose -f test/interop/docker-compose.yml up -d` with dart_ipfs, Kubo, and optionally Helia services.
  - Wait for health checks.
  - Execute Dart test suite in `test/interop/`.
- Kubo version must be pinned and tracked via `test/interop/.kubo-version` or `renovate`. Default to a recent stable Kubo release.
- Helia tests run in a separate job matrix entry and are allowed to fail (continue-on-error) until stabilized.

#### 4.4.4 Test Harness
- `test/interop/`
  - `docker-compose.yml` — defines the network.
  - `bin/setup.dart` — waits for peer readiness and bootstraps connectivity.
  - `test/car_test.dart`, `test/bitswap_test.dart`, `test/gateway_test.dart`, `test/dht_test.dart`, `test/ipns_test.dart`.
- Helper package `test/interop/lib/`
  - `kubo_client.dart` — thin RPC client for Kubo `/api/v0/*`.
  - `dart_ipfs_client.dart` — thin RPC client for dart_ipfs `/api/v0/*`.
  - `cid_matcher.dart` — deterministic CID comparison helpers.

#### 4.4.5 Acceptance Criteria
- Interop CI passes against Kubo for all P0 scenarios before v2.2 release.
- Test failures block merging of PRs that modify protocol or service code.
- Helia jobs exist in CI and report results even if allowed to fail.
- Every scenario asserts the exact bytes match between implementations.
- Logs and packet captures are retained as CI artifacts on failure.

---

### 4.5 P1 MODIFIED — Package Modularization (Phase 1)

#### 4.5.1 Goal
Create a `packages/` monorepo scaffold and extract only the **stable** `dart_ipfs_core` layer. Keep protocol and service layers in the umbrella package until v2.1 stabilizes, maintaining backward-compatible re-exports.

#### 4.5.2 Monorepo Layout

```
packages/
├── dart_ipfs_core/
│   ├── lib/
│   │   ├── dart_ipfs_core.dart        # public API barrel
│   │   ├── src/
│   │   │   ├── cid/                   # CID v0/v1, multibase, multicodec
│   │   │   ├── multibase/
│   │   │   ├── multicodec/
│   │   │   ├── multihash/
│   │   │   ├── block/                 # BlockStore interface, in-memory store, fs store
│   │   │   ├── codec/                 # common codecs (dag-cbor, dag-json, raw)
│   │   │   ├── crypto/                # key utilities, hashing helpers
│   │   │   └── data_structures/       # small immutable helpers (not protocol logic)
│   │   ├── pubspec.yaml
│   │   ├── README.md
│   │   ├── analysis_options.yaml
│   │   └── test/                      # unit tests for each module
├── dart_ipfs_core_compat/ (optional)
│   └── README.md explaining umbrella re-exports
├── melos.yaml                         # workspace root (optional, P1)
pubspec.yaml                           # umbrella package (remains the published package)
```

#### 4.5.3 What Moves Into `dart_ipfs_core`

| Module | Move? | Reason |
|--------|-------|--------|
| CID, multibase, multicodec, multihash | Yes | Stable, spec-defined, low churn. |
| `Block`, `BlockStore` interfaces | Yes | Core abstraction needed by plugins and other packages. |
| In-memory and filesystem `BlockStore` implementations | Yes | Stable, self-contained. |
| DAG-CBOR, DAG-JSON, raw codecs | Yes | Spec-defined, stable. |
| Key utilities (`PrivateKey`, `PublicKey`, hashing) | Yes | Needed for IPNS/CID; but not the full protocol stack. |
| Bitswap / DHT / libp2p | **No** | Still stabilizing in v2.1. |
| Gateway / RPC services | **No** | Still stabilizing in v2.1. |
| MFS / Pinning / Reprovider | **No** | Still stabilizing in v2.1. |

#### 4.5.4 Umbrella Re-Exports
The root `lib/dart_ipfs.dart` must continue to export all public APIs that consumers currently use. For moved modules, re-export from `dart_ipfs_core`:

```dart
export 'package:dart_ipfs_core/dart_ipfs_core.dart'
    show CID, Multibase, Multihash, Block, BlockStore, ...;
```

Existing import paths `package:dart_ipfs/src/core/...` are **not** guaranteed to remain stable; only `package:dart_ipfs/dart_ipfs.dart` public exports are part of the backward-compatibility promise. Add a deprecation notice in `CHANGELOG.md` for deep imports.

#### 4.5.5 Dependency Direction
- `dart_ipfs_core` has **no** dependency on the umbrella package.
- Umbrella package depends on `dart_ipfs_core` (path dependency during development; published version constraint after release).
- No other `packages/` entries are created in v2.2 unless explicitly approved by a new Council deliberation.

#### 4.5.6 Acceptance Criteria
- `dart run melos bootstrap` (or `dart pub get` in each package) succeeds.
- `dart test` in `packages/dart_ipfs_core` passes with ≥80% line coverage (per project policy).
- Root `dart test` still passes with all existing tests using the umbrella re-exports.
- `dart pub publish --dry-run` in `packages/dart_ipfs_core` reports no errors.
- README documents the monorepo layout and stability tiers.

---

### 4.6 P1 MODIFIED — Plugin Ecosystem (Phase 1)

#### 4.6.1 Goal
Harden the plugin API with capability manifests, lifecycle hooks, and code signing. Ship 2–3 in-repo example plugins. Defer a public plugin registry to v3.0.

#### 4.6.2 Plugin API Surface

| Concept | Description |
|---------|-------------|
| `PluginCapability` | Declarative set of permissions (e.g., `blockstore.read`, `blockstore.write`, `dht.provide`, `network.dial`, `gateway.register_route`, `metrics.emit`). |
| `PluginManifest` | JSON/YAML file bundled with plugin: `id`, `name`, `version`, `capabilities`, `hooks`, `author`, `signature`, `checksums`. |
| `PluginLifecycle` | Interface with `initialize`, `start`, `stop`, `onConfigChanged`, `onPeerConnected`, `onBlockStored`. |
| `PluginHost` | Runtime service that loads plugins, validates manifests, enforces capability ACLs, and routes lifecycle events. |
| `PluginSandbox` | Execution boundary for untrusted plugins. In v2.2 this is Dart `Isolate`-based with capability gating; true OS sandboxing is deferred. |
| `Signature` | Ed25519 signature over the canonical manifest bytes (including the `archive_sha256` checksum of the plugin code), so the signature covers the plugin package content, not just the manifest. |

#### 4.6.3 Manifest Schema (YAML)

```yaml
plugin:
  id: com.example.bitswap-logger
  name: Bitswap Logger
  version: 1.0.0
  dart_ipfs_version: ">=2.2.0 <2.3.0"
  author: "Dart IPFS Contributors <security@dart-ipfs.invalid>"
  capabilities:
    - network.bitswap.observe
    - metrics.emit
  hooks:
    - on_bitswap_message
    - on_metrics_flush
  entrypoint: plugin/main.dart
  signature:
    algorithm: ed25519
    public_key: base64://...
    signature: base64://...
  checksums:
    archive_sha256: "..."
```

#### 4.6.4 Capability Model
- Capabilities are **deny-by-default**.
- The plugin must request capabilities at load time; any runtime access outside the granted set throws a `CapabilityException` and disables the plugin.
- Host services expose capability-gated adapters (e.g., `CapabilityBlockStore`, `CapabilityMetricsEmitter`) rather than raw service references.
- Audit log: every plugin action that exercises a capability is logged with plugin ID, capability, and outcome.

#### 4.6.5 Signing & Trust
- In-repo example plugins are signed with a repository dev key stored in `tool/plugin_dev_key.pem` (not for production use).
- Production deployments may supply a trusted-keys file via config (`plugin.trustedKeysPath`).
- Unsigned plugins may only be loaded if `plugin.allowUnsigned` is explicitly set to `true` (default: false).

#### 4.6.6 Example Plugins (In-Repo)

| Plugin ID | Purpose | Capabilities |
|-----------|---------|--------------|
| `org.dart-ipfs.examples.bitswap-logger` | Logs all Bitswap wantlist/have messages to a local file. | `network.bitswap.observe`, `metrics.emit` |
| `org.dart-ipfs.examples.pin-policy` | Auto-pins CIDs matching a configured allowlist. | `blockstore.read`, `blockstore.write`, `pin.add` |
| `org.dart-ipfs.examples.gateway-metrics` | Emits gateway request counts/histograms to a custom endpoint. | `gateway.request.observe`, `metrics.emit` |

#### 4.6.7 Non-Goals for v2.2
- Public plugin registry or marketplace.
- Hot-reload of plugins in production (plugins are loaded at startup).
- True OS-level sandboxing (Isolate-only in v2.2).
- Dynamic plugin installation over the network.

#### 4.6.8 Acceptance Criteria
- `PluginHost` loads all three example plugins in CI.
- Removing a capability from a manifest causes the plugin to fail to load.
- Logging plugin records a Bitswap message when two nodes exchange a block.
- Pin-policy plugin successfully pins a CID matching the allowlist.
- Unsigned plugin fails to load unless `allowUnsigned: true`.
- Tampered plugin archive fails signature verification.
- Plugin API is documented in `doc/plugins.md`.

---

### 4.7 P2 DEFERRED — WASM Build

#### 4.7.1 Verdict
- Keep existing web code (`web/`, `example/ipfs_dashboard/`) **wasm-clean**.
- Do **not** ship a production WASM IPFS node in v2.2.
- Revisit full WASM compilation and deployment in v3.0.

#### 4.7.2 v2.2 Constraints
- All code under `lib/src/` must compile without errors when targeted at `dart2wasm` (no unsupported `dart:io` imports in shared paths, no unimplemented `dart:js` interop patterns).
- CI should add a `dart compile wasm` or `flutter build web --wasm` target as a **non-blocking** lint/build job to catch regressions.
- Do not add WASM-specific APIs or production promises.

#### 4.7.3 Acceptance Criteria
- `web/` builds with `flutter build web` without errors.
- WASM-clean CI job exists and reports status but does not block release.

---

### 4.8 P2 DEFERRED — FUSE Mount

#### 4.8.1 Verdict
- No FUSE implementation in v2.2.
- Revisit after CLI, Docker, and interoperability parity are achieved.

#### 4.8.2 v2.2 Constraints
- Do not introduce FUSE dependencies, privileges, or platform-specific code.
- Kubernetes manifests and Docker images must remain non-privileged (no `/dev/fuse` mounts, no `SYS_ADMIN` capability).

---

### 4.9 P2 MODIFIED — Reference WebUI

#### 4.9.1 Verdict
- Promote `example/ipfs_dashboard/` and `web/` as **maintained, optional reference WebUIs**.
- Add web build CI target and documentation.
- Do **not** create a separate productized WebUI in v2.2.

#### 4.9.2 Specification
- Move `example/ipfs_dashboard/` to a maintained status: add `README.md`, `pubspec.yaml` hygiene, and issue tracking.
- Ensure `web/` demo builds with `flutter build web` in CI.
- Add a GitHub Actions job `.github/workflows/web.yml` that builds both dashboards on PRs and `main`.
- Document the WebUI in `doc/webui.md` with:
  - How to run locally.
  - How to connect to a local `dart_ipfs` daemon.
  - Which features are supported (CID search, file upload, peer list, pinning view).
- WebUI must use the public umbrella API only; no deep imports into `lib/src/`.

#### 4.9.3 Acceptance Criteria
- `flutter build web` succeeds for both `example/ipfs_dashboard` and `web/` in CI.
- WebUI connects to `http://127.0.0.1:5001` and displays node identity.
- WebUI can add a file and display the resulting CID.
- Docs are published and reviewed as part of the v2.2 release checklist.

---

## 5. Implementation Sequence

The Council recommends the following order. P0 items must be completed before v2.2 release; P1 items may ship in v2.2 but must not delay release if they are not complete; P2 items are explicitly deferred or kept as non-blocking CI/docs.

### Phase 1 — P0 Foundations (v2.2.0-alpha)
1. **CLI / daemon binary** (`bin/ipfs.dart`) — implement all required subcommands and add `dart compile exe` tooling.
2. **Docker images** — fix stale tag, refactor Dockerfile, add multi-arch build, signing, and SBOMs.
3. **Interoperability test suite** — scaffold Docker Compose network, Kubo client helpers, and P0 test scenarios.

### Phase 2 — P0 Hardening (v2.2.0-beta)
4. Stabilize CLI against interop tests; fix Bitswap, DHT, and gateway discrepancies uncovered by Kubo tests.
5. Container hardening audit (non-root, distroless, vulnerability scan).
6. Add CI publishing for `edge` and release tags.

### Phase 3 — P1 Modularity & Ecosystem (v2.2.0-rc / optional v2.2.x)
7. **Package modularization** — create `packages/dart_ipfs_core` and umbrella re-exports.
8. **Plugin API hardening** — capability model, manifest schema, signing, and three example plugins.
9. **Kubernetes manifests & Helm chart** — add `k8s/` base and Helm chart after Docker CI is stable.

### Phase 4 — P2 Cleanup (non-blocking)
10. **Reference WebUI** — add web build CI and documentation.
11. **WASM cleanliness** — add non-blocking `dart2wasm` CI job and fix regressions.
12. **FUSE mount** — defer to v3.0; ensure no privileged code is added.

---

## 6. Testing Strategy

### 6.1 CI Pipelines

| Pipeline | Trigger | Jobs | Block Release? |
|----------|---------|------|----------------|
| `lint.yml` | PR, main | `dart analyze`, `dart format`, `dart test` (unit) | Yes |
| `interop.yml` | PR (protocol/service changes), nightly | Kubo Bitswap, CAR, gateway, DHT, IPNS | Yes |
| `docker.yml` | PR (Dockerfile changes), release | Multi-arch build, image scan, sign/SBOM, `docker compose` smoke test | Yes |
| `k8s.yml` | PR (k8s/ changes), nightly | `helm lint`, `helm template`, `kustomize build`, minikube smoke test | P1: Yes once merged |
| `web.yml` | PR, main | `flutter build web` for both reference UIs | No (P2, report only) |
| `wasm.yml` | PR, main | `dart compile wasm` or `flutter build web --wasm` lint | No (P2, report only) |

### 6.2 Unit Tests
- Maintain ≥80% line coverage for new code (CLI, core package, plugin host).
- Existing unit tests must continue to pass via the umbrella re-exports after modularization.

### 6.3 Container Tests
- `docker run --rm <image> version` returns expected version.
- `docker compose -f docker-compose.yml up` starts daemon and passes `/api/v0/id` health check.
- Image scan passes with no CRITICAL vulnerabilities and no HIGH vulnerabilities without an approved exception.

### 6.4 Cross-Implementation Interop Tests

| Scenario | Target Peer | Success Criteria | Retry/Timeout Policy |
|----------|-------------|------------------|----------------------|
| CAR export/import | Kubo | Byte-exact CAR; root CID matches. | 3 retries, 60 s timeout. |
| Bitswap | Kubo | Both directions return exact bytes. | 3 retries, 120 s timeout. |
| Gateway | Kubo/`curl` | Correct body, headers, trustless format. | 10 retries, 30 s timeout. |
| DHT provide/find | Kubo | Peer ID appears in provider list. | 5 retries, 120 s timeout. |
| IPNS | Kubo | Resolved CID matches published record. | 5 retries, 180 s timeout. |
| Helia Bitswap | Helia | Same as Kubo Bitswap. | Allowed to fail. |
| Helia CAR | Helia | Same as Kubo CAR. | Allowed to fail. |

### 6.5 Release Gating
- All P0 CI pipelines must pass before a release tag is pushed.
- Interop tests must pass against a pinned Kubo version documented in the release notes.
- Docker images must be signed and published before the GitHub Release is published.

---

## 7. Security Considerations

### 7.1 Container Hardening
- Runtime image must be non-root, read-only root filesystem, minimal capability set, and no shell.
- Pin base image digests; scan with `trivy`/`grype` in CI.
- Sign images with `cosign` and publish SBOMs.
- Do not embed secrets or private keys in images; use runtime-mounted secrets or environment variables for sensitive config.
- Expose only the documented ports (4001 swarm, 5001 API, 8080 gateway, 8081 metrics).
- Bind API to localhost by default; require explicit config to bind to `0.0.0.0`.

### 7.2 Plugin Sandboxing
- Plugins run in Dart `Isolate`s with no shared mutable state with the host.
- Capability model is deny-by-default; host services never expose raw references.
- Unsigned plugins fail to load unless `allowUnsigned: true` is set.
- Signed plugins must verify the manifest signature against a trusted key list.
- Plugin audit logs are written to the configured log destination.
- In v2.2, plugins cannot escalate to OS-level operations; FUSE and raw socket access are blocked.

### 7.3 CLI Authentication Defaults
- RPC API (`/api/v0`) listens on `127.0.0.1:5001` by default; no authentication token is required for localhost in v2.2.
- Remote API binding requires explicit `--api-addr /ip4/0.0.0.0/tcp/5001` and emits a warning.
- Gateway on `8080` is read-only by default; writable gateway modes must be explicitly enabled via config.
- Admin/config subcommands (`config replace`, `config edit`, `id` private key export) require the local CLI context and cannot be invoked via the HTTP API unless separately authorized in a future release.
- CORS defaults must be restrictive; `Access-Control-Allow-Origin: *` is only enabled when explicitly configured.

### 7.4 Supply Chain
- Pin all CI action versions by SHA.
- Use OIDC / short-lived tokens for registry publishing where possible.
- Publish SLSA provenance for release images.
- Maintain a `SECURITY.md` with vulnerability reporting process.

### 7.5 Kubernetes Security
- Use `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`.
- No privileged containers, no host networking, no `hostPath` volumes unless in an explicit debug overlay.
- NetworkPolicy should restrict ingress to API/gateway ports only; swarm port may be exposed via Service.
- Secrets for bootstrap keys or RPC auth (if any) stored in Kubernetes Secrets, not ConfigMaps.

---

## 8. Backward Compatibility & Migration Notes

### 8.1 Public API Contract
- `package:dart_ipfs/dart_ipfs.dart` remains the stable public API.
- Deep imports (`package:dart_ipfs/src/...`) are **not** part of the compatibility contract and may break during v2.2. Add a `CHANGELOG.md` warning.
- After extracting `dart_ipfs_core`, the same classes (CID, Multibase, etc.) remain available via the umbrella re-export.

### 8.2 CLI Migration
- New CLI is additive; no existing library usage is broken.
- Library users who previously embedded `IPFSNode` directly are encouraged but not required to migrate to `bin/ipfs.dart`.
- Config file format stays compatible; CLI `--config` accepts the same JSON config model.

### 8.3 Docker Migration
- Existing `docker-compose.yml` users must update to the new image tag (`ghcr.io/dart-ipfs/dart-ipfs:<version>`).
- The old `Dockerfile` image tag is deprecated; update to the pinned multi-arch image.
- Volume paths remain compatible: `/data/ipfs` or configurable via `IPFS_PATH`.

### 8.4 Plugin Migration
- Pre-v2.2 plugin loading (if any existed) is replaced by the new manifest/capability model.
- Old plugin packages must add a `plugin.yaml` manifest and request explicit capabilities.
- Example plugins serve as migration templates.

### 8.5 Deprecation Timeline
| Item | Deprecated In | Removed In |
|------|---------------|------------|
| Deep `lib/src/` imports | v2.2.0 | v3.0.0 |
| Old Docker image tag | v2.2.0 | v2.3.0 |
| Unsigned plugin loading (default) | v2.2.0 | v3.0.0 (require signing) |
| Single-package monorepo | v2.2.0 | v3.0.0 (full package split) |

---

## 9. Acceptance Summary

v2.2 is considered complete when:

1. `bin/ipfs.dart` ships with all required subcommands and passes CLI tests.
2. Multi-arch Docker images are built, signed, scanned, and published automatically.
3. Interoperability tests against Kubo pass for CAR, Bitswap, gateway, DHT, and IPNS.
4. `packages/dart_ipfs_core` is extracted, tested, and umbrella re-exports preserve backward compatibility.
5. Plugin API supports capability manifests, signing, and the three in-repo examples.
6. Kubernetes base manifests and Helm chart exist and pass lint/template/CI.
7. Reference WebUI is documented and builds in CI.
8. WASM and FUSE are cleanly deferred with no production promises or privileged code.
9. Security hardening criteria are met and documented.
10. `CHANGELOG.md` and `ROADMAP.md` are updated to reflect the v2.2 scope and v3.0 deferred items.

---

*End of specification.*
