# dart_ipfs Package Modularization (Phase 1) Specification

**Document ID:** `MODULARIZATION_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2.x / release-candidate (not a v2.2.0 blocker)  
**Status:** Deferred by Council of Five decision (2026-07-09)  
**Council Priority:** P1 MODIFIED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.5

---

## 1. Goal and Scope

The goal of this specification is to begin transforming `dart_ipfs` from a single umbrella package into a maintainable monorepo. Phase 1 extracts only the **stable core primitives** into a new package named `dart_ipfs_core` under `packages/`. Protocol and service layers remain in the umbrella package until they stabilize, and the umbrella package continues to re-export all public APIs so existing consumers are not broken.

Scope for v2.2.x:

- Create a `packages/` monorepo scaffold.
- Extract `dart_ipfs_core` containing stable data primitives: CID, multibase, multicodec, multihash, block abstractions, blockstore interfaces/implementations, common codecs, and key utilities.
- Maintain backward-compatible umbrella re-exports from `package:dart_ipfs/dart_ipfs.dart`.
- Adopt workspace tooling: **Melos** is the recommended choice for bootstrapping, versioning, and cross-package testing. Native Dart workspaces (`pubspec_overrides.yaml`) may be used only if the team explicitly opts out of Melos.
- Document the monorepo layout and stability tiers.
- This work is intentionally **not a v2.2.0 release blocker**; it ships in the v2.2.x / release-candidate window once core interfaces are stable.

Out of scope for v2.2:

- Extracting protocol packages (Bitswap, DHT, libp2p) or service packages (gateway, RPC, MFS, pinning).
- Converting the umbrella package into a pure facade.
- Creating a public registry or workspace website.

---

## 2. Official References

- Dart package layout conventions: https://dart.dev/tools/pub/package-layout
- Dart pubspec reference: https://dart.dev/tools/pub/pubspec
- Dart workspaces / `pubspec_overrides.yaml`: https://dart.dev/tools/pub/workspaces
- Melos monorepo tool: https://melos.invertase.dev/
- Effective Dart (style and API design): https://dart.dev/effective-dart
- Dart publishing: https://dart.dev/tools/pub/publishing
- Version constraints and semver: https://dart.dev/tools/pub/dependencies

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Package structure | Single umbrella package with `lib/` at the repository root. | Core primitives cannot be consumed without pulling the full protocol/service stack. |
| Monorepo tooling | None. | Cross-package development and dependency management are not supported. |
| Re-exports | N/A (single package). | Once core is extracted, umbrella re-exports must be added to maintain compatibility. |
| Publish surface | Entire package is published. | Consumers depend on implementation details in `lib/src/` because there is no smaller, stable core package. |

Key files affected:

- `pubspec.yaml` (root) — add a dependency on `dart_ipfs_core`.
- `lib/dart_ipfs.dart` — add re-exports from `dart_ipfs_core`.
- Existing core modules under `lib/src/` that will move:
  - `lib/src/core/cid/` (CID, multibase, multicodec, multihash)
  - `lib/src/core/block/` (Block, BlockStore interfaces, in-memory and fs stores)
  - `lib/src/core/codec/` (DAG-CBOR, DAG-JSON, raw)
  - `lib/src/core/crypto/` (key utilities, hashing helpers)

---

## 4. Target State / Requirements

### 4.1 Monorepo Layout

```
packages/
├── dart_ipfs_core/
│   ├── lib/
│   │   ├── dart_ipfs_core.dart        # public API barrel
│   │   └── src/
│   │       ├── cid/                   # CID v0/v1, multibase, multicodec
│   │       ├── multibase/
│   │       ├── multicodec/
│   │       ├── multihash/
│   │       ├── block/                 # BlockStore interface, in-memory store, fs store
│   │       ├── codec/                 # common codecs (dag-cbor, dag-json, raw)
│   │       ├── crypto/                # key utilities, hashing helpers
│   │       └── data_structures/       # small immutable helpers (not protocol logic)
│   ├── pubspec.yaml
│   ├── README.md
│   ├── analysis_options.yaml
│   └── test/                          # unit tests for each module
├── dart_ipfs_core_compat/ (optional)
│   └── README.md explaining umbrella re-exports
├── melos.yaml                         # workspace root (optional, P1)
pubspec.yaml                           # umbrella package (remains the published package)
```

### 4.2 What Moves Into `dart_ipfs_core`

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

### 4.3 Umbrella Re-Exports

The root `lib/dart_ipfs.dart` must continue to export all public APIs that consumers currently use. For modules moved to `dart_ipfs_core`, re-export from the core package:

```dart
export 'package:dart_ipfs_core/dart_ipfs_core.dart'
    show CID, Multibase, Multihash, Block, BlockStore, ...;
```

- Only imports of `package:dart_ipfs/dart_ipfs.dart` are part of the backward-compatibility promise.
- Deep imports (`package:dart_ipfs/src/...`) are **not** guaranteed to remain stable. A deprecation notice must be added to `CHANGELOG.md`.

### 4.4 Dependency Direction

- `dart_ipfs_core` has **no** dependency on the umbrella package.
- The umbrella package depends on `dart_ipfs_core` (path dependency during development; published version constraint after release).
- No other `packages/` entries are created in v2.2 unless explicitly approved by a new Council deliberation.

### 4.6 Versioning Policy

- `dart_ipfs_core` follows the umbrella package version exactly (**single release train**). Both packages share a `CHANGELOG.md` entry and a single semver tag.
- The umbrella package depends on the published version of `dart_ipfs_core` after release; during development it uses a Melos workspace or path override.

### 4.7 Consumer Rationale and Migration

- The primary consumers of `dart_ipfs_core` in the v2.2 window are in-repo plugin examples and the future `dart_ipfs_cli` package (v3.0). This justifies the extraction without over-engineering the split.
- Deep imports (`package:dart_ipfs/src/...`) are deprecated in v2.2.0 and will be removed in v3.0.0.
- Provide a migration table:

| Old import | New import |
|------------|------------|
| `package:dart_ipfs/src/core/cid.dart` | `package:dart_ipfs/dart_ipfs.dart` (public re-export) or `package:dart_ipfs_core/dart_ipfs_core.dart` |
| `package:dart_ipfs/src/core/data_structures/block.dart` | `package:dart_ipfs/dart_ipfs.dart` or `package:dart_ipfs_core/dart_ipfs_core.dart` |
| `package:dart_ipfs/src/core/crypto/ed25519_signer.dart` | `package:dart_ipfs_core/dart_ipfs_core.dart` |

---

## 5. Detailed Acceptance Criteria

1. `dart run melos bootstrap` (or `dart pub get` in each package) succeeds.
2. `dart test` in `packages/dart_ipfs_core` passes with >=80% line coverage.
3. Root `dart test` still passes with all existing tests using the umbrella re-exports.
4. `dart pub publish --dry-run` in `packages/dart_ipfs_core` reports no errors.
5. README documents the monorepo layout and stability tiers.
6. All public classes previously available from `package:dart_ipfs/dart_ipfs.dart` remain available after the move.
7. No new dependencies are added from `dart_ipfs_core` back to the umbrella package.
8. A dependency graph check (e.g., `dart run dependency_validator`) reports zero forbidden dependencies from `dart_ipfs_core` back to the umbrella package.
9. The `CHANGELOG.md` warns that deep `lib/src/` imports are deprecated and will be removed in v3.0.0.
10. `analysis_options.yaml` is consistent across the root package and `dart_ipfs_core`.
11. Documentation in `doc/monorepo.md` (or equivalent) explains how to add packages in future phases.
12. A consumer test proves that `package:dart_ipfs/dart_ipfs.dart` and `package:dart_ipfs_core/dart_ipfs_core.dart` expose the same CID/multihash API for the moved classes.

---

## 6. Security Considerations

- Do not include private keys, example secrets, or repository credentials in the published `dart_ipfs_core` package.
- The core package must expose only stable, safe APIs. Cryptographic helpers should be clearly marked and should not encourage misuse (e.g., generating weak keys, bypassing signatures).
- Publishing must be done with a trusted publisher account and two-factor authentication enabled on pub.dev.
- Version constraints should be conservative to prevent accidental breaking upgrades for consumers.
- If Melos is used, ensure that local path overrides are not accidentally published in `pubspec.yaml`.

---

## 7. Testing Strategy

### 7.1 Unit Tests in Core Package

- Move existing unit tests for CID, multibase, multicodec, multihash, block, blockstore, codecs, and crypto into `packages/dart_ipfs_core/test/`.
- Add new tests where coverage is below 80%.
- Ensure deterministic, hermetic tests that do not depend on network or filesystem state unless explicitly required.

### 7.2 Umbrella Re-Export Tests

- Keep existing root tests in place; they validate that the umbrella re-exports still expose the expected APIs.
- Add a dedicated `test/umbrella_reexports_test.dart` that verifies the moved classes are still importable from `package:dart_ipfs/dart_ipfs.dart`.

### 7.3 Workspace Tooling Tests

- Verify `dart pub get` succeeds in both `packages/dart_ipfs_core` and the root.
- If using Melos, verify `melos bootstrap` and `melos test` succeed.
- Verify `dart pub publish --dry-run` in the core package has no warnings or errors.

### 7.4 CI Pipeline

- Extend `.github/workflows/lint.yml` to run tests in both `packages/dart_ipfs_core` and the root.
- Add a check that the root package still depends on the published version constraint (not a path override) in release branches, or that `pubspec_overrides.yaml` is ignored by publishing.

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - Stable core modules identified in the table above.
  - A clear public API surface for `lib/dart_ipfs.dart`.
- **Order:** Modularization is a P1 item and is part of the v2.2.x / release-candidate phase. It should not delay the v2.2.0 P0 release. The workspace tooling decision (Melos) is made before any files are moved.
- **Downstream consumers:**
  - `PLUGINS_SPEC.md` — the plugin API depends on stable `BlockStore` and key interfaces from `dart_ipfs_core`.
  - `CLI_SPEC.md` and `DOCKER_SPEC.md` — these should remain functional regardless of whether modularization lands.

---

## 9. Backward Compatibility Notes

- `package:dart_ipfs/dart_ipfs.dart` remains the stable public API.
- Deep imports (`package:dart_ipfs/src/...`) are **not** part of the compatibility contract and may break during v2.2. A `CHANGELOG.md` warning is required.
- After extracting `dart_ipfs_core`, the same classes (CID, Multibase, Multihash, Block, BlockStore, etc.) remain available via the umbrella re-export.
- Existing library consumers who use only public exports will not need code changes.
- The deprecation timeline:

| Item | Deprecated In | Removed In |
|------|---------------|------------|
| Deep `lib/src/` imports | v2.2.0 | v3.0.0 |
| Single-package monorepo | v2.2.0 | v3.0.0 (full package split) |

- In v3.0, additional protocol and service packages may be extracted, and the umbrella package may become a pure facade. Phase 1 intentionally avoids that scope to minimize disruption.

---

## 10. Council of Five Decision — 2026-07-09

### 10.1 Initial deliberation

A first Council of Five deliberation was held for WP-07 (core modularization redesign). The proposal presented three options:

1. Extend `dart_ipfs_core` CID API and migrate incrementally.
2. Defer WP-07 and keep the monolithic core.
3. Create a compatibility adapter/extension layer.

| Council Member | Option 1 | Option 2 | Option 3 | Preferred |
|----------------|----------|----------|----------|-----------|
| Coherence      | 6        | 8        | 4        | Option 2  |
| Capability     | 7        | 3        | 4        | Option 1  |
| Safety         | 6        | 9        | 4        | Option 2  |
| Efficiency     | 4        | 9        | 3        | Option 2  |
| Evolution      | 8        | 3        | 5        | Option 1  |
| **Total**      | **31**   | **32**   | **20**   |           |

**Initial verdict:** Option 2 — Defer WP-07 indefinitely and keep the monolithic core (3 of 5 votes).

### 10.2 Strategic research and final decision

Following the initial verdict, an agentic-loop research phase investigated how other IPFS implementations modularize, what the Dart ecosystem expects, whether any downstream consumer needs `dart_ipfs_core`, and where the official specs place the CID/protobuf boundary. The findings were:

- **Kubo, Helia, rust-ipfs, js-ipfs, and go-libp2p** all keep CID/multihash/multibase in protocol-agnostic packages with **no** protobuf dependency.
- The official **CID specification** defines only binary and multibase-string encodings. Protobuf is a **protocol container**, not a CID encoding.
- The reference `go-cid` library exposes `Bytes()`, `Cast()`, `Decode()`, `String()` — but **no** `fromProto()`/`toProto()`.
- `dart_ipfs` has **0 pub.dev dependents**; no GitHub issues, discussions, StackOverflow questions, Reddit threads, or blogs request modularization or core-only imports.
- The Dart/Flutter IPFS community overwhelmingly uses **HTTP API clients**, not full nodes.

A second Council of Five deliberation was convened with three revised options:

- **Option A:** Defer WP-07 indefinitely (status quo).
- **Option B:** Redesign WP-07 into a proper spec-aligned modularization (protobuf-free core, protobuf methods in protocol packages).
- **Option C:** Abandon WP-07 and redirect effort to adoption (docs, examples, HTTP API wrapper, community outreach).

| Council Member | Option A | Option B | Option C | Preferred |
|----------------|----------|----------|----------|-----------|
| Coherence      | 6        | 4        | 9        | **C**     |
| Capability     | 6        | 3        | 9        | **C**     |
| Safety         | 6        | 3        | 8        | **C**     |
| Efficiency     | 8        | 2        | 9        | **C**     |
| Evolution      | 3        | 7        | 8        | **C**     |
| **Total**      | **29**   | **19**   | **43**   |           |

**Final verdict:** Unanimous — **Option C**. WP-07 is abandoned as originally specified. The project will pursue an **adoption-first strategy**.

### 10.3 Rationale

1. The original WP-07 plan would have moved protobuf-specific CID methods into `dart_ipfs_core`, violating the boundary that every other IPFS implementation respects.
2. A proper spec-aligned modularization (Option B) is architecturally correct but high-risk and premature: it would touch ~43 source files and ~260 test files with zero current beneficiaries.
3. `dart_ipfs` has no downstream consumers today. The highest-leverage use of effort is to build adoption, not to refactor for hypothetical users.
4. The Dart/Flutter ecosystem's actual demand is for lightweight HTTP API clients, not full IPFS nodes.

### 10.4 Conditions for revisiting modularization

Reconsider WP-07 only when one or more of the following are true:

- `dart_ipfs` reaches **≥5 pub.dev dependents** (or a similarly concrete adoption signal).
- A downstream package explicitly requests protocol-agnostic CID/multihash/multibase primitives without the full IPFS protocol stack.
- The project has the resources to execute Option B correctly: a protobuf-free `dart_ipfs_core` and protobuf methods in protocol-specific packages.

If modularization is revisited, the original WP-07 design is **discredited**. The new design must follow the go-cid / js-multiformats / rust-cid pattern:

- `dart_ipfs_core` contains only protocol-agnostic primitives: `CID.fromBytes()`, `CID.toBytes()`, `CID.fromString()`, `CID.toString()`, `version`, `codec`, `multihash`, plus Multihash/Multibase/Multicodec and Block/BlockStore interfaces.
- `CID.fromProto()` / `CID.toProto()` are **not** in core. They live in protocol-specific packages or remain in the umbrella as convenience helpers.

### 10.5 Decision record

Full Council context, research synthesis, and member rationales are recorded in the Obsidian vault:

- `ciel/kg/decisions/2026-07-09-wp07-council-decision.md` (initial deliberation)
- `ciel/kg/decisions/2026-07-09-wp07-research-synthesis.md`
- `ciel/kg/decisions/2026-07-09-wp07-final-decision.md`
