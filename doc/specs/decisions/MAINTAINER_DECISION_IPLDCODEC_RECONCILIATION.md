# maintainer decision: Reconcile the Two IPLDCodec Interfaces in dart_ipfs

**Status:** maintainer decision  
**Date:** 2026-06-25  
**Scope:** dart_ipfs v2.0 core data layer (IPLD codecs)  
**Related specifications:** `doc/specs/features/DAG_JSON_SPEC.md`, `doc/specs/audits/MAINTAINER_AUDIT_CORE_DATA_LAYER.md`, `doc/specs/PROTOCOL_COMPLIANCE_SPEC.md`

---

## 1. Context and Findings

The codebase currently contains two incompatible `IPLDCodec` abstractions.

- **Canonical interface:** `lib/src/core/ipld/codecs/ipld_codec.dart` defines `IPLDCodec` with a single string `identifier` and async, typed operations on `IPLDNode` (`encode` returns `Future<Uint8List>`, `decode` returns `Future<IPLDNode>`). This is the interface used by the codec registry and the standard codecs. Source: lines 6-15.
- **Duplicate interface:** `lib/src/core/ipld/dag_json_codec.dart` defines a second `IPLDCodec` with `name` and `code` getters and synchronous `encode`/`decode` that return `dynamic`. Source: lines 7-19. Its only implementation, also named `DagJsonCodec`, reports `name = 'dag-json'` and `code = 0x0129` (lines 24-27).
- **Registry usage:** `lib/src/core/ipfs_node/ipld_handler.dart` stores codecs in a `Map<String, IPLDCodec>` keyed by `codec.identifier` (line 42) and registers them via `_registerCodec`, which uses `codec.identifier` as the key (lines 63-64). It later computes CIDs by passing the same string to `CID.computeForData` (line 172).
- **Codec implementations:** All standard codecs (`RawCodec`, `DagPbCodec`, `DagCborCodec`, `DagJsonCodec`) in `lib/src/core/ipld/codecs/standard_codecs.dart` implement the canonical identifier-only interface (lines 13-112). The advanced codecs (`DagJoseCodec`, `CarCodec`) in `lib/src/core/ipld/codecs/advanced_codecs.dart` also implement the canonical interface (lines 15, 26, 99, 110). The duplicate `dag_json_codec.dart` implementation is not used by the registry; only `test/core/ipld/dag_json_codec_test.dart` imports it (line 6).
- **Spec direction:** `doc/specs/features/DAG_JSON_SPEC.md` mandates removing the duplicate `dag_json_codec.dart` implementation and its `IPLDCodec` interface (sections 4.4, 5, 7.4), but it does not resolve how the two interface shapes should be reconciled. The audit in `doc/specs/audits/MAINTAINER_AUDIT_CORE_DATA_LAYER.md` (lines 55-58, 229-230) explicitly flags that consolidation requires merging or deprecating one interface, not merely deleting one file.

The question before the maintainers is therefore twofold:

1. What is the unified codec interface shape? (Options A, B, C, D.)
2. Should the multicodec `name`/`code` information live on the interface itself, or in a separate registry?

---

## 2. Options Evaluated

### A. Keep the canonical identifier-only interface
- Keep `lib/src/core/ipld/codecs/ipld_codec.dart` as the canonical `IPLDCodec`.
- Delete `lib/src/core/ipld/dag_json_codec.dart` and its duplicate interface.
- Move any useful DAG-JSON logic into the existing `DagJsonCodec` in `standard_codecs.dart`.
- Continue to resolve multicodec codes externally (e.g., via `EncodingUtils` in `CID`).

### B. Keep the duplicate name/code dynamic interface
- Keep the `IPLDCodec` from `dag_json_codec.dart` as the canonical interface.
- Change `standard_codecs.dart`, `advanced_codecs.dart`, and `ipld_handler.dart` to use `name`, `code`, and `dynamic` sync encode/decode.
- Delete the identifier-only interface.

### C. Design a new unified interface that combines both
- Merge the two interfaces into one contract: `name`, `code`, and async typed `encode`/`decode` on `IPLDNode`.
- Migrate all codecs in `standard_codecs.dart` and `advanced_codecs.dart` to implement the new contract.
- Update `IPLDHandler` to register and invoke codecs using the new metadata.
- Provide a backward-compatible deprecated `identifier` alias during the v2.0 transition.

### D. Separate multicodec metadata from the interface
- Keep the encode/decode contract in `IPLDCodec` minimal.
- Move `name`/`code` into a separate `MulticodecRegistry` or codec descriptor table.
- Register codecs by pairing the codec instance with a registry entry.

---

## 3. Review Lenses

### Lens 1: Coherence — Does it fit the existing codec registry and IPLD handler?

- **A.** High coherence with the current registry. The handler already keys by `identifier` (line 64). The main weakness is that the interface has no knowledge of multicodec, so the registry must rely on external string-to-code mapping.
- **B.** Low coherence. The handler is built around the identifier-only interface and `IPLDNode`; switching to sync `dynamic` encode/decode would break the registry's typed contract and require a near rewrite of the handler's data flow.
- **C.** High coherence. `name` becomes the natural registry key, `code` becomes the natural CID input, and the async `IPLDNode` contract matches every other codec. The registry and handler change in a single, predictable way.
- **D.** Moderate coherence. The registry remains small, but every lookup now requires consulting two objects (the codec and the registry), and the handler must be careful to keep the registry and the codec map in sync.

### Lens 2: Capability — Does it enable spec-compliant DAG-CBOR, DAG-JSON, and DAG-PB?

- **A.** The shape of the interface does not block spec compliance, but it does not help either. Multicodec identity (e.g., `0x0129` for DAG-JSON) remains implicit, which makes it easier to misconfigure or to add a new codec without registering its code.
- **B.** The dynamic signature undermines the `IPLDNode` data model that DAG-CBOR and DAG-JSON must share. Spec compliance becomes harder because the encoder would receive untyped Dart values instead of a uniform IPLD node.
- **C.** Best capability. The typed `IPLDNode` contract preserves the shared data model, while explicit `name`/`code` make it trivial for every codec to report its multicodec identity as required by `DAG_JSON_SPEC.md` section 4.3 ("Codec identity").
- **D.** Capable if the registry is authoritative, but the codec itself does not self-declare its identity. New codecs must be added to both the interface implementation and the registry, increasing the chance of drift.

### Lens 3: Safety — What is the blast radius of changing the interface?

- **A.** Smallest blast radius. Only the duplicate file, the one test that imports it, and the `DagJsonCodec` implementation in `standard_codecs.dart` need attention. No change to the handler or other codecs.
- **B.** Largest blast radius. It would require rewriting `standard_codecs.dart`, `advanced_codecs.dart`, `ipld_handler.dart`, and the public `DagJsonCodec` semantics, plus all tests that assume `IPLDNode` results.
- **C.** Moderate blast radius. Every codec class gains two getters; the handler changes its registration key and CID call site; tests that assert on `identifier` may need updates. However, encode/decode signatures remain unchanged, so most callers are unaffected.
- **D.** Small blast radius. The interface itself changes minimally, but the registry must be introduced everywhere the handler resolves a codec, which is a smaller but still nontrivial change.

### Lens 4: Efficiency — Can it be done without a massive refactor?

- **A.** Fastest. The duplicate interface is removed, and the existing `standard_codecs.dart` implementation is promoted. Work is localized to DAG-JSON spec compliance.
- **B.** Most expensive. The refactor spans the entire IPLD data layer and is likely to introduce regressions in type safety and async behavior.
- **C.** Reasonable cost. The migration is mechanical: add `name` and `code` to each codec, update the handler's key and CID call. It can be done in one focused pass.
- **D.** Low cost for the interface change, but the registry must be designed, tested, and wired into the handler before it provides real value.

### Lens 5: Evolution — Does it support future codecs and multicodec registration?

- **A.** Limited. A future codec can implement the interface, but its multicodec code must be known by `CID`/`EncodingUtils` or by another out-of-band mechanism. This creates a hidden dependency on the string-to-code mapping.
- **B.** Poor. The dynamic contract does not scale to codecs that need typed IPLD nodes or async I/O (e.g., `CarCodec`, which reads from the block store).
- **C.** Excellent. New codecs self-declare `name`/`code` and can be registered generically. The handler can validate that no two codecs share a name or code, and future multicodec registration can be automated from the interface.
- **D.** Good. A centralized registry can be updated without touching the interface, but the lack of self-declaration means codecs are not discoverable by reflection or by package consumers without the registry.

---

## 4. Scores

Scores are on a scale of 1 (worst) to 5 (best) per lens.

| Option | Coherence | Capability | Safety | Efficiency | Evolution | Total |
|--------|-----------|------------|--------|------------|-----------|-------|
| A. Keep identifier-only | 4 | 3 | 5 | 5 | 3 | 20 |
| B. Keep name/code dynamic | 2 | 2 | 1 | 2 | 2 | 9 |
| C. New unified interface | 5 | 5 | 3 | 3 | 5 | 23 |
| D. Separate registry | 4 | 4 | 4 | 4 | 4 | 20 |

Option C is the clear leader. Option A is the safest short-term choice but is weaker on evolution and capability. Option D is a viable alternative to A, but it does not solve the discoverability and self-declaration problem that C solves. Option B is unacceptable.

---

## 5. Final Verdict

**The maintainers selects Option C: a new unified `IPLDCodec` interface that combines the best of both existing contracts.**

The duplicate interface in `lib/src/core/ipld/dag_json_codec.dart` is rejected. The sync `dynamic` encode/decode signature is rejected because it breaks the shared `IPLDNode` data model and the async contract already used by every production codec.

**Answer to the registry question:** `name` and `code` are required members of the unified `IPLDCodec` interface, **and** a separate `MulticodecRegistry` is introduced to index codecs by name and code. The codec is the authoritative source of its own `name`/`code`; the registry is the authoritative lookup mechanism. The registry is built from the codecs registered with `IPLDHandler`, not from a second, hand-maintained table. This gives the interface both self-declaration and centralized discovery.

---

## 6. Unified Interface Shape

```dart
/// Interface for all IPLD codecs in dart_ipfs.
abstract class IPLDCodec {
  /// Multicodec name and the registry key (e.g., 'dag-json').
  String get name;

  /// Multicodec integer code (e.g., 0x0129 for DAG-JSON).
  int get code;

  /// Encodes an [IPLDNode] into bytes.
  Future<Uint8List> encode(IPLDNode node);

  /// Decodes bytes into an [IPLDNode].
  Future<IPLDNode> decode(Uint8List data);
}
```

### Backward compatibility

- During v2.0.0-rc, provide a deprecated `identifier` getter that returns `name` so that existing code using `codec.identifier` continues to compile.
- The old `IPLDCodec` interface in `lib/src/core/ipld/dag_json_codec.dart` is removed along with the file body, per `DAG_JSON_SPEC.md` section 4.4. A deprecated re-export pointing to `standard_codecs.dart` may be retained for v2.0.0-rc only if external consumers are affected, and it must be removed in v2.1.
- The single `DagJsonCodec` implementation lives in `lib/src/core/ipld/codecs/standard_codecs.dart` and is made spec-compliant as described in `DAG_JSON_SPEC.md`.

### Registry shape

```dart
/// Index of registered IPLD codecs by multicodec name and code.
class MulticodecRegistry {
  IPLDCodec? byName(String name);
  IPLDCodec? byCode(int code);
  Iterable<IPLDCodec> get all;
  void register(IPLDCodec codec);
}
```

`IPLDHandler` owns the registry and uses it for both name-based and code-based lookups.

---

## 7. Migration Plan

1. **Update the interface file.** Replace `lib/src/core/ipld/codecs/ipld_codec.dart` with the unified shape (section 6). Add a deprecated `identifier` alias returning `name` for the v2.0 transition.
2. **Add multicodec identity to every codec.** Update `RawCodec`, `DagPbCodec`, `DagCborCodec`, and `DagJsonCodec` in `lib/src/core/ipld/codecs/standard_codecs.dart` (lines 13-112) to implement `name` and `code`. Do the same for `DagJoseCodec` and `CarCodec` in `lib/src/core/ipld/codecs/advanced_codecs.dart` (lines 15-96 and 99-120). Use the official multicodec table for the numeric values (e.g., `dag-json` is `0x0129`).
3. **Update the IPLD handler.** In `lib/src/core/ipfs_node/ipld_handler.dart`:
   - Change `_registerCodec` to key by `codec.name` (lines 63-64).
   - Change `_encodeData` to pass `codec.code` to `CID.computeForData` instead of the string `codecId` (line 172), or keep the string only for the `Block.format` field while using `codec.code` for the CID multicodec portion.
   - Initialize a `MulticodecRegistry` with the default codecs and expose it via `getStatus()` or a new `registry` getter.
4. **Remove the duplicate implementation.** Delete `lib/src/core/ipld/dag_json_codec.dart`, or replace it with a deprecated re-export of `lib/src/core/ipld/codecs/standard_codecs.dart` for v2.0.0-rc only.
5. **Update tests.** Migrate `test/core/ipld/dag_json_codec_test.dart` to import from `standard_codecs.dart`. Add regression tests that assert no duplicate `IPLDCodec` interface exists and that each codec reports the correct `name` and `code`.
6. **Update specifications.** Amend `doc/specs/features/DAG_JSON_SPEC.md` to reference this decision and to describe the unified interface. Update `doc/specs/PROTOCOL_COMPLIANCE_SPEC.md` and the migration notes if any public API contracts change.
7. **Land after DAG-CBOR.** Per `DAG_JSON_SPEC.md` section 8, the DAG-JSON consolidation should land after the DAG-CBOR implementation is spec-compliant, so cross-codec fixtures can be validated against the same `IPLDNode` types.

---

## 8. Risks and Mitigations

- **Public API breakage.** Any external code importing the old `IPLDCodec` from `dag_json_codec.dart` will break. Mitigation: provide a deprecated shim in v2.0.0-rc and remove it in v2.1, as already allowed by `DAG_JSON_SPEC.md` section 9.
- **CID determinism.** Changing the CID computation path from a string-based codec lookup to a code-based lookup must produce the same CIDs for existing built-in codecs. Mitigation: validate all existing fixtures and cross-codec tests before merging.
- **Multicodec code accuracy.** Each codec must use the correct official multicodec code. Mitigation: add a unit test that compares every built-in codec's `code` against a canonical reference table.
- **Async contract drift.** The new interface preserves the existing async signatures, so no async/await churn is expected outside the handler. Mitigation: keep the encode/decode signatures unchanged during this migration.
- **Test dependency on the old file.** `test/core/ipld/dag_json_codec_test.dart` currently imports the duplicate implementation. Mitigation: update the test to use the unified `DagJsonCodec` from `standard_codecs.dart` and extend it with spec compliance cases.

---

## 9. References

- `lib/src/core/ipld/codecs/ipld_codec.dart` (lines 6-15) — current canonical interface.
- `lib/src/core/ipld/dag_json_codec.dart` (lines 7-27) — duplicate interface and implementation.
- `lib/src/core/ipld/codecs/standard_codecs.dart` (lines 13-112) — codecs using the canonical interface.
- `lib/src/core/ipld/codecs/advanced_codecs.dart` (lines 15-120) — advanced codecs using the canonical interface.
- `lib/src/core/ipfs_node/ipld_handler.dart` (lines 42-64, 172) — codec registry and CID computation.
- `test/core/ipld/dag_json_codec_test.dart` (line 6) — test importing the duplicate implementation.
- `doc/specs/features/DAG_JSON_SPEC.md` (sections 4.3, 4.4, 5, 7.4, 8, 9) — DAG-JSON consolidation requirements.
- `doc/specs/audits/MAINTAINER_AUDIT_CORE_DATA_LAYER.md` (lines 55-58, 229-230) — audit finding on the two interfaces.
- `doc/specs/PROTOCOL_COMPLIANCE_SPEC.md` (lines 51, 230, 405) — protocol-level direction.
- IPLD DAG-JSON specification: `https://ipld.io/specs/codecs/dag-json/spec/`
- Multicodec table: `https://github.com/multiformats/multicodec/blob/master/table.csv`
