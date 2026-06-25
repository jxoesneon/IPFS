# Ciel Council of Five Audit Report: Operations & Ecosystem Specs

**Audit Scope:** Per-feature specifications in `C:\Users\josee\IPFS\doc\specs\features\` for the `dart_ipfs` v2.2 release window.

**Specs Audited:**
1. `CLI_SPEC.md`
2. `DOCKER_SPEC.md`
3. `KUBERNETES_SPEC.md`
4. `INTEROP_TESTS_SPEC.md`
5. `MODULARIZATION_SPEC.md`
6. `PLUGINS_SPEC.md`

**Architecture Baseline:** `dart_ipfs` v1.11.5 (`pubspec.yaml`, line 2); inspected source files include `lib/src/core/ipfs_node/ipfs_node.dart`, `lib/src/core/builders/ipfs_node_builder.dart`, `lib/src/core/config/ipfs_config.dart`, `lib/src/services/rpc/rpc_handlers.dart`, `lib/src/services/rpc/rpc_server.dart`, `lib/src/services/gateway/gateway_server.dart`, `lib/src/core/plugins/ipfs_plugin.dart`, `Dockerfile`, and `docker-compose.yml`.

**Council Lenses:**
- **Coherence:** Fit with existing `dart_ipfs` architecture and code paths.
- **Capability:** Genuine, non-redundant capability expansion.
- **Safety:** Risks, attack vectors, and veto-worthy issues.
- **Efficiency:** Lean, focused, performant vs. bloated.
- **Evolution:** Advancement toward Kubo/Helia parity and superiority.

---

## Executive Summary

| Spec | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|------|-----------|------------|--------|------------|-----------|---------|
| CLI_SPEC.md | 7 | 8 | 7 | 7 | 8 | **PASS** |
| DOCKER_SPEC.md | 7 | 8 | 8 | 7 | 8 | **PASS** |
| KUBERNETES_SPEC.md | 7 | 7 | 8 | 7 | 7 | **PASS** |
| INTEROP_TESTS_SPEC.md | 6 | 9 | 6 | 6 | 9 | **CONDITIONAL** |
| MODULARIZATION_SPEC.md | 7 | 6 | 8 | 6 | 7 | **CONDITIONAL** |
| PLUGINS_SPEC.md | 6 | 7 | 6 | 6 | 7 | **CONDITIONAL** |

**Overall Council Stance:** All six specs are directionally correct and align with the previously approved v2.2 backlog. Three foundational specs (CLI, Docker, Kubernetes) are ready to enter implementation with minor amendments. Three advanced specs (Interop, Modularization, Plugins) require scope tightening or sequencing adjustments before they can be treated as release-blocking. No spec is rejected outright; none has a Safety score at or below the veto threshold of 3.

---

## 1. CLI_SPEC.md

### Scores
- **Coherence:** 7/10
- **Capability:** 8/10
- **Safety:** 7/10
- **Efficiency:** 7/10
- **Evolution:** 8/10

### Overall Verdict: PASS

### Summary of Strengths
- The spec correctly identifies the missing executable surface: there is no `bin/ipfs.dart` today, and `example/cli_dashboard/bin/main.dart` is an example dashboard, not a daemon binary.
- It leverages existing RPC handlers (`lib/src/services/rpc/rpc_handlers.dart`) and the gateway server (`lib/src/services/gateway/gateway_server.dart`) rather than duplicating protocol logic.
- Subcommand set is appropriately scoped for a v2.2 MVP: daemon, add, cat, ls, pin, id, swarm, config, and version.
- Security defaults are sound: localhost-by-default API binding, explicit warning for remote binding, read-only gateway default, restrictive CORS, and no key leakage to stdout.
- Acceptance criteria are concrete and verifiable (e.g., `dart compile exe`, `curl /api/v0/id`, return codes).

### Summary of Weaknesses
- The spec assumes that `IPFSNode.start()` automatically starts the RPC server and gateway server. In the current architecture, `IPFSNodeBuilder` registers `LifecycleManager` at `lib/src/core/builders/ipfs_node_builder.dart:135-136` but does not register `RPCServer` or `GatewayServer` with it. The CLI `daemon` command will need to instantiate and manage these servers explicitly, or the lifecycle wiring must be added first.
- `IPFSConfig.fromFile` at `lib/src/core/config/ipfs_config.dart:287-297` reads YAML, not JSON, and `IPFSConfig.toJson()` at lines 300-322 omits the `gateway`, `metrics`, `keystore`, and `customConfig` fields. The CLI `config show` and `config replace` acceptance criteria will produce incomplete JSON unless the config model is completed.
- No RPC handlers exist for `pin ls`, `pin rm`, `pin verify`, `config get/set/replace`, or `swarm addrs/filters`. The spec lists these as subcommands but does not map them to existing library APIs, which means they require new implementation before the CLI can pass acceptance.
- The `config profile` subcommand is referenced without a defined profile taxonomy or list.
- The spec does not address the existing `example/cli_dashboard/bin/main.dart` binary or explain whether it should be removed, renamed, or ignored to avoid user confusion.

### Specific Recommendations
1. Add an explicit prerequisite to register `RPCServer` and `GatewayServer` with `LifecycleManager` in `IPFSNodeBuilder`, or document that `daemon` will start them outside the lifecycle manager.
2. Extend `IPFSConfig.toJson()` to include `gateway`, `metrics`, and `customConfig` so that `config show` and `config replace` are complete and reversible.
3. Split `config` into two phases: `show`, `get`, and `set` for v2.2; defer `edit`, `replace`, and `profile` until the config model and versioning story are hardened.
4. Define the `version` string source: derive it from `pubspec.yaml` (currently `1.11.5` at line 2) via code generation or a build-time constant, rather than hard-coding `dart_ipfs/0.1.0` as seen in `lib/src/services/rpc/rpc_handlers.dart:31` and `lib/src/services/gateway/gateway_server.dart:100`.
5. Add `package:args` to `pubspec.yaml` dependencies and document the choice between `CommandRunner` and a custom parser.
6. Clarify the fate of `example/cli_dashboard/bin/main.dart` to prevent a second, competing entry point.

### Missing Research References and Acceptance Criteria
- Reference needed: Dart AOT compilation constraints on Windows, macOS, and Linux (e.g., `dart compile exe` behavior with native library dependencies such as `libsodium` via `sodium`).
- Reference needed: Kubo exit code conventions (`https://docs.ipfs.tech/reference/kubo/cli/#exit-status`) for subcommands like `add` and `cat`.
- Missing acceptance criterion: CLI must generate a default `config.yaml` (or `config.json`) on first run and verify that `IPFSConfig.fromFile` can load it.
- Missing acceptance criterion: `daemon` must validate that `--api-addr`, `--gateway-addr`, and `--swarm-addr` are syntactically valid multiaddrs before binding.
- Missing acceptance criterion: `add --recursive` and `--wrap-with-directory` must be tested against `ContentManager.addDirectory` and directory parsing at `lib/src/core/ipfs_node/content_manager.dart`.

---

## 2. DOCKER_SPEC.md

### Scores
- **Coherence:** 7/10
- **Capability:** 8/10
- **Safety:** 8/10
- **Efficiency:** 7/10
- **Evolution:** 8/10

### Overall Verdict: PASS

### Summary of Strengths
- The current `Dockerfile` at the repository root is stale and insecure: it builds `example/full_node_example.dart` instead of a CLI binary, it uses a `scratch` stage and then overwrites it with `debian:bookworm-slim`, and the image tag is `1.2.4-secure` while the package is `1.11.5`. The spec correctly identifies the need for a multi-stage, hardened image.
- Multi-architecture support (`linux/amd64` and `linux/arm64`) is essential for production adoption and is well-specified.
- Supply-chain controls are comprehensive: digest pinning, cosign signing, SBOMs, SLSA provenance, and vulnerability scanning with CRITICAL/HIGH gating.
- Runtime hardening is strong: non-root user (`uid=1000`), read-only root filesystem, minimal capabilities, no shell, and documented port exposure.
- The debug and builder variants are properly scoped and labeled as non-production.

### Summary of Weaknesses
- The spec proposes `gcr.io/distroless/base` or `cgr.dev/chainguard/static` for the runtime image, but the current `dart_ipfs` dependency tree includes `sodium: ^4.0.2+1` which wraps `libsodium` and requires glibc at runtime. A static or `distroless/static` image will fail unless `libsodium` is statically linked or a `distroless/cc`/`debian-slim` base is used. The spec does not address this dependency.
- The existing `docker-compose.yml` introduces an `nginx` reverse proxy with host port binding. The spec does not reconcile the new image with the nginx service or explain whether the proxy remains in v2.2.
- The runtime image size target (`< 50 MB` excluding the binary) is optimistic for a Dart AOT executable that includes `libsodium`, `hive`, and protocol buffers. The acceptance criteria should specify an upper bound rather than a strict target, or require static linking first.
- The `edge` tag is mutable and could be pulled by automated CI; the spec does not require a digest verification step for consumers, which weakens the supply-chain story it otherwise builds.
- QEMU-only cross-compilation is mentioned as undesirable, but no fallback plan is given if native ARM64 runners are unavailable in the free GitHub Actions tier.

### Specific Recommendations
1. Replace `distroless/base` or `chainguard/static` with `distroless/cc` or `chainguard/glibc` until all native dependencies can be statically linked, or document the static-linking work as a prerequisite.
2. Add a dedicated section on `docker-compose.yml` reconciliation: either keep nginx as an optional production overlay with mTLS, or remove it from the default developer compose and bind gateway/API directly to localhost.
3. Change the image size acceptance criterion from `< 50 MB` to a staged target (e.g., `< 80 MB` for v2.2, `< 50 MB` after static linking) and measure the compressed image, not the uncompressed layer size.
4. Require that `docker-compose.yml` and Helm values reference the image by digest in production examples, not by mutable `latest` or `edge` tags.
5. Add a `docker` build smoke test to the existing `.github/workflows/test.yml` or the new `.github/workflows/docker.yml` before any publishing step.
6. Document how the `tool/compile_cli.dart` script will handle the `libsodium` dynamic library path on different base images.

### Missing Research References and Acceptance Criteria
- Reference needed: `dart_ipfs` native dependency audit (which packages load `.so`/`.dll`/`.dylib` files and how they map to container base images).
- Reference needed: Chainguard `glibc` or `cc` image documentation for Dart AOT binaries with native dependencies.
- Missing acceptance criterion: `docker run --rm <image> id` must print `uid=1000` (or `uid=10001` if aligned with the existing compose user) and must not have a writable root filesystem.
- Missing acceptance criterion: The runtime image must not contain a shell, `apt`, `curl`, or `setuid` binaries; verify with `docker run --rm <image> sh` failing.
- Missing acceptance criterion: `docker build` must fail if `trivy` or `grype` reports a CRITICAL vulnerability in any stage, including the builder stage.
- Missing acceptance criterion: Cosign signature must be verifiable by a third party using only the public key or OIDC issuer (keyless) documented in the release notes.

---

## 3. KUBERNETES_SPEC.md

### Scores
- **Coherence:** 7/10
- **Capability:** 7/10
- **Safety:** 8/10
- **Efficiency:** 7/10
- **Evolution:** 7/10

### Overall Verdict: PASS

### Summary of Strengths
- The spec builds cleanly on the Docker and CLI specs: image is `ghcr.io/dart-ipfs/dart-ipfs:<tag>`, container command is `ipfs daemon`, and persistent storage is provided by a PVC.
- `StatefulSet` is the correct controller choice for a single-node, stateful IPFS daemon.
- Security defaults are strong: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `fsGroup: 1000`, `drop: ["ALL"]`, and no `hostPath`/`hostNetwork` in production overlays.
- Secrets are separated from ConfigMaps, and the spec explicitly forbids baking bootstrap keys or RPC auth into the image.
- Ingress rules correctly prohibit exposing the RPC API (`5001`) without an authenticated proxy.
- The Kustomize + Helm dual-artifact approach gives operators flexibility without forcing either one.

### Summary of Weaknesses
- The artifact layout includes `pdb.yaml` and `hpa.yaml` in the Helm chart. With `replicaCount` fixed to 1, a `PodDisruptionBudget` is of limited value and a `HorizontalPodAutoscaler` is unusable. These templates add maintenance overhead without clear benefit in v2.2.
- The spec does not choose a primary deployment mechanism (Kustomize vs. Helm). In practice, maintaining both to the same quality bar will split effort and may produce drift.
- Resource sizing guidance is absent; operators will not know whether to request 512 Mi, 1 Gi, or more for a single-node daemon.
- The swarm service is described as `NodePort` or `LoadBalancer` depending on overlay, but UDP port 4001 support is not explicitly required in the `Service` spec, despite libp2p swarm needing both TCP and UDP.
- The `values-production.yaml` and production overlay are referenced but not detailed; without examples, the acceptance criterion "production overlay uses StatefulSet + PVC + read-only root filesystem" is not fully testable.
- The minikube smoke test is release-blocking, but the spec does not specify how CI will provision a Kubernetes cluster or whether the `edge` image will be available before the release tag is pushed.

### Specific Recommendations
1. Remove `pdb.yaml` and `hpa.yaml` from v2.2; add them back only when clustering or multi-replica support is approved.
2. Choose Helm as the primary, documented installation path and treat Kustomize as the reference/CI path, or vice versa. Document the decision and the expected maintenance cadence for each.
3. Add a `resources` recommendation table (e.g., requests: 200m CPU / 512Mi memory; limits: 1000m CPU / 1Gi memory) with a note that these are starting points.
4. Require the swarm `Service` to expose both TCP and UDP port 4001, and document that some cloud load balancers do not support UDP.
5. Add a concrete `values-production.yaml` snippet with `securityContext`, `persistence`, and `ingress` settings so the acceptance criterion is objective.
6. Make the Kubernetes CI non-blocking for the v2.2.0 release and release-blocking only after the first successful minikube smoke run on `main`; this matches the spec's own P1 priority and avoids delaying P0 deliverables.

### Missing Research References and Acceptance Criteria
- Reference needed: Kubernetes `StatefulSet` headless service documentation and how it interacts with libp2p identify protocols.
- Reference needed: Cloud provider load-balancer UDP support matrix (AWS NLB, GCP, Azure) because swarm UDP is required.
- Missing acceptance criterion: `helm template` with default values must render a `StatefulSet` with `replicas: 1`, `securityContext.runAsNonRoot: true`, and `securityContext.readOnlyRootFilesystem: true`.
- Missing acceptance criterion: `kubectl apply -k k8s/overlays/minikube/` must result in a pod whose readiness probe (`/api/v0/id` or `ipfs id`) succeeds within 120 seconds.
- Missing acceptance criterion: Gateway ingress must be disabled by default and must require `ingress.enabled=true` plus an explicit `ingress.hosts` entry to be created.
- Missing acceptance criterion: `helm upgrade` of the chart must not delete or recreate the existing PVC, verified by checking the `resourcePolicy` annotation or `helm.sh/resource-policy: keep`.

---

## 4. INTEROP_TESTS_SPEC.md

### Scores
- **Coherence:** 6/10
- **Capability:** 9/10
- **Safety:** 6/10
- **Efficiency:** 6/10
- **Evolution:** 9/10

### Overall Verdict: CONDITIONAL

### Summary of Strengths
- The spec addresses the single biggest risk in the v2.2 plan: protocol drift against Kubo and Helia. It is the most strategically important spec in this audit.
- The test matrix is comprehensive: CAR exchange, Bitswap fetch, gateway retrieval, DHT provide/find, and IPNS resolution.
- CI architecture is sound: Docker Compose network, pinned Kubo version, nightly runs, release-blocking P0 tests, and report-only Helia P1 tests.
- Failure artifacts (logs, packet captures) are specified, which will reduce time-to-debug for flaky P2P tests.
- Security considerations correctly require isolated test networks, no production keys, and digest-pinned test images.

### Summary of Weaknesses
- The spec makes DHT provide/find and IPNS resolution P0 release-blocking. In the current codebase, DHT and IPNS are still stabilizing (per prior Council notes and the `lib/src/protocols/dht/` and `lib/src/protocols/ipns/` paths). Gating the release on these tests creates a high risk of v2.2.0 slipping if DHT/IPNS specs are not fully implemented first.
- The CAR exchange test requires `/api/v0/dag/export` and `/api/v0/dag/import`, but the RPC handlers at `lib/src/services/rpc/rpc_handlers.dart` only implement `/api/v0/dag/get` and `/api/v0/dag/put` (the latter returning 501). These handlers must be built before the interop test can run.
- Helia scaffolding is described as P1+ but still adds CI time, matrix complexity, and maintenance cost. The value is clear for v3.0, but it is marginal for v2.2.
- "Packet captures retained as CI artifacts" conflicts with retention policies and potential privacy concerns if any real data accidentally enters the test network; the spec does not define a purge schedule.
- Timeout and retry policies are generous (e.g., 120-180 s for DHT/IPNS). On GitHub Actions, this can make the interop job run for 15-30 minutes per PR, slowing feedback loops for protocol changes.

### Specific Recommendations
1. Split the P0 matrix into two tiers:
   - **P0 release-blocking:** CAR exchange, gateway retrieval, and Bitswap fetch (both directions).
   - **P1 required-but-allowed-to-fail:** DHT provide/find and IPNS resolution until the networking specs are proven stable.
2. Add `/api/v0/dag/export` and `/api/v0/dag/import` RPC handlers as prerequisites to the CAR acceptance criterion, or change the test to use Kubo CLI `ipfs dag export` and compare against a dart_ipfs library export path.
3. Move Helia tests to a separate, non-blocking nightly workflow that does not run on every PR, reducing CI noise and cost.
4. Replace "packet captures retained as artifacts" with "logs and pcap artifacts retained for 7 days, then purged by repository retention policy," and require that test data be synthetic and non-sensitive.
5. Cap the P0 interop job at 10 minutes total; tighten DHT/IPNS timeouts to 60 s after stabilization, and allow `continue-on-error` for P1 scenarios during the stabilization period.
6. Make the interop test job depend on the Docker image build job, so that the exact image being tested is the same one that would be published.

### Missing Research References and Acceptance Criteria
- Reference needed: Kubo v0.42.0 Docker image digest and compatibility matrix with dart_ipfs libp2p transports (TCP/QUIC/WebTransport).
- Reference needed: Helia test harness example (e.g., `ipfs/helia` test containers or `@helia/interop` patterns) to ground the P1+ scaffold in reality.
- Missing acceptance criterion: The Docker Compose network must be created with `internal: true` and must not publish host ports for the test services.
- Missing acceptance criterion: Every P0 scenario must assert byte-exact equality of retrieved content, not just CID equality or presence in a provider list.
- Missing acceptance criterion: The pinned Kubo version must be bumped by a scheduled Dependabot/Renovate PR and the PR must run the full P0 suite before merge.
- Missing acceptance criterion: Failure of a P1 scenario must not fail the overall CI run or block merging, and its results must be surfaced in a dedicated status check.

---

## 5. MODULARIZATION_SPEC.md

### Scores
- **Coherence:** 7/10
- **Capability:** 6/10
- **Safety:** 8/10
- **Efficiency:** 6/10
- **Evolution:** 7/10

### Overall Verdict: CONDITIONAL

### Summary of Strengths
- The spec correctly limits Phase 1 to stable primitives (CID, multibase, multicodec, multihash, block abstractions, blockstore interfaces, common codecs, key utilities) and defers protocol/service extraction until v2.1 stabilizes.
- Backward compatibility is explicitly preserved through umbrella re-exports from `lib/dart_ipfs.dart`, which currently exports `src/core/cid.dart`, `src/core/config/ipfs_config.dart`, `src/core/ipfs_node/ipfs_node.dart`, and a few other public APIs.
- The dependency direction is correct: `dart_ipfs_core` must not depend on the umbrella package, and the umbrella package depends on the core package.
- Security considerations are minimal and low-risk: no secrets in the published package, trusted pub.dev publisher, and conservative version constraints.
- The deprecation timeline for deep `lib/src/` imports is clear (deprecated in v2.2, removed in v3.0).

### Summary of Weaknesses
- The value proposition is under-specified. The project already depends on external packages (`multibase: ^1.0.0`, `dart_multihash: ^1.0.1`) for many of the primitives the spec proposes to extract. Without a clear consumer use case (e.g., plugin authors, external packages), the overhead of a monorepo may exceed the benefit in v2.2.
- The spec does not address how the `dart_ipfs_core` package will be versioned and published relative to the umbrella package. If both share a release train, patch releases to core will force umbrella releases; if they diverge, compatibility testing multiplies.
- Workspace tooling is left as "evaluate Melos or use `pubspec_overrides.yaml`." This is not a decision; implementation will stall on tooling choice without Council guidance.
- Moving tests while maintaining 80% coverage in the new package is more work than the spec acknowledges, because many existing tests exercise the moved modules through the umbrella node builder and will need to be duplicated or refactored.
- The spec does not explain how `pubspec.yaml` line 92 `dependency_overrides` will interact with the new workspace overrides.

### Specific Recommendations
1. Make the decision on workspace tooling before implementation begins: recommend Melos for a monorepo with cross-package testing and version alignment, or native Dart workspaces (`pubspec_overrides.yaml`) if the team wants to avoid an extra dependency. Record the Council decision in the spec.
2. Add a consumer-driven rationale: identify at least one in-repo or planned package (e.g., plugin examples, `dart_ipfs_cli` extracted in v3.0) that will consume `dart_ipfs_core` without the umbrella package.
3. Treat modularization as a v2.2.x / release-candidate deliverable, not a v2.2.0 blocker. Update the target release line to `v2.2.x` or `v2.3.0-alpha` unless it is explicitly deprioritized.
4. Define the versioning policy: either `dart_ipfs_core` follows the umbrella semver exactly (single release train) or it is versioned independently with a documented compatibility matrix.
5. Before moving files, run a dependency graph analysis to confirm that the chosen modules have no imports back to protocol or service code.
6. Add a migration guide for consumers who currently deep-import `lib/src/core/cid.dart` and similar files, with a clear replacement import path.

### Missing Research References and Acceptance Criteria
- Reference needed: Dart native workspaces (`pubspec_overrides.yaml`) and Melos comparison for packages with interdependent tests.
- Reference needed: `dart pub publish --dry-run` behavior for packages that use path dependencies or `pubspec_overrides.yaml`.
- Missing acceptance criterion: A dependency graph check (e.g., `dart run dependency_validator`) must report zero forbidden dependencies from `dart_ipfs_core` back to the umbrella package.
- Missing acceptance criterion: `dart test` in `packages/dart_ipfs_core` must reach 80% line coverage without including umbrella integration tests.
- Missing acceptance criterion: `dart pub publish --dry-run` for both packages must pass with no warnings about local path overrides or missing `CHANGELOG.md` entries.
- Missing acceptance criterion: A consumer test must prove that `package:dart_ipfs/dart_ipfs.dart` and `package:dart_ipfs_core/dart_ipfs_core.dart` expose the same CID/multihash API for the moved classes.

---

## 6. PLUGINS_SPEC.md

### Scores
- **Coherence:** 6/10
- **Capability:** 7/10
- **Safety:** 6/10
- **Efficiency:** 6/10
- **Evolution:** 7/10

### Overall Verdict: CONDITIONAL

### Summary of Strengths
- The existing plugin system is minimal: `lib/src/core/plugins/ipfs_plugin.dart` defines only an `IPFSPlugin` abstract class and a `PluginManager` that registers and runs lifecycle hooks. The spec correctly identifies the need for hardening.
- The capability taxonomy is a good starting point (`blockstore.read`, `network.bitswap.observe`, `metrics.emit`, `gateway.register_route`).
- Deny-by-default, capability-gated adapters, and audit logging are the right security posture for a plugin runtime.
- Ed25519 manifest signing and the trusted-keys file are well-aligned with the `lib/src/core/crypto/ed25519_signer.dart` utility already present in the codebase.
- The spec appropriately defers public registries, hot-reload, OS-level sandboxing, and dynamic network installation to v3.0.

### Summary of Weaknesses
- The spec claims that plugins "run in Dart Isolates with no shared mutable state with the host." This is misleading. Dart Isolates run in the same OS process and can access the same filesystem, network, environment variables, and native libraries (via FFI) as the host. They are not a security boundary against malicious plugins. The spec should explicitly state this limitation and not rely on Isolates for confinement.
- Storing a repository development signing key at `tool/plugin_dev_key.pem` is a security risk. Any leak of the repository (or a CI artifact) exposes a trusted key. The spec should require that the dev key be generated dynamically in CI for tests and never committed to the repository.
- The capability taxonomy is not yet aligned with the actual service structure. For example, `CapabilityBlockStore` and `CapabilityMetricsEmitter` do not exist, and the spec does not map capabilities to concrete `IPFSNode` methods or service classes.
- The example plugins are more complex than necessary for Phase 1. A logging plugin, a pin-policy plugin, and a gateway-metrics plugin each require stable Bitswap, pinning, and gateway internals that are themselves still being hardened in v2.2.
- There is no mention of the performance overhead of spawning Isolates for each plugin or the memory cost of copying large blocks across Isolate boundaries.

### Specific Recommendations
1. Rewrite the security framing: Isolates provide memory isolation and crash containment, not a sandbox against malicious code. Add an acceptance criterion that an untrusted plugin attempting filesystem or network access outside its capabilities is blocked by capability enforcement, not by the Isolate boundary.
2. Replace the committed `tool/plugin_dev_key.pem` with a CI-generated key pair for tests, and require that production deployments use a `plugin.trustedKeysPath` pointing to keys managed outside the repository.
3. Reduce the Phase 1 example set to one or two simple plugins (e.g., a metrics emitter and a logging observer) that require only read-only capabilities, and defer the pin-policy plugin until pinning is fully stabilized.
4. Add a capability-to-service mapping table showing which `IPFSNode` manager or service class implements each capability, and which methods are gated.
5. Document the performance model: plugin Isolates are spawned at startup, message-passing overhead is expected, and large block payloads should be passed by reference or capability token rather than copied.
6. Add a requirement that the plugin host must be optional and disabled by default until the operator explicitly enables it, to avoid breaking existing `PluginManager` consumers who register in-process plugins.

### Missing Research References and Acceptance Criteria
- Reference needed: Dart Isolate security model and limitations (e.g., `dart:ffi` and `dart:io` access from Isolates).
- Reference needed: Capability-based security in plugin systems (e.g., Deno permissions, WebExtension manifest permissions) for comparison.
- Missing acceptance criterion: A plugin denied a capability must receive `CapabilityException` and must be disabled; the node must continue running without it.
- Missing acceptance criterion: An unsigned plugin must fail to load unless `plugin.allowUnsigned` is explicitly set to `true` in the config, and the failure must be logged at the warning level.
- Missing acceptance criterion: A tampered plugin archive must fail signature verification before any code is loaded or initialized.
- Missing acceptance criterion: The plugin host must not prevent the node from starting if plugin loading is disabled.
- Missing acceptance criterion: Audit logs must include plugin ID, capability exercised, timestamp, and outcome, and must be testable via a mock logger or output capture.

---

## Cross-Cutting Findings

### 1. Dependency on Prior Specs
All six specs assume that the v2.0/v2.1 protocol and services specs are implemented before or alongside v2.2 work. Specifically:
- `CLI_SPEC.md` and `INTEROP_TESTS_SPEC.md` require CAR export/import, trustless gateway, and DHT/IPNS stability from `PROTOCOL_COMPLIANCE_SPEC.md`, `NETWORKING_P2P_SPEC.md`, and `SERVICES_APIS_SPEC.md`.
- `PLUGINS_SPEC.md` requires stable `BlockStore`, key interfaces, and pinning from `MODULARIZATION_SPEC.md` and the services specs.
- `DOCKER_SPEC.md` and `KUBERNETES_SPEC.md` require the CLI binary to exist and be stable.

The Council should confirm the v2.0/v2.1 implementation status before committing to the v2.2 release date.

### 2. Configuration Model Gaps
`IPFSConfig` at `lib/src/core/config/ipfs_config.dart` is incomplete for the CLI and plugin specs:
- `toJson()` omits `gateway`, `metrics`, `keystore`, and `customConfig` (lines 300-322).
- There is no `plugin` configuration section for `plugin.allowUnsigned`, `plugin.trustedKeysPath`, etc.
- The file format is YAML (`fromFile` uses `loadYaml` at line 293), while CLI and Docker examples reference `config.json`.

A single configuration spec should be added to harmonize file format, JSON/YAML support, and plugin settings.

### 3. Lifecycle Wiring
`IPFSNodeBuilder` does not register `RPCServer` or `GatewayServer` with `LifecycleManager`. The CLI `daemon` command and the Kubernetes readiness probe both assume these services are running. Either the lifecycle manager must be extended, or the CLI must explicitly manage them with documented shutdown order.

### 4. Version String Drift
The version string is hard-coded in multiple places:
- `lib/src/services/rpc/rpc_handlers.dart:31` — `dart_ipfs/0.1.0`
- `lib/src/services/gateway/gateway_server.dart:100` — `dart_ipfs/0.1.0`
- `pubspec.yaml:2` — `1.11.5`
- `Dockerfile:21` — `1.2.4-secure`

The CLI, Docker, and Kubernetes specs must define a single source of truth for the version string and eliminate these inconsistencies.

### 5. Native Dependency in Containers
`sodium: ^4.0.2+1` (line 65 of `pubspec.yaml`) wraps `libsodium`. Any container image based on `distroless/static` or `scratch` will fail unless the dependency is statically linked or the base image provides glibc. This blocks the Docker spec's runtime image choice until resolved.

---

## Council Recommendations

1. **Approve CLI, Docker, and Kubernetes specs for implementation** with the amendments listed above. Treat them as P0/P1 deliverables for v2.2.
2. **Condition INTEROP_TESTS_SPEC.md on protocol stability.** Make CAR, gateway, and Bitswap P0 release-blocking; keep DHT and IPNS as P1 required-but-allowed-to-fail until the networking specs are verified. Move Helia to a separate nightly workflow.
3. **Defer MODULARIZATION_SPEC.md to a v2.2.x or v2.3.0-alpha release** unless a clear external consumer is identified. Make the workspace tooling decision before implementation begins.
4. **Condition PLUGINS_SPEC.md on fixing the Isolate sandbox framing and removing the committed dev key.** Reduce Phase 1 to one or two read-only example plugins and make the plugin host optional by default.
5. **Add a cross-cutting configuration specification** to resolve `IPFSConfig` gaps, JSON/YAML inconsistency, and plugin settings before any CLI or plugin implementation begins.
6. **Mandate a single source of truth for version strings** before the Docker and Kubernetes specs are implemented, and update all hard-coded references in `rpc_handlers.dart`, `gateway_server.dart`, and the `Dockerfile`.
7. **Resolve the `libsodium` runtime dependency** before selecting a final distroless base image, and document the chosen base image plus any required dynamic libraries.
8. **Confirm the lifecycle wiring** for `RPCServer` and `GatewayServer` in `IPFSNodeBuilder` or the CLI `daemon` command, and include a readiness probe contract for Kubernetes and Docker health checks.

---

## Appendix: Verdict Legend

- **PASS:** Three or more scores at or above 6, Safety strictly above 3, and the spec is ready for implementation with at most minor amendments.
- **CONDITIONAL:** Three or more scores at or above 6, Safety strictly above 3, but the spec has material gaps that must be resolved before it becomes release-blocking or before implementation proceeds.
- **DEFER:** The spec is not ready for the current release window; it may have too many open questions or depend on unimplemented prerequisites.
- **REJECT:** Safety score is 3 or below, or a majority of scores are below the threshold.

All six specs in this audit are at or above the threshold on three or more lenses and have Safety scores above 3. None are rejected.
