---
description: Standard Operating Procedure for releasing new versions of dart_ipfs
---

# Release Workflow

This workflow ensures that every release is stable, compliant with pub.dev standards, and successfully passes CI/CD pipeline checks _before_ a tag is pushed.

## 1. Pre-Release Verification (Local)

**CRITICAL**: You MUST perform these steps locally before creating any release commit.

### A. Version Consistency

Ensure `pubspec.yaml` version matches `CHANGELOG.md` entry.

```bash
grep "version:" pubspec.yaml
grep "## \[" CHANGELOG.md | head -n 1
```

### B. Clean & Format

Ensure the codebase is clean and formatted.

```bash
dart format .
git diff --exit-code # Fail if format made changes
```

### C. Static Analysis (Strict)

Pub.dev is stricter than standard CI. Ensure `lib/` and `test/` are spotless.

```bash
# Analyze library and test code (matches CI)
dart analyze lib test
```

> **Rule**: If `dart analyze` shows ANY `info`, `warning`, or `error` (e.g., `avoid_print`, `unused_import`), you **MUST** fix it. Do not proceed.

### D. Documentation Generation

Ensure documentation generates successfully, as the `Docs` workflow will fail otherwise.

```bash
dart doc .
```

### E. Test Suite

Run the full test suite.

```bash
dart test -r compact
```

### F. Pub Publish Dry-Run (The "Golden Rule")

Simulate the publish process. **Note**: Your git working directory must be clean (no uncommitted changes) for this to accurately reflect a release.

```bash
dart pub publish --dry-run
```

> **Stop**: If this command returns _any_ warnings or errors, the specific release workflow WILL FAIL. Fix them first.

---

## 2. Release Execution

Once Pre-Release Verification is green:

### A. Version Bump

1.  Update `version` in `pubspec.yaml`.
2.  Update `CHANGELOG.md` with:
    - Header: `## [X.Y.Z] - YYYY-MM-DD`
    - Description of changes.

### B. Commit Release

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: Release vX.Y.Z"
```

### C. Tagging

Create the version tag. This triggers the CI pipeline.

```bash
git tag vX.Y.Z
```

### D. Push

Push the commit and the tag.

```bash
git push origin master
git push origin vX.Y.Z
```

---

## 3. Post-Release Verification

1.  **Monitor CI**: Watch the [GitHub Actions](https://github.com/jxoesneon/IPFS/actions) `Publish` workflow.
2.  **Verify Pub.dev**: Check [pub.dev/packages/dart_ipfs](https://pub.dev/packages/dart_ipfs) (may take 15 mins to appear).
3.  **Announce**: Notify stakeholders/users (if applicable).

---

## Troubleshooting

### "Dry Release" Failed?

- **Unused Imports**: Remove them.
- **Print Statements**: Replace `print` with `logger` or remove.
- **File too large**: Check `.pubignore` or `.gitignore`.

### CI Failed after Tagging?

1.  **Delete Remote Tag**: `git push --delete origin vX.Y.Z`
2.  **Delete Local Tag**: `git tag -d vX.Y.Z`
3.  **Fix Issue**: Make new commits to fix the error.
    - _Formatting failed?_ Run `dart format .` and commit.
    - _Tests failed?_ Run `dart test` locally to reproduce.
4.  **Re-tag**: `git tag vX.Y.Z`
5.  **Re-push**: `git push origin vX.Y.Z`
