# dart_ipfs Docker & Multi-Architecture Image Specification

**Document ID:** `DOCKER_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Status:** Draft specification for implementation  
**Council Priority:** P0 APPROVED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.2

---

## 1. Goal and Scope

The goal of this specification is to deliver reproducible, hardened, multi-architecture Docker images for `dart_ipfs` with automated CI builds, publishing, and supply-chain provenance. The image must be suitable for production daemon deployments, local development, CI build verification, and troubleshooting.

Scope includes:

- Refactoring the existing `Dockerfile` to use a modern, multi-stage build.
- Defining production (`runtime`), build (`builder`), and debug image variants.
- Building multi-arch manifests for `linux/amd64` and `linux/arm64`.
- Pinning base image digests and signing published images.
- Publishing `edge` (per `main` merge) and semver/release tags to `ghcr.io`.
- Updating `docker-compose.yml` to reference the new image and include health checks.
- Running container vulnerability scans in CI and blocking releases on CRITICAL/HIGH findings.

Out of scope for v2.2:

- Windows or macOS native containers (Linux only).
- GPU-accelerated or specialized hardware images.
- A public Docker Hub registry (use `ghcr.io` for now).

---

## 2. Official References

- Dockerfile best practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- OCI Image Specification: https://github.com/opencontainers/image-spec
- Docker Content Trust / Notary: https://docs.docker.com/engine/security/trust/
- cosign image signing: https://github.com/sigstore/cosign
- Distroless images: https://github.com/GoogleContainerTools/distroless
- Chainguard Images: https://www.chainguard.dev/chainguard-images
- CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker
- NSA/CISA Kubernetes Hardening Guidance: https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF
- OpenSSF Scorecard: https://github.com/ossf/scorecard
- SLSA provenance: https://slsa.dev/spec/v1.0/provenance
- GitHub Container Registry: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- Docker buildx: https://docs.docker.com/build/building/multi-platform/

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Dockerfile | A `Dockerfile` exists in the repository root, but it references a stale image tag. | The image does not reflect the current v2.x release and may not build cleanly. |
| CI build | No automated CI builds or publishes the image. | Users cannot reliably pull `latest` or `v2.x` images. |
| Multi-arch | No multi-architecture manifest or build matrix. | Only one architecture is produced, excluding ARM64 production deployments. |
| Signing | No image signing, SBOM, or provenance. | Supply chain is not verifiable. |
| Compose | A `docker-compose.yml` exists but lacks health checks and the new image reference. | No out-of-the-box `docker compose up` smoke test for the daemon. |

Key files to update or create:

- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/docker.yml`
- `tool/compile_cli.dart` (produces the binary copied into the image)

---

## 4. Target State / Requirements

### 4.1 Image Variants and Tags

| Variant | Tag Pattern | Base | Purpose | Notes |
|---------|-------------|------|---------|-------|
| `runtime` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>` | `gcr.io/distroless/base` or `cgr.dev/chainguard/static` | Production daemon | Non-root, no shell, minimal attack surface. |
| `runtime` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-<arch>` | Same as above | Per-arch digest | Used by multi-arch manifest. |
| `builder` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-builder` | `dart:stable-sdk` or pinned `dart:<version>` | CI / build verification | Contains Dart SDK, protoc, build tools. Not for production. |
| `debug` | `ghcr.io/dart-ipfs/dart-ipfs:<semver>-debug` | `gcr.io/distroless/base:debug` or `cgr.dev/chainguard/bash` | Troubleshooting | Includes shell; must not be the default. |
| `latest` | `ghcr.io/dart-ipfs/dart-ipfs:latest` | Multi-arch runtime | Rolling pointer to latest release | Updated only on stable releases, not every CI build. |
| `edge` | `ghcr.io/dart-ipfs/dart-ipfs:edge` | Multi-arch runtime | Latest successful `main` build | Mutable; for early adopters. |

### 4.2 Dockerfile Structure

- Use a multi-stage build: `build` -> `test` (optional) -> `runtime`.
- `build` stage: install the Dart SDK, dependencies, and compile `bin/ipfs.dart` to `build/ipfs` using `dart compile exe`.
- `runtime` stage: copy the compiled binary into a distroless or Chainguard static image.
- Set `ENTRYPOINT ["/app/ipfs"]` and `CMD ["daemon"]`.
- Add OCI labels per the OCI Image Specification: `org.opencontainers.image.source`, `.version`, `.revision`, `.description`, `.license`.
- Expose only the documented ports: `4001/tcp` and `4001/udp` (libp2p swarm), `5001` (RPC API), `8080` (gateway), and `8081` (metrics, if enabled).
- Create a non-root user (`uid=1000`, `gid=1000`) and run the daemon under that identity.
- Remove package managers, setuid binaries, and shells from the runtime stage.

### 4.3 Multi-Architecture Build

- Build for at least `linux/amd64` and `linux/arm64` using `docker buildx` with a single multi-platform manifest.
- Avoid QEMU-only cross-compilation for Dart native binaries if possible. Preferred approaches:
  - Use Dart AOT snapshot + native runtime compilation inside the target architecture stage.
  - Use `buildx` with native runners where available.
- Produce per-arch digests and a combined manifest for the `runtime` and `edge` tags.

### 4.4 Supply-Chain Hardening

- Pin all base image digests (`gcr.io/distroless/base@sha256:...`) and track updates via Renovate or Dependabot.
- Sign images with `cosign` (keyless via OIDC where possible, or with a project signing key).
- Attach SBOMs using `syft` or `trivy`.
- Publish SLSA provenance where feasible using `slsa-github-generator`.
- Run `trivy` or `grype` container scans in CI and block releases on CRITICAL/HIGH findings without an approved exception.
- Pin all GitHub Actions used in `.github/workflows/docker.yml` by SHA.
- Use OIDC / short-lived tokens for registry publishing where possible.

### 4.5 docker-compose.yml

- Reference the new image tag `ghcr.io/dart-ipfs/dart-ipfs:<version>`.
- Mount a persistent volume for the IPFS repo path (e.g., `/data/ipfs`).
- Expose the documented ports.
- Add a health check that invokes `ipfs id` or `/api/v0/id`.
- Default the API address to localhost inside the container unless overridden by environment variable.

---

## 5. Detailed Acceptance Criteria

1. `docker buildx build --platform linux/amd64,linux/arm64 -t dart-ipfs:v2.2.0 .` succeeds from a clean checkout.
2. The runtime image has no shell and no root user (`docker run --rm <image> whoami` fails; `id` inspection shows `uid=1000`).
3. `docker run --rm dart-ipfs:v2.2.0 version` prints the correct semantic version and supported protocol versions.
4. `docker run --rm dart-ipfs:v2.2.0 daemon --api-addr /ip4/0.0.0.0/tcp/5001` starts and responds to `curl http://localhost:5001/api/v0/id`.
5. CI publishes the `edge` tag on every merge to `main` and a semver tag on every GitHub release.
6. Published images are signed with `cosign` and have SBOMs attached.
7. Container scans in CI report no CRITICAL vulnerabilities and no HIGH vulnerabilities without an approved exception.
8. `docker compose up` from the repository root starts the daemon and the health check succeeds.
9. The `builder` image can be used in CI to reproduce the release build.
10. The `debug` image includes a shell and is clearly labeled as not for production use.

---

## 6. Security Considerations

- Runtime image must be non-root, read-only root filesystem, minimal capability set, and no shell.
- Do not embed secrets, private keys, or `.env` files in images. Use runtime-mounted secrets or environment variables for sensitive configuration.
- Bind the API to localhost by default inside the container; require explicit configuration to bind to `0.0.0.0`.
- Only expose documented ports. Disable any debug or pprof endpoints unless explicitly enabled.
- Keep the final image small to reduce attack surface. Distroless and Chainguard static images are preferred.
- Use image signing and SBOMs so consumers can verify provenance and contents.
- Scan all images before publishing; gate releases on vulnerability findings.
- Do not run as root; use `USER` directive and a writable volume for the repo path.
- Avoid `setuid` binaries and package managers in the runtime image.

---

## 7. Testing Strategy

### 7.1 Container Build Tests

- Verify the multi-arch build succeeds in CI on every Dockerfile change.
- Inspect the runtime image for shell absence and non-root user.
- Verify image size targets (e.g., runtime < 50 MB excluding the binary).

### 7.2 Container Runtime Tests

- `docker run --rm <image> version` returns the expected version.
- `docker compose -f docker-compose.yml up` starts the daemon and passes the `/api/v0/id` health check.
- A smoke test adds a file via the container CLI and retrieves it via the gateway.

### 7.3 Security Scanning

- Run `trivy image` or `grype` on every build and fail on CRITICAL/HIGH findings.
- Generate and attach SBOMs in CI.
- Verify cosign signatures after publishing.

### 7.4 CI Pipeline

- Create `.github/workflows/docker.yml` triggered:
  - On PRs touching `Dockerfile`, `docker-compose.yml`, or `.github/workflows/docker.yml`.
  - On every release tag.
- Jobs:
  - Multi-arch build and local load.
  - Vulnerability scan.
  - Sign and publish to `ghcr.io` (only on `main` and releases).
  - Docker Compose smoke test.

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - CLI binary (`bin/ipfs.dart`) and `tool/compile_cli.dart` must be stable (see `CLI_SPEC.md`).
  - Release versioning and tagging strategy.
  - GitHub Container Registry access configured for the repository.
- **Order:** Docker is a P0 foundation item and must be completed in the alpha phase, before Kubernetes manifests and interop tests depend on published images.
- **Downstream consumers:**
  - `KUBERNETES_SPEC.md` — the Helm chart and Kustomize manifests reference the published image.
  - `INTEROP_TESTS_SPEC.md` — the Docker Compose interop network may use the published image or a local build.

---

## 9. Backward Compatibility Notes

- Existing `docker-compose.yml` users must update to the new image tag `ghcr.io/dart-ipfs/dart-ipfs:<version>`.
- The old `Dockerfile` image tag is deprecated and will be removed in v2.3.0.
- Volume paths remain compatible: the default repo path inside the container should be `/data/ipfs` or configurable via the `IPFS_PATH` environment variable.
- No breaking changes to the library API are introduced by the Docker work.
- The `latest` tag will be a rolling pointer to the most recent stable release; users who want immutable references should use semver tags or digests.
