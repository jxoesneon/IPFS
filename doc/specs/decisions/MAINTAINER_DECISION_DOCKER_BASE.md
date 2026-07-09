# Maintainer Decision — Docker Runtime Base Image Strategy for dart_ipfs v2.2

**Decision ID:** `MAINTAINER_DECISION_DOCKER_BASE`  
**Date:** 2026-06-25  
**Convened by:** project maintainers  
**Scope:** Select the runtime base image strategy for `dart_ipfs` Docker images in v2.2.  
**Trigger:** Cross-cutting audit finding that `pubspec.yaml` includes `sodium: ^4.0.2+1`, which wraps `libsodium`, and `libsodium` requires glibc. The current `DOCKER_SPEC.md` proposes `distroless/base` or `cgr.dev/chainguard/static`, which will fail at runtime unless the native dependency is resolved.

---

## 1. Background and Constraints

### 1.1 Native Dependency

- `pubspec.yaml` (line 65) declares `sodium: ^4.0.2+1`, which wraps the native `libsodium` library.
- `libsodium` is a C library that requires glibc at runtime. It is not a pure-Dart dependency and cannot be bundled into a static Dart AOT executable without deliberate static linking.
- The existing `Dockerfile` already acknowledges this constraint by using `debian:bookworm-slim` and installing `libsodium23` (lines 22-25), although the file is otherwise stale and insecure.
- The `sodium` package is not directly imported in `lib/src`, but `ipfs_libp2p` is used extensively for P2P transports and may pull it transitively. Removing the dependency without a full audit is unsafe for v2.2.

### 1.2 Spec Context

- `doc/specs/features/DOCKER_SPEC.md` targets `distroless/base` or `cgr.dev/chainguard/static` for the runtime image, with a size target of < 50 MB (excluding binary).
- `doc/specs/audits/MAINTAINER_AUDIT_OPERATIONS_ECOSYSTEM.md` flags this as a cross-cutting blocker: "Choose glibc base or remove/inline libsodium dependency."
- `doc/specs/audits/MAINTAINER_AUDIT_MASTER.md` lists implementation priority: "Docker images (after libsodium base decision)."

---

## 2. Options Evaluated

| Option | Description |
|--------|-------------|
| **A** | Use a glibc-based base image for the default runtime (e.g., `debian:12-slim`, `ubuntu:24.04`, or `cgr.dev/chainguard/glibc-dynamic`). |
| **B** | Use a multi-stage build with a static Dart executable and remove or inline `libsodium` usage so a `distroless/static` or `scratch` image can be used. |
| **C** | Use `scratch` or `distroless/static` but document that `libsodium` requires a separate sidecar or that the user must override to a glibc image. |
| **D** | Adopt a multi-variant approach: default to a hardened glibc base (`cgr.dev/chainguard/glibc-dynamic`), provide an experimental static variant if feasible, and keep a debug variant. |

---

## 3. maintainers Lens Evaluation

### 3.1 Coherence: Does the option fit the existing Docker spec and CI plan?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 9/10 | Aligns with the existing Dockerfile, which already uses a glibc base (`debian:bookworm-slim`). Requires minimal changes to `DOCKER_SPEC.md` and the CI pipeline. The spec's security requirements (non-root, read-only root, no shell) can still be met on a glibc base. |
| **B** | 4/10 | Requires a major dependency audit and refactoring of `pubspec.yaml` and potentially `ipfs_libp2p` usage. The CLI/Docker implementation sequence in `MAINTAINER_AUDIT_MASTER.md` places Docker after the libsodium decision, but this option makes the Docker work dependent on a large, uncertain crypto refactor. |
| **C** | 3/10 | Contradicts the stated goal of a production-ready, zero-config Docker image. Pushing the burden to the user undermines the `docker compose up` acceptance criterion and the Kubernetes spec's expectation of a runnable default image. |
| **D** | 8/10 | Preserves the spec's structure while adding a documented variant matrix. The default remains the safe, runnable image; an experimental static variant is a non-blocking addition. This matches the existing variant table in `DOCKER_SPEC.md` (runtime, builder, debug). |

### 3.2 Capability: Does the option produce a runnable container?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 9/10 | Produces a runnable container immediately. `libsodium` is satisfied by the base image. The current `Dockerfile` already proves this works mechanically. |
| **B** | 5/10 | High uncertainty. Static linking `libsodium` into a Dart AOT executable is not a standard, well-documented path for `package:sodium`. If `ipfs_libp2p` transitively depends on `sodium`, the refactor scope expands substantially. |
| **C** | 4/10 | The default image is broken for P2P operations unless the user supplies a sidecar or switches base images. This is not a runnable default. |
| **D** | 9/10 | The default variant is runnable. The static variant is explicitly experimental and gated by a separate CI job; it does not block the v2.2 release. |

### 3.3 Safety: What are the supply-chain and runtime risks?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 8/10 | A glibc base is larger than a static image, which increases the CVE surface. However, using `cgr.dev/chainguard/glibc-dynamic` mitigates this: Chainguard images are minimal, frequently patched, and include SBOMs. Digest pinning, cosign signing, and container scanning remain in scope. |
| **B** | 9/10 | If achievable, this yields the smallest runtime with no glibc and no package manager. However, the implementation risk is high; a botched static-link attempt could introduce subtle crypto failures or runtime crashes. |
| **C** | 6/10 | The runtime image is small, but the operational model is risky: users must manage a sidecar or override the image, creating a support burden and misconfiguration risk. |
| **D** | 8/10 | The hardened glibc default provides a strong security baseline. The static variant is opt-in and can be promoted to default only after it passes the full interop test suite. This avoids betting the release on unproven static linking. |

### 3.4 Efficiency: What is the image size and build complexity trade-off?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 7/10 | `debian:12-slim` adds ~30 MB uncompressed; `cgr.dev/chainguard/glibc-dynamic` is smaller but still larger than `static`. Build complexity is low. The original < 50 MB target should be relaxed to a staged upper bound (e.g., < 80 MB for v2.2). |
| **B** | 9/10 | Smallest possible final image if static linking succeeds. Build complexity is high: requires custom linker flags, `libsodium` static library availability, and verification across `linux/amd64` and `linux/arm64`. |
| **C** | 6/10 | Small image, but operational overhead (sidecar coordination, image overrides) increases total cost of ownership. The "efficiency" of the image itself is offset by the complexity of deploying it. |
| **D** | 7/10 | The default is slightly larger than an ideal static image, but the build pipeline is simple and maintainable. The static variant is an additive optimization, not a release blocker. |

### 3.5 Evolution: Does it support future mobile/web and multi-arch builds?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 8/10 | Supports multi-arch (`linux/amd64`, `linux/arm64`) with standard Docker buildx. Does not block future mobile/web work because the Dart package remains unchanged. It does not advance the long-term goal of a fully static container. |
| **B** | 6/10 | If successful, it would simplify future mobile and embedded deployments. However, the refactor is risky and could delay v2.2. Static linking is not a prerequisite for mobile/web, which have their own build targets. |
| **C** | 3/10 | The sidecar model does not generalize to mobile, web, or standard Kubernetes deployments. It is a dead end for the ecosystem. |
| **D** | 9/10 | The glibc default ships v2.2 on schedule. The static variant creates a long-term runway: if it matures, it can become the default in v2.3 without disrupting users. This is the most evolvable path. |

---

## 4. Aggregate Scores and Verdict

| Option | Coherence | Capability | Safety | Efficiency | Evolution | Average | Verdict |
|--------|-----------|------------|--------|------------|-----------|---------|---------|
| **A** | 9 | 9 | 8 | 7 | 8 | 8.2 | Strong candidate |
| **B** | 4 | 5 | 9 | 9 | 6 | 6.6 | Reject for v2.2 default; revisit as static variant |
| **C** | 3 | 4 | 6 | 6 | 3 | 4.4 | Reject |
| **D** | 8 | 9 | 8 | 7 | 9 | 8.2 | **Adopt** |

**Final Verdict:** Adopt **Option D** for dart_ipfs v2.2.

The default runtime image shall use a hardened glibc base: **`cgr.dev/chainguard/glibc-dynamic`** (or equivalent). The image matrix shall include an **experimental static variant** (based on `cgr.dev/chainguard/static` or `scratch`) if and only if static linking of `libsodium` is demonstrated to work across both target architectures. A **debug variant** with a shell shall remain available for troubleshooting. This strategy satisfies the native dependency, preserves the Docker spec's security posture, and leaves a clear path to a fully static image in a future release.

---

## 5. Detailed Decisions

### 5.1 Default Runtime Base: `cgr.dev/chainguard/glibc-dynamic`

- **Rationale:** This is the smallest hardened glibc base that satisfies `libsodium` at runtime. It provides glibc without a package manager, shell, or unnecessary tooling, minimizing the CVE surface compared to `debian:12-slim` or `ubuntu:24.04`.
- **Alternatives considered:** `debian:12-slim` and `ubuntu:24.04` are acceptable fallback bases if Chainguard image availability or licensing becomes a concern, but they are not the preferred default because they include more unneeded packages.
- **Security controls retained:** non-root user (`uid=1000`), read-only root filesystem, `cap_drop: ALL`, no shell, digest-pinned base image, cosign signing, SBOM generation, and container vulnerability scanning.

### 5.2 Default vs. Variant: Most Secure Runnable Option Wins

- The **default** image shall be the **most secure runnable option** (`chainguard/glibc-dynamic`), not the absolute smallest option.
- The **smallest** option (`static`/`scratch`) is an **experimental variant** until it can be proven to pass the full runtime test suite, including P2P networking and crypto operations.
- A **builder** variant (`dart:stable-sdk` or pinned equivalent) is required for reproducible CI builds and local development.
- A **debug** variant (`cgr.dev/chainguard/bash` or `gcr.io/distroless/base:debug`) is required for troubleshooting and must be clearly labeled as not for production.

### 5.3 Experimental Static Variant Rules

- The static variant is **not release-blocking** for v2.2.
- It may be built and published as `ghcr.io/dart-ipfs/dart-ipfs:<semver>-static` only if:
  - `dart compile exe` produces a binary that can be placed on `cgr.dev/chainguard/static` or `scratch` and still resolve `libsodium` (either via static linking or by removing/transitively-avoiding the dependency).
  - The binary passes container runtime tests: `version`, `daemon`, `/api/v0/id`, and a P2P smoke test.
  - The multi-arch build (`linux/amd64` and `linux/arm64`) succeeds for both architectures.
- If the static variant cannot be produced, it is deferred to v2.3 with no impact on the v2.2 release.

### 5.4 Dependency Audit Recommendation

- Before v2.2.0 ships, the maintainer shall run a transitive dependency audit to determine whether `package:sodium` is actually loaded at runtime by `dart_ipfs` or `ipfs_libp2p`.
- If `sodium` is unused, create a v2.2.x follow-up task to remove it from `pubspec.yaml`, which may simplify the v2.3 static variant.
- If `sodium` is used, document the specific call sites and evaluate whether the functionality can be replaced with `package:cryptography` (already in `pubspec.yaml`) or another pure-Dart implementation.

### 5.5 Updates to `DOCKER_SPEC.md`

The following amendments shall be made to `doc/specs/features/DOCKER_SPEC.md`:

1. Replace the runtime base recommendation from `gcr.io/distroless/base` or `cgr.dev/chainguard/static` with `cgr.dev/chainguard/glibc-dynamic` (default), and add `cgr.dev/chainguard/static` as an experimental variant.
2. Update the image size acceptance criterion from a strict "< 50 MB" to a staged target: "< 80 MB compressed for v2.2 glibc runtime; < 50 MB for static variant after it is proven."
3. Add a section documenting the `libsodium` runtime requirement and the reason for the glibc base.
4. Reconcile `docker-compose.yml`: keep the nginx reverse-proxy as an **optional production overlay**, and remove it from the default developer compose so the default is a simple `docker compose up` of the daemon.
5. Add acceptance criteria for verifying no shell, no package manager, and no writable root filesystem in the runtime image.
6. Add a `tool/compile_cli.dart` documentation requirement that notes the `libsodium` dynamic library path for glibc-based images.

### 5.6 Implementation Priority

Per `MAINTAINER_AUDIT_MASTER.md`, Docker images are implemented after the libsodium base decision. With this decision in place, the v2.2 implementation order is:

1. Update `Dockerfile` to use `cgr.dev/chainguard/glibc-dynamic` with multi-stage build, non-root user, and `bin/ipfs.dart` entry point.
2. Create `.github/workflows/docker.yml` for multi-arch build, scan, sign, and publish.
3. Update `docker-compose.yml` to reference the published image and add a health check.
4. (Optional, non-blocking) Build experimental `static` variant in CI.
5. Update `DOCKER_SPEC.md` to reflect this decision and the amended acceptance criteria.

---

## 6. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `cgr.dev/chainguard/glibc-dynamic` may not include `libsodium` by default. | Verify the base image contents before finalizing; if `libsodium` is missing, add a copy step from the builder stage or select `debian:12-slim` as the fallback. |
| Image size may exceed the amended target. | Track compressed size in CI; investigate stripping the binary or removing unused dependencies before release. |
| Future static variant may never be feasible. | The static variant is experimental and non-blocking; the glibc default is a stable long-term option. |
| Users may be confused by multiple variants. | Document the variant matrix in the README and image registry; keep `latest` pointing to the hardened glibc runtime. |

---

## 7. Maintainer Signatures

- **Coherence:** Adopt hardened glibc default; align with existing Dockerfile and CI plan.
- **Capability:** Ensure the default image runs P2P networking without user-side workarounds.
- **Safety:** Prefer Chainguard glibc for minimal CVE surface; retain signing, SBOM, and scanning.
- **Efficiency:** Accept slightly larger image to avoid release-blocking refactor; optimize via static variant after v2.2.
- **Evolution:** Preserve the path to a fully static, distroless image in a future release without blocking v2.2.

**Final maintainer decision:** Adopt **Option D**. Default runtime base is **`cgr.dev/chainguard/glibc-dynamic`**, with an experimental `static` variant and a `debug` variant. Amend `DOCKER_SPEC.md` accordingly.
