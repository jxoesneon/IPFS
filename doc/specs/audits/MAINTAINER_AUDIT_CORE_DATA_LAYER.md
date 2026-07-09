# Project Review — Core Data Layer

**Audit date:** 2026-06-25  
**Audited specs:**

1. `doc/specs/features/CAR_FORMAT_SPEC.md`
2. `doc/specs/features/UNIXFS_SPEC.md`
3. `doc/specs/features/DAG_CBOR_SPEC.md`
4. `doc/specs/features/DAG_JSON_SPEC.md`
5. `doc/specs/features/IPLD_SELECTORS_SPEC.md`

**Auditor lenses:** Coherence, Capability, Safety, Efficiency, Evolution.  
**Verdict scale:** 0-10 per lens. Overall verdict PASS / CONDITIONAL / DEFER / REJECT.

---

## Executive Summary

All five specs are technically sound, well-researched, and aligned with the dart_ipfs v2.0 goal of Kubo/Helia parity. However, every spec contains outdated file-path references and stale current-state descriptions relative to the actual repository layout (`lib/src/core/...` rather than the older `lib/src/codec/...` tree). None are rejected or unsafe, but none can be approved unconditionally until the paths and current-state sections are reconciled with the codebase. The maintainer decision for every spec is **CONDITIONAL**.

| Spec | Coherence | Capability | Safety | Efficiency | Evolution | Verdict |
|---|---|---|---|---|---|---|
| CAR_FORMAT_SPEC.md | 5 | 9 | 8 | 8 | 9 | **CONDITIONAL** |
| UNIXFS_SPEC.md | 6 | 9 | 8 | 8 | 9 | **CONDITIONAL** |
| DAG_CBOR_SPEC.md | 6 | 9 | 8 | 8 | 9 | **CONDITIONAL** |
| DAG_JSON_SPEC.md | 6 | 7 | 8 | 7 | 7 | **CONDITIONAL** |
| IPLD_SELECTORS_SPEC.md | 6 | 9 | 8 | 7 | 9 | **CONDITIONAL** |

---

## Cross-Cutting Findings

The following issues appear in multiple specs and should be resolved in a single alignment pass before any implementation begins.

### 1. Pervasive file-path drift

Every spec references a `lib/src/codec/...` tree that no longer exists. The actual locations are:

| Spec claim | Actual location |
|---|---|
| `lib/src/codec/advanced_codecs.dart` (CAR spec line 51) | `lib/src/core/ipld/codecs/advanced_codecs.dart` |
| `lib/src/codec/cbor/EnhancedCBORHandler.dart` (CAR spec line 56; DAG-CBOR spec line 51) | `lib/src/core/cbor/enhanced_cbor_handler.dart` |
| `lib/src/codec/dag_json_codec.dart` (DAG-JSON spec line 52) | `lib/src/core/ipld/dag_json_codec.dart` |
| `lib/src/codec/standard_codecs.dart` (DAG-JSON spec line 53) | `lib/src/core/ipld/codecs/standard_codecs.dart` |
| `lib/src/core/ipld/ipld_handler.dart` (Selectors spec line 53) | `lib/src/core/ipfs_node/ipld_handler.dart` |

References to `lib/src/codec/...` will mislead implementers and break any tooling that relies on the spec paths. Each spec must be updated to reference the actual source files.

### 2. Current-state descriptions are partially inaccurate

- **CAR:** The spec correctly identifies that `CarCodec` is protobuf-based and non-standard, but the `CAR` class in `lib/src/core/data_structures/car.dart` is the dominant in-memory CAR abstraction, not the `CarCodec` in `advanced_codecs.dart`. The spec should address whether the existing `CAR`, `CarHeader`, and `CarIndex` classes are replaced, renamed, or migrated.
- **UnixFS:** The spec says `lib/src/core/unixfs/` contains directory construction and path resolution logic, but the directory only contains `unixfs_builder.dart`, which implements file chunking and nothing else. The path is right; the claim about what is inside is wrong.
- **Selectors:** The spec claims `GraphsyncHandler` cannot attach blocks based on a selector. In reality, `lib/src/protocols/graphsync/graphsync_handler.dart` already calls `_ipld.executeSelector` and attaches the resulting blocks. The problem is not attachment; it is that the selector model is custom and non-interoperable.

### 3. Two competing `IPLDCodec` interfaces exist

The DAG-JSON spec does not acknowledge that `lib/src/core/ipld/codecs/ipld_codec.dart` (used by `standard_codecs.dart`) and `lib/src/core/ipld/dag_json_codec.dart` define different `IPLDCodec` abstractions. Consolidation requires merging or deprecating one interface, not just picking one file. This is a dependency that should be surfaced in the DAG-JSON spec and resolved before implementation.

### 4. Protobuf-generated `IPLDNode` vs. the spec's clean data model

The specs assume a clean `IPLDNode` abstraction that can be reshaped freely. The actual codebase uses `package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart`, a protobuf-generated model with mutable fields, `Kind` enum, and `Int64` values. Any new codec API must either map cleanly onto this generated model or come with a migration plan. None of the specs address this constraint.

---

## 1. CAR_FORMAT_SPEC.md

### Scores

| Lens | Score | Rationale |
|---|---|---|
| Coherence | 5 | Direction is correct, but paths are wrong and the relationship with the existing `CAR` class in `data_structures/car.dart` is undefined. |
| Capability | 9 | Standard CAR v1/v2 is a genuine, non-redundant capability required for gateway, MFS, and GraphSync. |
| Safety | 8 | Strong untrusted-input handling, varint limits, max block sizes, identity CID warnings, and index validation. |
| Efficiency | 8 | Streaming, zero-copy CARv2 extraction, and optional indexing are appropriately scoped. |
| Evolution | 9 | CAR v1/v2 interoperability is a hard prerequisite for Kubo/Helia parity. |

**Verdict: CONDITIONAL**

### Strengths

- Accurately captures the official CAR v1 and v2 wire formats, including the 11-byte pragma, 40-byte header, and `IndexSorted` / `MultihashIndexSorted` index payloads.
- Acceptance criteria are concrete and testable: Kubo import/export, CAR v2 round-trip, legacy removal, malformed-input rejection, and index correctness.
- Security section correctly identifies the main attack surfaces: malicious varints, oversized blocks, missing roots, and index/data payload mismatches.
- Dependency ordering is sound: DAG-CBOR must land first, then CAR, then UnixFS and GraphSync.

### Weaknesses

- **Line 51:** `lib/src/codec/advanced_codecs.dart` does not exist. The actual `CarCodec` is in `lib/src/core/ipld/codecs/advanced_codecs.dart`.
- **Line 56:** `lib/src/codec/cbor/EnhancedCBORHandler.dart` does not exist. The actual file is `lib/src/core/cbor/enhanced_cbor_handler.dart`.
- **Line 113:** `Future<CID?> findCID(CID cid)` is declared as returning a CID, but the description says it returns an offset. The return type should be `Future<int?>` or the description should be corrected.
- **Line 126-128:** `BlockStore.exportCar` and `BlockStore.importCar` do not exist in `lib/src/core/data_structures/blockstore.dart`. The spec should reference the existing `BlockStore` interface and show how the new helpers fit in.
- **Line 128:** The trustless gateway bullet incorrectly lists `application/vnd.ipfs.ipns.record` alongside `application/vnd.ipld.car`. The IPNS record MIME type is not a CAR output and should be removed from the CAR spec.
- The spec does not clarify whether the existing `CAR`, `CarHeader`, and `CarIndex` classes in `lib/src/core/data_structures/car.dart` are deleted, renamed, or refactored. This creates an undefined collision with the proposed `CarReader`/`CarWriter` API.

### Recommendations

1. Update all file paths to the `lib/src/core/...` tree.
2. Add a "Current Codebase Map" subsection showing the old CAR classes and the new target classes, with a migration decision for each.
3. Fix the `findCID` return type or description.
4. Remove the IPNS record MIME type from the CAR gateway bullet.
5. Define the exact fate of the protobuf `CarProto` and the generated `car.pb.dart` code: deletion, deprecation, or restricted internal use.

### Missing Research / Acceptance Criteria

- A specific acceptance test that compares the binary bytes of a CAR v2 index produced by dart_ipfs against `go-car/v2` for the same blocks.
- A migration note for any consumers of the existing `CAR` protobuf class.
- Clarification of whether CAR v2 with `Characteristics` bitfield non-zero values is out of scope or rejected.

---

## 2. UNIXFS_SPEC.md

### Scores

| Lens | Score | Rationale |
|---|---|---|
| Coherence | 6 | The `lib/src/core/unixfs/` path is correct, but the description of existing functionality is wrong. The P0/P1 split is sensible. |
| Capability | 9 | UnixFS directories, files, HAMT sharding, and symlinks are essential for gateway, MFS, and import/export. |
| Safety | 8 | Path traversal, symlink cycles, DAG cycles, and resource limits are all addressed. |
| Efficiency | 8 | P0 focuses on basic directories and files; HAMT and symlinks are deferred to P1. |
| Evolution | 9 | Correct UnixFS is a cornerstone of Kubo/Helia parity. |

**Verdict: CONDITIONAL**

### Strengths

- Correctly identifies the core UnixFS requirements: DAG-PB node construction, cumulative `Tsize`, file chunking, and path resolution.
- P0/P1 split is practical: basic directories and files first, HAMT sharding and symlinks second.
- Security considerations are comprehensive, especially path traversal, symlink cycles, and DAG cycle detection.
- Acceptance criteria include CID parity with Kubo for directories and files, which is the right success metric.

### Weaknesses

- **Line 48:** The spec claims `lib/src/core/unixfs/` contains directory construction and path resolution logic. It only contains `unixfs_builder.dart`, which builds file DAGs and does not implement directories, path resolution, or HAMT.
- **Line 49:** The `Tsize` gap is described for directories, but the existing `UnixFSBuilder` in `unixfs_builder.dart` uses `block.data.length` for chunk link sizes, not the cumulative serialized size of the subtree. This is also a `Tsize` bug that affects file root CID parity.
- **Line 116-120:** The `Tsize` formula is ambiguous. `serialized_size(link.hash)` should be clarified as the serialized byte size of the block referenced by the link, not the CID. The spec's formula is close but could be interpreted as the CID size.
- **Line 140:** The HAMT fanout threshold is stated as 256, but the spec does not explicitly require a configurable threshold or acceptance tests for the exact Kubo default. Kubo/Helia may vary; the spec should pin the test target.
- The spec does not specify whether UnixFS files and directories should use CIDv0 or CIDv1. Kubo defaults to CIDv1 for directory nodes and most modern exports. CID version choice affects CID parity and should be an acceptance criterion.
- The spec does not mention that the existing `DagPbCodec` in `lib/src/core/ipld/codecs/standard_codecs.dart` sets `mtime: DateTime.now().millisecondsSinceEpoch` on `MerkleDAGNode`, which is non-deterministic and would break CID parity if used for UnixFS directories.

### Recommendations

1. Correct the current-state description: only `unixfs_builder.dart` exists, and it only handles file chunking.
2. Add a concrete `Tsize` definition and acceptance tests that compare the exact byte values against Kubo-generated fixtures.
3. Explicitly require CIDv1 for UnixFS directories (and chunked file roots) to match modern Kubo defaults, or make the version a configurable parameter with Kubo as the default.
4. Address the non-deterministic `mtime` in `DagPbCodec` / `MerkleDAGNode` before UnixFS CID parity can be achieved.
5. Add a test acceptance criterion for HAMT sharding threshold parity with Kubo.

### Missing Research / Acceptance Criteria

- Reference to the actual `dag_pb` and `unixfs_pb` generated protobuf files used by the existing builder.
- A fixture-based test that imports a small directory from Kubo and re-exports it with identical root CID and CAR bytes.
- Explicit handling of empty directories and single-file directories, which are common edge cases.

---

## 3. DAG_CBOR_SPEC.md

### Scores

| Lens | Score | Rationale |
|---|---|---|
| Coherence | 6 | The required changes are correct, but the file path is wrong and the new API surface is not reconciled with the existing `DagCborCodec`. |
| Capability | 9 | Spec-compliant DAG-CBOR is foundational for CAR, selectors, and CID parity. |
| Safety | 8 | Strong parser limits, strict decoding, tag validation, and deterministic hashing requirements. |
| Efficiency | 8 | Focused on the codec and its canonical behavior; no scope creep. |
| Evolution | 9 | DAG-CBOR is a prerequisite for nearly every v2.0 interoperability goal. |

**Verdict: CONDITIONAL**

### Strengths

- Accurately captures the official DAG-CBOR rules: tag 42 CIDs with `0x00` prefix, no tag 45 for bytes, canonical map ordering, big integers via tags 2/3, and strict decoding.
- Correctly identifies the legacy tag 45 behavior in `EnhancedCBORHandler` as the primary interoperability blocker.
- Acceptance criteria are clear and include cross-codec fixture parity, legacy removal, and CID parity.
- Dependency ordering is correct: DAG-CBOR is a prerequisite for CAR, selectors, and GraphSync.

### Weaknesses

- **Line 51:** `lib/src/codec/cbor/EnhancedCBORHandler.dart` does not exist. The actual file is `lib/src/core/cbor/enhanced_cbor_handler.dart`.
- **Line 95-96:** The proposed `encodeDagCbor` / `decodeDagCbor` / `computeCidDagCbor` functions are not reconciled with the existing `DagCborCodec` in `lib/src/core/ipld/codecs/standard_codecs.dart`, which already exposes `identifier = 'dag-cbor'`, `encode(IPLDNode)`, and `decode(Uint8List)` returning `Future`.
- **Line 98:** The spec requires the codec to expose `codecCode = 0x71` and `name = 'dag-cbor'`. The existing `IPLDCodec` interface only has `identifier`. The interface change must be planned and documented.
- **Line 77:** The wording about shortest float representation is slightly vague. It should explicitly state whether the encoder must produce the shortest IEEE 754 form that preserves the value, per the IPLD DAG-CBOR canonical requirements.
- The spec does not address how the new codec will interact with the protobuf-generated `IPLDNode` model, which uses mutable fields and `Int64` for integers.

### Recommendations

1. Update the file path to `lib/src/core/cbor/enhanced_cbor_handler.dart`.
2. Decide whether the new API is a thin wrapper around the existing `DagCborCodec` or a replacement, and document the transition.
3. Update the `IPLDCodec` interface (or create a new `DagCborCodec` subclass) to expose `codecCode` and `name` consistently.
4. Add a specific acceptance test that runs the official IPLD DAG-CBOR cross-codec fixtures and compares CIDs against go-ipld-prime.
5. Clarify float canonicalization: require the shortest form that preserves value, and add a fixture test for it.

### Missing Research / Acceptance Criteria

- Reference to the `cbor` package version in `pubspec.yaml` and any customizations needed to enforce DAG-CBOR subset rules.
- A test that verifies the old tag 45 bytes are rejected on decode, as mentioned in the security section.
- Explicit acceptance criterion that DAG-CBOR nodes used as CAR headers round-trip through Kubo/Helia without CID or byte changes.

---

## 4. DAG_JSON_SPEC.md

### Scores

| Lens | Score | Rationale |
|---|---|---|
| Coherence | 6 | The consolidation goal is correct, but paths are wrong and the duplicate-interface problem is not fully described. |
| Capability | 7 | DAG-JSON is useful for RPC and debugging, but it is a consolidation/cleanup task rather than a major new capability. |
| Safety | 8 | Reserved namespace validation, parser limits, and deterministic hashing are well covered. |
| Efficiency | 7 | The scope is appropriately limited to canonical encoding/decoding; no bloat. |
| Evolution | 7 | DAG-JSON parity is useful but less critical than CAR, UnixFS, or DAG-CBOR. |

**Verdict: CONDITIONAL**

### Strengths

- Correctly identifies the duplicate DAG-JSON implementations and the need to consolidate on a single spec-compliant codec.
- Describes the reserved namespace encoding for bytes (`{"/": {"bytes": "..."}}`) and CID links (`{"/": "cid-string"}`) correctly.
- Includes strict validation rules that prevent reserved-namespace injection attacks.
- P1 priority is appropriate; DAG-JSON should not block the core P0 data layer.

### Weaknesses

- **Line 52:** `lib/src/codec/dag_json_codec.dart` does not exist. The actual file is `lib/src/core/ipld/dag_json_codec.dart`.
- **Line 53:** `lib/src/codec/standard_codecs.dart` does not exist. The actual file is `lib/src/core/ipld/codecs/standard_codecs.dart`.
- **Line 54:** The claim that "The maintainer review is to remove the duplicate and consolidate on the standard codecs file" is a self-reference that should be replaced by the actual technical rationale.
- **Line 69-70:** The spec says the encoder may "emit a BigInt-aware representation" for integers outside the safe JSON range. The IPLD DAG-JSON spec does not define a special BigInt representation; it uses plain JSON numbers. The encoder should either fail or encode as a plain JSON number, but it cannot invent a new representation and remain spec-compliant. This paragraph needs correction.
- The spec does not mention that the duplicate `IPLDCodec` interface in `lib/src/core/ipld/dag_json_codec.dart` has a different shape (`name`/`code`/`encode`/`decode` returning `Uint8List`/`dynamic`) than the `IPLDCodec` interface in `lib/src/core/ipld/codecs/ipld_codec.dart` (`identifier`/`encode`/`decode` returning `Future<Uint8List>`/`Future<IPLDNode>`). Consolidation is not as simple as deleting one file; the interfaces must be reconciled.
- The existing `DagJsonCodec` in `standard_codecs.dart` delegates to `DAGJsonHandler`, which is not audited in the spec. That handler may have its own non-compliance issues.

### Recommendations

1. Update all file paths to the actual locations.
2. Remove the self-referential "maintainer review" language and replace it with technical rationale.
3. Correct the big-integer paragraph: state that DAG-JSON uses plain JSON numbers and that integers outside the safely representable range must either fail or be represented as a JSON number that round-trips without loss. No new BigInt representation is allowed.
4. Add a section that reconciles the two `IPLDCodec` interfaces and specifies the consolidation plan.
5. Audit `DAGJsonHandler` and include its gaps in the current-state section.

### Missing Research / Acceptance Criteria

- A cross-codec fixture test comparing DAG-JSON output to the official IPLD DAG-JSON cross-codec fixtures.
- A test that verifies `1.0` encodes with a decimal point and decodes as a float, while `1` decodes as an integer.
- Acceptance criterion that the duplicate `IPLDCodec` interface is removed and all internal imports are updated.

---

## 5. IPLD_SELECTORS_SPEC.md

### Scores

| Lens | Score | Rationale |
|---|---|---|
| Coherence | 6 | The vocabulary and AST are correct, but the handler path is wrong and the current-state claim about GraphSync block attachment is inaccurate. |
| Capability | 9 | Official IPLD selectors are essential for GraphSync and selective DAG retrieval. |
| Safety | 8 | Budgets, cycle detection, untrusted selector handling, and ADL validation are well specified. |
| Efficiency | 7 | The vocabulary is comprehensive; the P0 scope is large but bounded by budgets. |
| Evolution | 9 | Selector interoperability is a major step toward Kubo/Helia GraphSync parity. |

**Verdict: CONDITIONAL**

### Strengths

- Correctly lists the official selector vocabulary: `exploreAll`, `exploreFields`, `exploreIndex`, `exploreRange`, `exploreRecursive`, `exploreRecursiveEdge`, `exploreUnion`, `exploreInterpretAs`, `matcher`, `limit`, and `condition`.
- Proposes a typed AST, strict parser, and budget-aware executor, which is the right architecture.
- Acceptance criteria include fixture parity with go-ipld-prime and GraphSync block attachment, which are the correct success metrics.
- Security considerations correctly emphasize untrusted selectors, recursion budgets, and cycle detection.

### Weaknesses

- **Line 53:** `lib/src/core/ipld/ipld_handler.dart` does not exist. The actual `IPLDHandler` is in `lib/src/core/ipfs_node/ipld_handler.dart`.
- **Line 56:** The spec says `GraphsyncHandler` cannot attach blocks based on a selector. This is inaccurate: `lib/src/protocols/graphsync/graphsync_handler.dart` already calls `_ipld.executeSelector` and attaches the selected blocks. The real issue is that the selector is custom and not interoperable, not that attachment is missing.
- **Line 57:** The claim that the selector vocabulary does not include `exploreRecursive`, `exploreInterpretAs`, etc. is partially true; the existing `IPLDSelector` in `lib/src/core/ipld/selectors/ipld_selector.dart` has `SelectorType.recursive` but not the official `exploreRecursive` shape. The current-state description should be more precise.
- **Line 78:** `condition` is listed as optional and may be deferred. The spec should make it explicit whether `condition` is in P0 or P1, because some GraphSync fixtures may require it.
- **Line 99-104:** The pseudo-code for `Condition` is confusing (`Selector? condition; Selector? next`). It should be clearer that a `condition` selector contains a condition node and a `next` selector to apply when the condition matches.
- **Line 133:** ADL interpretation for HAMT is required for P1. This creates a tight dependency on the UnixFS P1 HAMT implementation, which should be called out more strongly in the dependency list.

### Recommendations

1. Update the `IPLDHandler` path to `lib/src/core/ipfs_node/ipld_handler.dart`.
2. Correct the GraphSync current-state claim: attachment exists but is based on a custom selector model.
3. Clarify whether `condition` is in P0 or P1 and add the corresponding acceptance criteria.
4. Add a dependency note that `exploreInterpretAs` for HAMT requires the UnixFS P1 HAMT implementation.
5. Define the exact migration path for the existing `SelectorType` enum and `IPLDSelector` class in `lib/src/core/ipld/selectors/ipld_selector.dart`.

### Missing Research / Acceptance Criteria

- A fixture parity test against `selector-fixtures-1` and `selector-fixtures-recursion` with a reference Go implementation.
- A test that verifies the GraphSync handler attaches exactly the blocks selected by a given selector, no more and no less.
- A test that verifies a selector received as DAG-CBOR and DAG-JSON round-trips to the same typed AST and produces the same selected CID set.

---

## Maintainer Summary

All five specs pass the scoring threshold for a bare PASS, but the maintainers cannot approve them unconditionally because of the pervasive file-path drift and stale current-state descriptions. These are not fatal flaws; they are documentation alignment issues that can be fixed in a single pass. Once the paths and current-state sections are corrected, the specs are ready for implementation.

The technical content of the specs is strong:

- The official format and wire-level requirements are correct.
- The security considerations are thorough.
- The acceptance criteria are testable and aligned with Kubo/Helia parity.
- The dependency ordering is sound.

The main risks are:

1. Implementers may start from the wrong files if the spec paths are not corrected.
2. The existing protobuf-based CAR and custom selector models may not be cleanly removed if the migration plan is not explicit.
3. The duplicate `IPLDCodec` interfaces could cause a partial or inconsistent DAG-JSON consolidation.

## Required Pre-Implementation Actions

Before any of these specs are moved to implementation, the following must be completed:

1. **Path alignment:** Update every spec to reference the actual `lib/src/core/...` source files. Replace all occurrences of `lib/src/codec/...` with the correct paths.
2. **Current-state rewrite:** Rewrite the "Current State in dart_ipfs" sections to reflect the actual code in each file, not the intended or assumed state.
3. **Interface reconciliation:** Resolve the two `IPLDCodec` interfaces and document the unified codec API in the DAG-JSON and DAG-CBOR specs.
4. **CAR migration plan:** Decide whether the existing `CAR`, `CarHeader`, and `CarIndex` classes in `lib/src/core/data_structures/car.dart` are deleted, renamed, or refactored, and add this to the CAR spec.
5. **UnixFS determinism fix:** Address the non-deterministic `mtime` in `MerkleDAGNode` / `DagPbCodec` before UnixFS CID parity tests can pass.
6. **Big-integer correction:** In DAG_JSON_SPEC.md, remove the suggestion of a non-standard BigInt representation and clarify that DAG-JSON uses plain JSON numbers.
7. **GraphSync correction:** In IPLD_SELECTORS_SPEC.md, correct the claim that block attachment is missing and instead describe the custom-selector interoperability gap.
8. **Condition scope:** In IPLD_SELECTORS_SPEC.md, explicitly place `condition` in P0 or P1 and add the corresponding acceptance criteria.
9. **CID version for UnixFS:** In UNIXFS_SPEC.md, add an acceptance criterion that specifies CIDv1 for directories and chunked file roots, matching modern Kubo defaults.
10. **Re-audit:** After the above corrections, run a second maintainer audit to confirm the specs can be approved for implementation.
