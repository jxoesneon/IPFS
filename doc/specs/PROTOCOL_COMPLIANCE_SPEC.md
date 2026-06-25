# dart_ipfs v2.0 — Protocol Compliance & Core Data Layer Specification

**Status:** Council of Five Approved Backlog (P0/P1/P2)  
**Repository:** `C:\Users\josee\IPFS` (dart_ipfs)  
**Target Release:** v2.0  

---

## 1. Overview / Goal

The goal of this backlog is to make dart_ipfs a spec-compliant member of the IPFS data layer. The v2.0 release must replace custom, non-standard serialization with the official IPFS/IPLD formats and wire the result into the higher-level services (MFS, gateway, GraphSync, trustless retrieval, and interoperability tests).

After completion, dart_ipfs must be able to:

- Read and write standard CAR v1 and v2 files that are accepted by Kubo and Helia.
- Build and resolve standard UnixFS directories (and, in P1, HAMT-sharded directories and symlinks).
- Encode and decode DAG-CBOR and DAG-JSON blocks that match the canonical hashes produced by reference implementations.
- Execute the official IPLD selector vocabulary against a local block store and feed selected blocks into GraphSync responses.
- Pass an interoperability test suite against Kubo and Helia for CAR, DAG, UnixFS, and selector operations.

This document contains no code; it defines data structures, wire formats, public APIs, acceptance criteria, sequencing, testing, and migration guidance.

---

## 2. Official References

All implementation must be driven by the current versions of these specifications and fixtures, not by the existing dart_ipfs internals.

- **CAR v1:** `https://ipld.io/specs/transport/car/carv1/`  
- **CAR v2:** `https://ipld.io/specs/transport/car/carv2/`  
- **CAR fixtures:** `https://ipld.io/specs/transport/car/carv1-basic/`, `https://ipld.io/specs/transport/car/carv2-basic/`  
- **DAG-CBOR:** `https://ipld.io/specs/codecs/dag-cbor/spec/` and fixtures `https://ipld.io/specs/codecs/dag-cbor/cross-codec/`  
- **DAG-JSON:** `https://ipld.io/specs/codecs/dag-json/spec/` and fixtures `https://ipld.io/specs/codecs/dag-json/cross-codec/`  
- **UnixFS:** `https://specs.ipfs.tech/unixfs/` and `https://specs.ipfs.tech/unixfs/path-resolution/`  
- **HAMT (UnixFS sharding):** `https://ipld.io/specs/advanced-data-layouts/hamt/spec/`  
- **IPLD Selectors:** `https://ipld.io/specs/selectors/` and fixtures `https://ipld.io/specs/selectors/selector-fixtures-1/`, `selector-fixtures-recursion/`  
- **IPLD Data Model:** `https://ipld.io/specs/data-model/`  
- **GraphSync:** `https://ipld.io/specs/transport/graphsync/`  
- **Trustless Gateway:** `https://specs.ipfs.tech/http-gateways/trustless-gateway/`  
- **CID:** `https://github.com/multiformats/cid`

---

## 3. Current-State Gaps in dart_ipfs

The following gaps were identified in the v1.11.5 baseline and must be closed by v2.0.

1. **CAR serialization is custom.** `lib/src/codec/advanced_codecs.dart` contains a `CarCodec` that uses a protobuf `CarProto` message. The output is not a valid CAR v1/v2 file and is rejected by Kubo/Helia.
2. **UnixFS directory construction is incomplete.** Under `lib/src/core/unixfs/`, directory PBNodes can be created but cumulative `Tsize` values are wrong or missing, and path resolution is not fully integrated with the block store.
3. **DAG-CBOR is not spec-compliant.** `lib/src/codec/cbor/EnhancedCBORHandler.dart` encodes raw bytes with the non-standard CBOR tag 45, encodes CIDs incorrectly, and does not enforce canonical key ordering or big-integer support.
4. **DAG-JSON has two competing implementations.** `lib/src/codec/dag_json_codec.dart` defines a duplicate `IPLDCodec` interface and is not spec-compliant. `lib/src/codec/standard_codecs.dart` has a `DagJsonCodec` that is closer but still incomplete.
5. **IPLD selectors are custom.** `lib/src/core/ipld/ipld_handler.dart` uses a hand-rolled `SelectorType` model that does not match the official selector vocabulary and cannot be serialized as DAG-CBOR. GraphSync currently cannot attach blocks based on a selector.
6. **IPLD Schema DSL validation is absent.** Only a lightweight stopgap exists; full schema validation is out of scope for v2.0.

---

## 4. Detailed Per-Item Specification

### 4.1 P0 — Standard CAR v1/v2 Format

#### Scope
Replace the custom protobuf `CarProto` serialization with the official CAR v1/v2 format. Keep the existing in-memory CAR API (reading roots, iterating sections, writing blocks). Remove or deprecate the non-standard `CarCodec` in `advanced_codecs.dart`.

#### Wire Format

**CAR v1**

```text
[ varint | DAG-CBOR Header ] [ varint | CID | Block ] [ varint | CID | Block ] ...
```

- The **Header** is a single DAG-CBOR-encoded map: `{ "roots": [ CID, ... ], "version": 1 }`. At least one root must be present and every root CID must appear in the data section.
- Each **Section** is a `varint` length of the remainder of the section (the combined byte length of the raw CID and the block), followed by the raw CID bytes, followed by the block bytes. The length excludes the varint itself. A decoder must parse the CID first to know its size; the remaining bytes are the block.
- The stream is append-only. The ordering of sections does not have to be DAG-ordered.

**CAR v2**

```text
[ 11-byte Pragma ] [ 40-byte Header ] [ padding ] [ CARv1 data payload ] [ padding ] [ optional Index payload ]
```

- **Pragma:** fixed 11 bytes `0x0aa16776657273696f6e02`. This is a valid CBOR map `{ "version": 2 }` prefixed by a length byte so that legacy CARv1 readers reject it as an unsupported version.
- **Header (40 bytes):**
  - 16 bytes `Characteristics` bitfield (all zero for v2.0; the high bit is reserved for `fully-indexed`).
  - 8 bytes `dataOffset` (unsigned little-endian) from the start of the pragma.
  - 8 bytes `dataSize` (unsigned little-endian) of the embedded CARv1 payload.
  - 8 bytes `indexOffset` (unsigned little-endian) from the start of the pragma, or `0` if no index.
- **Data payload:** a complete CARv1 file (header + sections). Extraction to CARv1 is a zero-copy slice of `dataOffset..dataOffset+dataSize`.
- **Index payload:** an optional index for random access. The v2.0 implementation must support **IndexSorted** (`0x0400`) and **MultihashIndexSorted** (`0x0401`). The index begins with a 4-byte index format code (little-endian) followed by the index records. For `IndexSorted` each record is `[ varint | multihash digest length | multihash digest bytes | varint | section offset ]`. The records are sorted by digest bytes. `indexOffset = 0` means no index is present.

#### Data Structures & API

The public API should keep the conceptual shape of the current in-memory CAR API but use spec bytes underneath.

- `CarHeader` — immutable object: `version` (1 or 2), `roots` (List<CID>).
- `CarSection` — immutable object: `cid` (CID), `bytes` (Uint8List).
- `CarReader` — streaming/iterable reader:
  - `CarReader.fromStream(Stream<Uint8List>)` or `fromBytes(Uint8List)`.
  - `Future<CarHeader> get header`.
  - `Stream<CarSection> sections()`.
  - `Future<CID?> findCID(CID)` for CARv2 with index.
- `CarWriter` — append-only writer:
  - `CarWriter({required List<CID> roots, bool v2 = false, ...})`.
  - `Future<void> write(CID, Uint8List)`.
  - `Future<Uint8List> close()` emits the full file (or `Stream<Uint8List>` for streaming).
- For CARv2, an optional `IndexBuilder` that collects `(multihash, offset)` pairs and writes the sorted index on close.

#### Acceptance Criteria

1. A CARv1 file written by dart_ipfs can be imported by `kubo dag import` and `kubo car import` without error and its roots are preserved.
2. A CARv1 file exported by Kubo can be read by dart_ipfs and every `(CID, block)` pair matches the expected hash.
3. The same holds for CARv2 with and without an index, using `kubo car` and Helia's `@helia/car`.
4. The legacy `CarCodec` class is removed from `advanced_codecs.dart` or marked `@deprecated` with a no-op body; the build does not depend on the old `CarProto` generated code.
5. CAR reader rejects malformed input: invalid varint, missing roots, roots not present in data section, truncated sections, or unknown CARv2 version.

---

### 4.2 P0 — UnixFS Basic Directories

#### Scope
Fix UnixFS directory creation, cumulative `Tsize` computation, and path resolution integration under `lib/src/core/unixfs/`. P1 adds HAMT sharding and symlinks with cycle guards.

#### Data Structures

UnixFS nodes are encoded as DAG-PB (`codecs/dag-pb/`). The PBNode schema:

```text
type PBNode struct {
  links [PBLink]
  data optional Bytes
}

type PBLink struct {
  hash &Any
  name optional String
  tsize optional Int
}
```

The `data` field of a PBNode holds a protobuf `Data` message:

```text
message Data {
  enum DataType {
    Raw = 0;
    Directory = 1;
    File = 2;
    Metadata = 3;
    Symlink = 4;
    HAMTShard = 5;
  }
  required DataType Type = 1;
  optional bytes Data = 2;
  optional uint64 filesize = 3;
  repeated uint64 blocksizes = 4;
  optional uint64 hashType = 5;
  optional uint64 fanout = 6;
}
```

- **Directory** nodes have `Type = Directory`, no `data` payload, and `links` whose `name` field is the path segment.
- **File** nodes have `Type = File`, `data` payload may contain file bytes for inline small files, and `links` to chunk CIDs for larger files. `blocksizes` lists the logical sizes of the chunks; `filesize` is the total logical size.
- `Tsize` of a `PBLink` is the cumulative serialized byte size of the DAG reachable through that link (the sum of all block sizes in the subtree, including the linked block itself).

#### API

- `UnixFSNode createDirectory(List<PBLink> links)` — builds a DAG-PB directory node, computes the CID, and stores the block.
- `UnixFSNode addChildToDirectory(CID dirCid, String name, CID childCid, int childTsize)` — returns a new directory node without mutating the original (content-addressed, immutable).
- `int computeTsize(CID root)` — recursively computes the cumulative serialized size of a UnixFS subtree, respecting a configurable max recursion depth and block size budget.
- `UnixFSPathResolver`:
  - `Future<CID> resolve(CID root, String path)` or `Future<UnixFSNode> resolve(root, path)`.
  - Splits `path` on `/`, ignoring empty segments and leading/trailing slashes.
  - Fetches each directory node from the block store, matches the next segment against `PBLink.name` using exact byte comparison, and follows the link.
  - Returns the final node/CID or throws `PathResolutionError`.

#### Acceptance Criteria

1. A directory created by dart_ipfs and exported via `kubo dag get /ipfs/<cid>` returns the same PBNode bytes and CID as a directory created by Kubo for the same file set.
2. `Tsize` values on every link are equal to the cumulative block size of the linked subtree and match Kubo.
3. `ipfs cat /ipfs/<dir-cid>/<sub-path>` against a dart_ipfs gateway (or Kubo gateway pointed at a dart_ipfs-provided DAG) resolves the file and returns the correct bytes.
4. Path resolution rejects `..`, `.`, empty segments, and missing links with a clear error class.
5. Round-trip: import a directory from Kubo, re-export it, and the resulting CID and CAR bytes are identical.

#### P1 Additions (HAMT + Symlinks)

- Implement a **HAMT-sharded directory** (`HAMTShard` type) for directories with more than a configured fanout threshold (default 256 entries per shard).
- Add **symlink** support (`Type = Symlink`, `data` = target path). The path resolver must detect symlinks and follow them, tracking a `Set<CID>` of visited symlink CIDs to detect cycles and throw `SymlinkCycleError`.

---

### 4.3 P0 — Full DAG-CBOR Codec

#### Scope
Make `EnhancedCBORHandler` (or its successor) fully compliant with the DAG-CBOR specification. The codec must produce the same canonical bytes and CID as Kubo, Helia, and `go-ipld-prime`.

#### Encoding Rules

- **CIDs:** encoded as CBOR tag `42` on a byte string. The byte string must be prefixed with `0x00` followed by the raw CID bytes. The prefix distinguishes binary CIDs from raw byte strings that happen to be tag 42.
- **Bytes:** encoded as plain CBOR byte strings (major type 2). **No** tag `45` or any other tag is used for raw bytes.
- **Integers:**
  - Values in the unsigned CBOR range use major type 0.
  - Values in the negative CBOR range use major type 1.
  - Values outside those ranges use CBOR big-integer tags `2` (positive) or `3` (negative) on a byte string in big-endian.
- **Floats:** encoded as CBOR floats (major type 7). Only finite values are allowed (no `NaN`/`Infinity`).
- **Strings, lists, maps:** use the standard CBOR major types.
- **Map canonical key ordering:** keys must be sorted by the raw UTF-8 bytes of the string: first by length, then lexicographically. This is the IPLD canonical CBOR ordering and must be deterministic for hashing.
- **Decoding:** must reject any CBOR tag other than `2`, `3`, and `42`. Tags must be applied only to the correct underlying types. CIDs must be decoded to the `CID` IPLD kind. Bytes must be decoded to the `Bytes` IPLD kind, not wrapped in a tag.
- **Strict mode:** by default, decoding fails on duplicate map keys, indefinite-length strings, and any unsupported CBOR feature. A lenient mode may be provided for legacy data but is not used for hashing.

#### API

- `Uint8List encodeDagCbor(IPLDNode node)` — returns canonical bytes.
- `IPLDNode decodeDagCbor(Uint8List bytes)` — returns the data-model node.
- `CID computeCidDagCbor(IPLDNode node)` — convenience that encodes and hashes with the DAG-CBOR multicodec (`0x71`) and a default hash (sha2-256 unless configured otherwise).
- The public codec must expose `codecCode = 0x71` and `name = 'dag-cbor'`.

#### Acceptance Criteria

1. All DAG-CBOR cross-codec fixtures from the IPLD specs round-trip and CID-match reference outputs.
2. A node containing a CID link decodes back to a CID object and not a tagged byte string.
3. A node containing raw bytes encodes and decodes as plain bytes; adding the old tag 45 produces an error on decode.
4. Two maps with the same logical content but different key order produce identical canonical bytes and CID.
5. Big-integer values outside the 64-bit range round-trip with exact equality.

---

### 4.4 P1 — Consolidated DAG-JSON Codec

#### Scope
Do not introduce a third DAG-JSON implementation. Remove/deprecate `dag_json_codec.dart` and its duplicate `IPLDCodec` interface. Update `DagJsonCodec` in `standard_codecs.dart` so it is the single, spec-compliant DAG-JSON codec.

#### Encoding Rules

- **Whitespace:** no whitespace. Object keys are sorted by raw UTF-8 bytes.
- **Integers:** encoded as JSON numbers without fractional or exponent notation. Dart `int` is arbitrary precision, but emit a JSON number only when the value is within the safe integer range recognized by the spec; otherwise use a BigInt-aware JSON number representation (or fail with a clear error if the configured JSON library cannot emit large integers without precision loss). The decoded value must round-trip as an integer.
- **Floats:** encoded with a decimal point (e.g. `1.0`) even when there is no fractional component, so they are distinguishable from integers on decode.
- **Bytes:** encoded as the reserved namespace `{ "/": { "bytes": "<base64url-no-padding>" } }`. Use RFC 4648 section 5 base64url without padding.
- **CID links:** encoded as `{ "/": "<cid-string>" }`.
  - CIDv0: Base58 string (the only valid encoding for CIDv0).
  - CIDv1: Multibase Base32 lowercase string (prefix `b`), no padding.
- **Reserved namespace:** reject maps that illegally use `/` as the first key when the value is a string but the map has other keys, or when the inner `bytes` map is malformed. Follow the exact parse-rejection rules in the DAG-JSON spec.
- **Path escaping:** when a DAG-JSON path or selector key contains a literal `/`, it must be escaped as `~1` and a literal `~` as `~0` per RFC 6901. This applies to path resolution and selector field names, not to the JSON serialization of the key itself.

#### API

- `String encodeDagJson(IPLDNode node)` — compact canonical string.
- `IPLDNode decodeDagJson(String json)` — returns data-model node.
- `CID computeCidDagJson(IPLDNode node)` — uses codec code `0x0129` (dag-json) with the default hash.

#### Acceptance Criteria

1. `lib/src/codec/dag_json_codec.dart` is deleted or its body is replaced by a deprecated re-export of `standard_codecs.dart`. The duplicate `IPLDCodec` interface is removed.
2. All DAG-JSON cross-codec fixtures round-trip and match reference CIDs.
3. Encoding bytes and CID links produces the exact reserved-namespace forms described above.
4. Invalid reserved-namespace maps are rejected during decode.
5. A float `1.0` encodes with a decimal point; an integer `1` encodes without; decoding distinguishes them.

---

### 4.5 P0 — Spec-Compliant IPLD Selector Execution

#### Scope
Replace the custom `SelectorType` model in `IPLDHandler` with the official IPLD selector vocabulary. Selectors are DAG-CBOR nodes. Implement a selector interpreter that can be invoked by `IPLDHandler` and by `GraphsyncHandler`.

#### Selector Vocabulary

The implementation must support at least the official selector types used by IPFS/GraphSync:

- `exploreAll` — traverse every key/value or index of a node.
- `exploreFields` — traverse a named set of fields (map keys).
- `exploreIndex` — traverse a single list index.
- `exploreRange` — traverse a range of list indices.
- `exploreRecursive` — recursive descent with a `limit` and optional `stopAt`.
- `exploreRecursiveEdge` — marker that terminates the recursion pattern inside `exploreRecursive`.
- `exploreUnion` — apply a list of selectors to the same node.
- `exploreInterpretAs` — traverse with an ADL interpretation (e.g., HAMT).
- `matcher` — select the current node and return it.
- `limit` — recursion limit helpers: `depth`, `recursiveEdge`, etc.
- `condition` — optional; include if required by GraphSync fixtures.

Selectors are represented as DAG-CBOR maps with the canonical selector schema. For example:

```text
{ "exploreAll": { "next": { "matcher": {} } } }
{ "exploreRecursive": { "limit": { "depth": 3 }, "sequence": { "exploreAll": { "next": { "exploreRecursiveEdge": {} } } } } }
{ "exploreFields": { "fields": { "foo": { "matcher": {} }, "bar": { "exploreAll": { "next": { "matcher": {} } } } } } }
```

#### Data Model

Define a typed selector AST that mirrors the spec. Suggested shape (pseudo-code):

```text
abstract class Selector
class ExploreAll extends Selector { Selector next }
class ExploreFields extends Selector { Map<String, Selector> fields }
class ExploreIndex extends Selector { int index; Selector next }
class ExploreRange extends Selector { int start; int end; Selector next }
class ExploreRecursive extends Selector { RecursionLimit limit; Selector sequence; Selector? stopAt }
class ExploreRecursiveEdge extends Selector
class ExploreUnion extends Selector { List<Selector> members }
class ExploreInterpretAs extends Selector { String adl; Selector next }
class Matcher extends Selector
class Condition extends Selector { Selector? condition; Selector? next }
```

#### API

- `Selector parseSelector(dynamic dagCborNode)` — deserialize a DAG-CBOR node into the typed AST. Reject unknown selector keys or malformed shapes.
- `Stream<SelectedNode> executeSelector(CID root, Selector selector, {int? maxDepth, int? maxNodes, bool includePath = false})` — traverses the block store starting at `root`, following the selector, and yields every matched node. The interpreter must respect `maxDepth`/`maxNodes` budgets and throw `SelectorBudgetExceeded` if exceeded.
- `SelectedNode` contains: `cid`, `node` (IPLD data-model node), `path` (optional IPLD path string), and `remainingDepth`.
- In `GraphsyncHandler`, when a request contains a selector, decode it, call `executeSelector(request.root, selector)`, and attach the resulting blocks to the `GraphsyncMessage.blocks` field of the response.

#### Acceptance Criteria

1. All selector fixtures from `selector-fixtures-1` and `selector-fixtures-recursion` produce the same set of selected CIDs as the reference Go implementation.
2. A `matcher` selector returns exactly the root node.
3. An `exploreRecursive` selector with a `depth` limit stops at the correct depth and does not follow links beyond the budget.
4. `exploreFields`, `exploreIndex`, `exploreRange`, and `exploreUnion` are tested independently and in combination.
5. GraphSync handler can respond to a selector request with the requested blocks; a Kubo or Helia GraphSync client can decode the response and materialize the selected DAG.
6. Selectors are serialized to DAG-CBOR before being sent and parsed on the receiving side; round-trip preserves semantics.

---

### 4.6 P2 — IPLD Schema DSL Validation (Deferred)

#### Scope
Keep the existing lightweight stopgap for schema validation (if any). Do not implement a full IPLD Schema DSL parser or validator in v2.0. Revisit after P0/P1 are complete and after the interoperability test suite is stable.

#### Notes for Later

- The DSL is defined at `https://ipld.io/specs/schemas/`.
- A future implementation should be able to load a schema, validate an IPLD node against a schema type, and optionally compile a schema into a Dart type adapter.
- Until then, any code that needs schema-like validation should use explicit runtime checks on the data-model node and should not invent a custom schema language.

---

## 5. Implementation Sequence

The dependencies below dictate the order. P0 items must land before P1 items; P2 is deferred.

1. **DAG-CBOR P0** — DAG-CBOR is the foundation for CAR headers, selectors, and many test fixtures. Land this first.
2. **DAG-JSON P1 consolidation** — once DAG-CBOR is solid, unify DAG-JSON so the codec suite is consistent.
3. **CAR v1/v2 P0** — implement after DAG-CBOR because CAR headers are DAG-CBOR. This unblocks trustless gateway CAR export and MFS import/export.
4. **UnixFS basic directories P0** — implement after CAR so directories can be round-tripped via Kubo/Helia. Path resolution depends on the block store only, not on selectors.
5. **IPLD Selectors P0** — implement after DAG-CBOR because selectors are DAG-CBOR nodes. This unblocks GraphSync.
6. **GraphSync integration P0/P1** — wire selector execution into `GraphsyncHandler` as part of the v2.1 naming/messaging backlog; this spec defines the selector/block attachment contract.
7. **HAMT + symlinks P1** — add after basic directories are correct and tested.
8. **IPLD Schema DSL P2** — revisit in a later release.

---

## 6. Testing Strategy

### 6.1 Unit Tests

Every codec and data structure must have targeted unit tests with golden vectors:

- **CAR:** tests for header parsing, section framing, empty CAR rejection, invalid varints, unknown versions, CARv2 header layout, and index lookup.
- **UnixFS:** tests for directory node creation, cumulative `Tsize` calculation, file chunking, path resolution, and error cases (missing link, `..`, empty path).
- **DAG-CBOR:** tests for CID tag 42, raw bytes, map canonical ordering, big integers, float handling, and rejection of unsupported tags.
- **DAG-JSON:** tests for CID/bytes reserved namespace, key sorting, whitespace stripping, integer/float distinction, and invalid forms.
- **Selectors:** tests for each selector type, malformed selector rejection, and budget enforcement.

### 6.2 Round-Trip Tests

For each codec, encode a representative set of IPLD nodes and verify that decode returns a node equal to the original. For content-addressed codecs, verify that the CID of the encoded bytes matches a reference implementation or a known fixture.

### 6.3 Interoperability Tests with Kubo and Helia

Create a CI job (or local Docker Compose stack) that runs the latest Kubo and Helia nodes and exercises:

- **CAR:** dart_ipfs exports a CARv1/v2 file; Kubo/Helia imports it and the roots match. Kubo/Helia exports a CAR; dart_ipfs reads all sections and the CIDs match.
- **DAG put/get:** dart_ipfs stores a DAG-CBOR or DAG-JSON node; Kubo `dag get` returns the same bytes and CID. Reverse direction also works.
- **UnixFS:** Kubo `add -r` a directory; dart_ipfs imports the resulting DAG and the root CID matches. Dart_ipfs builds a directory; Kubo `cat /ipfs/<cid>/path` returns the same files.
- **Selectors:** a known selector fixture is executed against the same DAG in both dart_ipfs and a reference implementation; the selected CID sets are identical.
- **GraphSync:** where GraphSync is enabled, request a selector from a dart_ipfs node and verify the client can reconstruct the DAG.

Use fixed test fixtures for determinism; add a smaller set of randomized property-based tests for fuzzing the codecs.

### 6.4 Regression Tests

- Ensure any old custom CAR files or DAG-JSON outputs that the test suite previously created are regenerated using the new codecs and fail the test if the format changes unexpectedly.
- Add a test that specifically verifies the legacy `CarCodec` is no longer present or is deprecated.

---

## 7. Security Considerations

- **Untrusted input:** CAR, DAG-CBOR, DAG-JSON, and selector decoders must operate on untrusted data. Enforce parser limits: max varint length, max block size, max CAR section count, max recursion depth, max selector budget, and max string/bytes length. Reject malformed lengths before allocating memory.
- **CID validation:** every block CID must match the hash of the block bytes. A decoder may optionally verify hashes on read; at minimum, the writer must compute correct CIDs. Do not accept identity CIDs in untrusted contexts unless the consumer explicitly opts in.
- **Path traversal:** UnixFS path resolution must never allow escape above the root. Reject `..`, empty segments, and absolute paths outside the resolved root. Symlink targets (P1) must be resolved relative to the link and must be checked against a cycle guard before following.
- **Selector budgets:** `exploreRecursive` and `exploreAll` on large DAGs can exhaust memory or CPU. Always run selectors with a `maxDepth` and `maxNodes` budget. If a selector is received over the network, default budgets must be small and configurable.
- **Deterministic hashing:** canonical ordering and deterministic encoding are required for content addressing. Any deviation from canonical DAG-CBOR or DAG-JSON produces a different CID and can break deduplication or verifiability.
- **No eval:** selector execution and schema validation must be interpreters, not code generators. Do not use `dart:mirrors` or string-to-code evaluation to implement selector logic.
- **Resource exhaustion:** CARv2 index building can consume memory proportional to the number of sections. Offer a streaming index builder that writes index records to disk for large archives.

---

## 8. Backward Compatibility & Migration Notes

- **Versioning:** this work is targeted at v2.0. The v1.x line may keep the old custom CAR/JSON code for emergency compatibility, but v2.0 removes or deprecates it.
- **Custom CAR files:** any CAR files produced by the legacy `CarCodec` are not valid CAR v1. Provide a migration note in the release notes: users must re-export content using the new CAR writer; there is no automatic conversion because the legacy format is implementation-specific.
- **API contract changes:** the in-memory CAR API will keep the same conceptual names (`CarReader`, `CarWriter`, `sections`, `roots`) but the underlying byte format changes. Document this in `CHANGELOG.md` and pin the breaking change to the v2.0 major version.
- **DagJsonCodec:** `lib/src/codec/dag_json_codec.dart` is removed. Any code that imported it must import the `DagJsonCodec` from `standard_codecs.dart`. If external consumers depend on the old `IPLDCodec` interface, introduce a short compatibility shim in v2.0.0-rc and remove it in v2.1.
- **Selector model:** the custom `SelectorType` is replaced by the official selector model. Any stored selector JSON/CBOR must be re-encoded. If the project serializes selectors in configuration, a migration script should convert the old format to the new one or fail loudly.
- **Interop default:** after landing, the default CI checks must pass against the latest Kubo and Helia stable versions. This is the source of truth for compatibility; any future regression that breaks interoperability is a release blocker.

---

## Appendix A — Council of Five Verdict Summary

The following priorities and scope decisions are extracted from the Council of Five verdicts provided for this backlog.

| Item | Priority | Verdict |
|------|----------|---------|
| Standard CAR v1/v2 format | P0 | APPROVED |
| UnixFS basic directories | P0 | APPROVED; HAMT + symlinks P1 |
| Full DAG-CBOR codec | P0 | APPROVED |
| Consolidated DAG-JSON codec | P1 | MODIFIED: remove duplicate `dag_json_codec.dart`, make `DagJsonCodec` in `standard_codecs.dart` spec-compliant |
| Spec-compliant IPLD selector execution | P0 | APPROVED; wire into `IPLDHandler` and GraphSync |
| Full IPLD Schema DSL validation | P2 | DEFERRED |

