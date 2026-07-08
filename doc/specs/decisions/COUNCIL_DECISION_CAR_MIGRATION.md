# Council of Five Decision — CAR Migration for dart_ipfs

**Decision ID:** `COUNCIL_DECISION_CAR_MIGRATION`  
**Date:** 2026-06-25  
**Verdict:** **Option A** — Delete the old `CAR` / `CarHeader` / `CarIndex` classes and replace them with the new standard `CarReader` / `CarWriter` classes.  
**Target Release:** dart_ipfs v2.0  
**Authority:** Ciel Council of Five (Coherence, Capability, Safety, Efficiency, Evolution)

---

## 1. Context

The existing `lib/src/core/data_structures/car.dart` (`CAR`, `CarHeader`, `CarIndex`) serializes through a custom protobuf message (`proto.CarProto` from `lib/src/proto/generated/core/car.pb.dart`) and is not wire-compatible with the official IPLD CAR v1/v2 specifications. The new target is defined in `doc/specs/features/CAR_FORMAT_SPEC.md`.

Internal consumers of the old CAR classes are:

- `lib/src/utils/car_reader.dart` (lines 8–18) — delegates to `CAR.fromBytes`.
- `lib/src/utils/car_writer.dart` (lines 8–13) — delegates to `CAR.toBytes`.
- `lib/src/core/ipfs_node/datastore_handler.dart` (lines 153–206) — builds a `CAR` via `CarHeader` and calls `CarWriter.writeCar`.
- `lib/src/core/ipld/codecs/advanced_codecs.dart` (lines 99–180) — `CarCodec` implements a non-standard `car` IPLD codec.
- `lib/src/core/ipfs_node/ipld_handler.dart` (line 60) — registers `CarCodec`.
- `lib/src/services/gateway/content_type_handler.dart` (lines 143–192) — converts CAR archives to HTML rather than returning a standard CAR payload.
- Tests: `test/utils/car_test.dart`, `test/core/car_full_test.dart`, `test/core/datastore_handler_test.dart`, `test/core/ipfs_node/datastore_handler_test.dart`.

The public API of `dart_ipfs` exposes only `importCAR(Uint8List)` / `exportCAR(String)` on `IPFS` (`lib/src/ipfs.dart`, lines 188–195) and `IPFSNode`. The underlying `CAR` class is not exported from `lib/dart_ipfs.dart`, so the migration is an internal implementation change.

---

## 2. Options Evaluated

| Option | Description |
|--------|-------------|
| **A** | Delete `CAR` / `CarHeader` / `CarIndex` and replace them with the standard `CarReader` / `CarWriter` / `CarHeader` / `CarSection` / `IndexBuilder` API from `CAR_FORMAT_SPEC.md`. |
| **B** | Keep the existing class names but rewrite their internals to produce and consume standard CAR bytes. |
| **C** | Rename the old classes to `LegacyCar` / `LegacyCarHeader` / `LegacyCarIndex`, keep them for backward compatibility, and add new standard `CarReader` / `CarWriter` classes. |
| **D** | **Devised alternative:** Delete the old classes, implement the standard API, but stage the removal over two milestones by keeping a read-only legacy decoder in a private `src/_legacy` directory for one release only. |

---

## 3. Council Deliberation

Scores are on a 0–10 scale per lens. Higher is better.

### 3.1 Coherence — Does the plan fit the existing architecture and public API?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 8 | The target classes in `CAR_FORMAT_SPEC.md` (`CarReader`, `CarWriter`, `CarHeader`, `CarSection`, `IndexBuilder`) replace the old in-memory model cleanly. The public `importCAR`/`exportCAR` signatures remain unchanged because they operate on `Uint8List`. |
| **B** | 6 | Reusing `CAR`/`CarHeader`/`CarIndex` while changing their byte semantics and field shape is confusing. The old `CarHeader` has non-standard `characteristics` and `pragma` fields that do not exist in the CAR v1/v2 DAG-CBOR header, and the old `CarIndex` is keyed by CID strings rather than multihash digests. |
| **C** | 5 | Two parallel CAR APIs create namespace clutter and contradict the spec’s intent of a single, standard implementation. The legacy classes remain visible to tests and tooling, increasing architectural friction. |
| **D** | 7 | Coherent with the target API, but the temporary legacy decoder adds a layer that is not in the spec and must be removed later. |

### 3.2 Capability — Does it deliver genuine standard CAR support?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 10 | Directly implements standard CAR v1 and v2 (DAG-CBOR header, varint-prefixed CID+block frames, 11-byte pragma, 40-byte header, `IndexSorted`/`MultihashIndexSorted` indexes, streaming). |
| **B** | 8 | Can be made to emit standard bytes, but the old `CAR` in-memory model (a `List<Block>`) is a poor fit for streaming and CAR v2 index construction. The resulting API would be a compromise, not the spec’s design. |
| **C** | 6 | New classes can deliver standard support, but the legacy classes still depend on the protobuf `CarProto` generated code, violating `CAR_FORMAT_SPEC.md` acceptance criterion #4 ("elimination of the protobuf `CarProto` generated code from the build"). |
| **D** | 9 | Same capability as A, but the legacy decoder remains in the build for one release, slightly delaying full legacy removal. |

### 3.3 Safety — What are the risks of breaking existing users, tests, or persisted data?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 6 | Breaks internal tests that construct old `CAR`/`CarHeader`/`CarIndex` objects. Old CAR files produced by dart_ipfs v1.x cannot be imported. No `.car` files are stored in the repository, and the public API (`Uint8List` import/export) does not change. The spec already declares this a v2.0 breaking change with no automatic conversion path. |
| **B** | 5 | Same breaking change in practice, but it is silent because the class names stay the same. Fields such as `CarHeader.characteristics` and `CarHeader.pragma` would disappear, causing subtle compile-time and runtime failures that are harder to detect than explicit deletions. |
| **C** | 8 | Preserves existing tests and any old CAR bytes, but leaves non-standard code alive. The risk is that internal consumers or future contributors accidentally continue to use the legacy path, undermining interoperability. |
| **D** | 7 | Preserves the ability to read old CAR bytes for one release, but the legacy path is explicitly private and deprecated, reducing the risk of continued use. |

### 3.4 Efficiency — Is the migration path lean and implementable in v2.0?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 8 | One clean replacement pass. The old `CAR` class is confined to a single file and a small set of internal consumers; the protobuf generated code can be deleted once the class is removed. No dual maintenance. |
| **B** | 6 | Fewer symbol renames, but the implementation must contort the old class shape to support the new wire format and the new streaming API, leading to more complex code and more test rewrites than A. |
| **C** | 4 | Doubles the implementation and test surface: two CAR models, two serialization paths, and continued dependency on protobuf generation. The acceptance criterion requiring protobuf removal is not met without a second migration pass. |
| **D** | 7 | Similar to A but requires an extra removal milestone; acceptable only if the team wants a softer landing, but the extra work is not justified by the risk. |

### 3.5 Evolution — Does it position dart_ipfs for future CAR work?

| Option | Score | Rationale |
|--------|-------|-----------|
| **A** | 10 | The streaming `CarReader`/`CarWriter` architecture and `IndexBuilder` directly support future work: CAR v2 index variants, trustless gateway CAR export, GraphSync block attachment, MFS import/export, and large-archive streaming. |
| **B** | 7 | Standard bytes are produced, but the old `CAR` class is not designed for streaming, limiting future index and large-file work. |
| **C** | 5 | Future CAR features must be duplicated or implemented only on the new path while the legacy path becomes dead weight. |
| **D** | 9 | Same forward position as A, with a temporary legacy anchor that is removed before the next release cycle. |

---

## 4. Summary Scorecard

| Lens | A | B | C | D |
|------|---|---|---|---|
| Coherence | 8 | 6 | 5 | 7 |
| Capability | 10 | 8 | 6 | 9 |
| Safety | 6 | 5 | 8 | 7 |
| Efficiency | 8 | 6 | 4 | 7 |
| Evolution | 10 | 7 | 5 | 9 |
| **Total** | **42** | **32** | **28** | **39** |

Option A wins on capability, efficiency, and evolution. It is slightly behind C and D on safety, but the safety gap is mitigated because the old API is not public and the v2.0 release already authorizes a breaking change. Option D is a close second but adds a milestone of legacy code that the Council does not believe is necessary.

---

## 5. Final Verdict

**Adopt Option A.**

Delete the old `CAR`, `CarHeader`, and `CarIndex` classes in `lib/src/core/data_structures/car.dart` and replace them with the standard `CarReader` / `CarWriter` / `CarHeader` / `CarSection` / `IndexBuilder` API specified in `doc/specs/features/CAR_FORMAT_SPEC.md`. Remove the legacy `CarCodec` from `lib/src/core/ipld/codecs/advanced_codecs.dart` and its registration in `lib/src/core/ipfs_node/ipld_handler.dart`. Remove `lib/src/proto/core/car.proto` and the generated `car.pb*.dart` files once all other consumers are gone. Update the internal consumers and tests in the same change set.

---

## 6. Required Implementation Actions

1. **New standard CAR implementation** (`lib/src/core/data_structures/car.dart`)
   - `CarHeader` — immutable value object with `version` (1 or 2) and `List<CID> roots` only.
   - `CarSection` — immutable value object with `CID cid` and `Uint8List bytes`, plus `serializedSize`.
   - `CarReader` — `fromBytes`, `fromStream`, `header`, `sections()`, and `findCID(CID)` for indexed CAR v2.
   - `CarWriter` — constructor with `roots`, `v2`, `index`; `write(CID, Uint8List)`, `close()`, `closeStream()`.
   - `IndexBuilder` — collects `(multihash, offset)` pairs, emits sorted `IndexSorted` or `MultihashIndexSorted` payload.

2. **Remove legacy serialization**
   - Delete the generated protobuf files under `lib/src/proto/generated/core/car.*`.
   - Delete `lib/src/proto/core/car.proto`.
   - Remove the `CarCodec` class from `lib/src/core/ipld/codecs/advanced_codecs.dart` (lines 99–180).
   - Remove its registration in `lib/src/core/ipfs_node/ipld_handler.dart` (line 60).
   - If `protobuf` / `fixnum` are no longer needed by any other generated code, remove them from `pubspec.yaml`.

3. **Update utility wrappers**
   - `lib/src/utils/car_reader.dart` — re-implement using `CarReader`.
   - `lib/src/utils/car_writer.dart` — re-implement using `CarWriter`.

4. **Update internal consumers**
   - `lib/src/core/ipfs_node/datastore_handler.dart` (lines 153–206) — use `CarWriter` for export and `CarReader` for import; stop constructing old `CAR` objects.
   - `lib/src/services/gateway/content_type_handler.dart` (lines 143–192) — remove the CAR-to-HTML conversion path for trustless requests; instead, route `application/vnd.ipfs.car` / `application/vnd.ipld.car` to the standard CAR writer.
   - `lib/src/services/gateway/gateway_handler.dart` (lines 122–125) — add trustless format negotiation and use the new CAR writer when requested.

5. **Update tests**
   - `test/utils/car_test.dart` — rewrite to test standard `CarReader`/`CarWriter`.
   - `test/core/car_full_test.dart` — rewrite to test CAR v1/v2 round-trips and edge cases.
   - `test/core/datastore_handler_test.dart` and `test/core/ipfs_node/datastore_handler_test.dart` — update to use new helper APIs.
   - `test/core/ipld/codecs/codecs_coverage_test.dart` — remove `CarCodec` tests.
   - Add a regression test asserting that the legacy `CarCodec` and `CarProto` symbols are no longer present.

6. **Spec and documentation updates**
   - Update `doc/specs/features/CAR_FORMAT_SPEC.md` "Current State" section to reference the actual files (`lib/src/core/...`) and to declare the fate of the old `CAR` class.
   - Fix the `findCID` return type / description per the audit (line 113).
   - Remove the incorrect IPNS record MIME type from the CAR gateway bullet (line 128).
   - Add a migration note to `CHANGELOG.md` and release notes: v1.x CAR files are not compatible and must be re-exported with the new writer.

---

## 7. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Old v1.x CAR files cannot be imported into v2.0. | Documented as a v2.0 breaking change in `CAR_FORMAT_SPEC.md` section 9 and the release notes. The format was implementation-specific and never interoperable, so no conversion path is provided. |
| Internal tests that construct old `CAR` objects break. | Rewrite the tests as part of the same PR. The old classes are not part of the public library export, so no external consumer contract is broken. |
| `protobuf` or `fixnum` dependencies might remain required by other generated code. | Audit all `*.pb.dart` files before removing the packages; only remove if no other generated messages use them. |
| Gateway CAR response path may regress. | Add a trustless gateway unit test and a Kubo/Helia interop test per `CAR_FORMAT_SPEC.md` acceptance criteria #3 and #7. |
| `CarCodec` removal leaves a gap in `IPLDHandler` codec registration. | Standard CAR is not an IPLD codec; it is a transport archive. Remove the registration rather than replacing it. |

---

## 8. Rationale for Rejecting Other Options

- **Option B** was rejected because it preserves misleading class names while silently changing their semantics. This is more dangerous than an explicit deletion and produces a worse fit with the streaming, indexed design of the new spec.
- **Option C** was rejected because it keeps the non-standard protobuf serialization alive, directly contradicting the `CAR_FORMAT_SPEC.md` acceptance criteria and leaving a permanent interoperability liability.
- **Option D** was rejected because the safety benefit of a staged legacy decoder is not worth the extra milestone and maintenance overhead. The old API is not public, and the v2.0 release already authorizes the breaking change.
