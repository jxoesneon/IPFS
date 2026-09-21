# Maintainer Guide & Release Protocol

This document establishes the rules and checklists for maintaining the `dart_ipfs` repository. Follow these procedures to ensure clean releases, stable builds, and accurate documentation.

## ⚠️ Prime Directive: "Clean & Synchronized"
Before any release or major push, the repository state must be **clean** (no untracked debug files) and **synchronized** (versions match across all docs).

---

## 📋 Release Checklist

Copy this checklist for every release cycle.

### 1. Pre-Release Checks
- [ ] **Remote Tag Check**: Run `git ls-remote --tags origin` to verify the next version number is free.
- [ ] **Pub.dev Check**: Check the live version on pub.dev to ensure semantic versioning continuity.
- [ ] **Uncommitted Files**: Run `git status`.
    - Move debug scripts to `scripts/` or delete them.
    - **CRITICAL**: If `packages/` exists, ensure `.git` folders inside vendored packages are removed to prevent submodule issues.
- [ ] **Test Suite**: Run `dart test` and verify critical paths (e.g., `gateway_selector_test.dart`).

### 2. Version Bump
`pubspec.yaml` (`version:`) is the single source of truth. All other version-bearing
surfaces are synchronized and validated by tooling — do **not** edit them by hand:

1. Bump `version:` in `pubspec.yaml`.
2. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `CHANGELOG.md` (manual; the gate requires it).
3. Run `make release-sync` — rewrites `lib/src/version.dart`, `docker-compose*.yml`,
   `helm/dart-ipfs/Chart.yaml` + `README.md`, `k8s/**/kustomization.yaml`,
   `k8s/base/deployment.yaml`, `README.md`, and `ROADMAP.md` from `pubspec.yaml`.
4. Run `make release-check` — validates every surface, the CHANGELOG section, and
   (when on a tag) that the tag matches `pubspec.yaml`. This is the same check the
   publish workflow runs as a fail-closed gate.
5. Update `doc/PROTOBUF_COMPATIBILITY.md` only if the protobuf dependency changed.

Still manual per release: the CHANGELOG entry content, README "What's New" /
ROADMAP narrative, the git tag itself, the changed-code coverage gate, and
maintainer sign-off. See `ENGINEERING_NOTES.md` for the full surface list.

### 3. Documentation Sync
- [ ] **Wiki/Docs**: Update `docs/` content if new features were added.
- [ ] **Example Apps**: Ensure `example/` apps build and run with the new version.

### 4. Git Operations
- [ ] **Atomic Commits**: Commit feature work *separately* from the release chore.
    - Feat: `feat(core): Add X`
    - Release: `chore(release): Bump version to 1.2.1`
- [ ] **Tagging**:
    1. Push `master` first: `git push origin master`
    2. Create tag: `git tag v1.2.1`
    3. Push tag: `git push origin v1.2.1`
    4. The `publish.yml` workflow then runs automatically: the release gate
       verifies surfaces/tag/CHANGELOG, the quality gate runs analysis,
       tests, and changed-line coverage for every package, the packages
       publish to pub.dev in dependency order, and a GitHub Release is
       created from the CHANGELOG section.

### 5. Multi-Package Tags

This repo publishes three packages. Each has its own tag convention,
which must match the package's configured tag pattern on pub.dev
(Admin → Automated publishing → GitHub Actions):

| Tag | Package | pub.dev tag pattern |
|-----|---------|---------------------|
| `v1.2.1` | `dart_ipfs` (umbrella, repo root) | `v{{version}}` |
| `core-v1.2.3` | `packages/dart_ipfs_core` | `core-v{{version}}` |
| `quic-v0.2.1` | `packages/dart_ipfs_quic` | `quic-v{{version}}` |

pub.dev OIDC publishing rejects tags that do not match the package's
pattern, so a bare `v*` tag can never publish `dart_ipfs_core`.

**Ordering is fail-closed**: `publish-quic` requires `publish-core`, and
`publish-umbrella` requires both. An upstream publish failure blocks
everything downstream — the umbrella can never ship with an
unresolvable dependency floor.

When a release bumps `dart_ipfs_core` or `dart_ipfs_quic`, publish the
sub-package **before** the umbrella tag, because the umbrella's pubspec
floor (`dart_ipfs_core: ^x.y.z`) must already resolve on pub.dev:

1. `git tag core-v1.2.3 && git push origin core-v1.2.3` — wait for the
   `Publish dart_ipfs_core` job to succeed.
2. `git tag v1.2.1 && git push origin v1.2.1` for the umbrella.

Tag pushes are idempotent: each publish job first checks whether the
package version already exists on pub.dev and skips the upload if so.
A `workflow_dispatch` run with `target=core|quic|umbrella|all` can also
drive a release without a tag push.

---

## 🧹 GitHub Hygiene Checklist

Rules for keeping the repository "squeaky clean".

### Weekly Checks
- [ ] **Issues Triage**:
    - Close stale issues (`> 30 days` inactive) with a polite message.
    - Label new issues (`bug`, `enhancement`, `question`).
    - Add `good first issue` to simple tasks for contributors.
- [ ] **Pull Requests**:
    - Review open PRs (don't let them rot).
    - Ensure CI/CD passes before merging.
    - **Squash & Merge** is preferred for cleaner history.
- [ ] **Security**:
    - Check "Security" tab for Dependabot alerts.
    - Merge non-breaking dependency updates immediately.

### Monthly Checks
- [ ] **Tag Verification**:
    - Compare `git tag` with GitHub Releases. Ensure parity.
    - **Fix**: Detect and remove any "stale" tags pointing to old commits.
- [ ] **Discussions**:
    - Mark answered questions as "Answered" to keep the "Unanswered" queue clean.
    - Convert actionable discussions into Issues.
- [ ] **Wiki/Pages**:
    - Walkthrough the `docs/index.md` links to ensure no 404s.

### Emergency Protocol
- **Accidental Keys Commit**: 
    - Rotate keys immediately.
    - Use BFG Repo-Cleaner if necessary (extreme cases).
- **Broken Master**:
    - Revert the offending commit immediately (`git revert <sha>`).
    - Do not `force push` to fix master unless absolutely necessary and coordinated.

---

## 🛠 Operational Rules

### 1. Dependency Management (Vendoring)
If you must modify a dependency (e.g., `p2plib`) locally:
1. Place it in `packages/<package_name>`.

2. Add `dependency_overrides` in `pubspec.yaml`.
3. **CRITICAL**: Remove the `.git` directory from the vendored package (`rm -rf packages/p2plib/.git`).
4. Commit the entire folder as source code.

### 1a. The `ipfs_libp2p` Fork

The project depends on `ipfs_libp2p` (a `dart_libp2p` fork published to
pub.dev) rather than upstream directly. The fork carries changes upstream
has not absorbed: stream write deadlines, respond-first close semantics,
session-stream support, and assorted interop fixes that Kubo/Helia
require. Upstream `dart_libp2p` 1.x is **not** a drop-in replacement.

Maintenance cadence:

- **On every upstream `dart_libp2p` release**: review the upstream diff
  against the fork and selectively merge anything relevant (protocol
  fixes, resilience, spec compliance). Keep a short running list of
  fork-only deltas so the review stays cheap.
- **Before each `dart_ipfs` release**: confirm the pinned `ipfs_libp2p`
  floor resolves on pub.dev and that no unmerged upstream fix affects a
  code path this release touches.
- **Periodically**: propose fork deltas upstream where they are generic
  (deadlines, framing bugs) so the divergence shrinks over time. If
  upstream absorbs everything, retire the fork.

### 2. CI/CD Safety
- **Never retag** an existing version on remote if CI/CD has already run. Bump the patch version instead (e.g., `v1.2.0` -> `v1.2.1`).
- Ensure `pubspec.yaml` dependencies are strictly versioned or overridden correctly to prevent build failures on fresh clones.

### 3. Feature Management
- **Dashboard Parity**: When adding a core feature (like Gateway Mode), immediately implement it in:
    - `IPFSNode` (Core)
    - `NodeService` (Flutter Integration)
    - `CLI` (Terminal Interface)
- **Documentation**: New public methods MUST have Effective Dart (`///`) documentation before merging.

### 4. Protobuf Compatibility Management
- **Version Updates**: When updating protobuf dependency:
  1. Check for breaking changes in protobuf changelog
  2. Update `PROTOBUF_COMPATIBILITY.md` with migration notes
  3. Verify all well-known type imports use `package:protobuf/well_known_types/`
  4. Run comprehensive test suite: `dart test`
  5. Update CHANGELOG.md with compatibility status
- **Import Patterns**: Never use local copies of well-known types (`any.pb.dart`, `timestamp.pb.dart`)
- **Testing**: Always test with both protobuf 6.0.0+ and verify backward compatibility
