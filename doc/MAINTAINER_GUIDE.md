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
Update the version number (e.g., `1.2.1`) in **ALL** of the following files:
- [ ] `pubspec.yaml` (`version:`)
- [ ] `CHANGELOG.md` (Add new section `## [1.2.1] - YYYY-MM-DD`)
- [ ] `README.md` (Update any "Installation" or "Usage" references)
- [ ] `ROADMAP.md` (Update "Current Version" header and status)
- [ ] `doc/PROTOBUF_COMPATIBILITY.md` (Update if protobuf version changes)

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

---

## 🧹 GitHub Hygiene Checklist

Rules for keeping the repository "squeaky clean".

### Weekly Checks
- [ ] **Issues Triage**:
    - Close stale issues (>30 days inactive) with a polite message.
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
