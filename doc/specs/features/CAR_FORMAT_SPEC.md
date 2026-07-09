# dart_ipfs v2.0 — CAR v1/v2 Format Specification

**Status:** Maintainer-approved P0 Backlog  
**Target Release:** v2.0  
**Priority:** P0 — Blocker for trustless gateway, MFS import/export, and GraphSync  

---

## 1. Goal and Scope

This specification defines the work required to replace the custom, non-standard CAR serialization in dart_ipfs with the official Content Addressable aRchive (CAR) v1 and v2 formats. After completion, dart_ipfs must be able to read and write CAR files that are accepted by Kubo, Helia, and any other IPLD-compliant implementation without re-encoding or hash mismatches.

Scope includes:

- Full CAR v1 encoder and decoder with correct varint framing, DAG-CBOR header, and CID-prefixed sections.
- Full CAR v2 encoder and decoder, including the 11-byte pragma, 40-byte header, optional padding, embedded CARv1 payload, and optional IndexSorted / MultihashIndexSorted index payloads.
- A public Dart API that preserves the conceptual shape of the current in-memory CAR API while delegating all byte serialization to the standard formats.
- Removal or deprecation of the legacy `CarCodec` in `lib/src/core/ipld/codecs/advanced_codecs.dart` and elimination of the protobuf `CarProto` generated code from the build.
- Integration with the block store so that CAR import/export can be used by MFS, the trustless gateway, and GraphSync responses.

Out of scope for this backlog item: CAR v3 or future transport extensions; content routing; GraphSync message encoding itself (only the CAR payload contract is defined here).

---

## 2. Official References

All behavior must be derived from the authoritative specifications and test fixtures, not from the existing dart_ipfs implementation.

- **CAR v1 specification:** `https://ipld.io/specs/transport/car/carv1/`
- **CAR v2 specification:** `https://ipld.io/specs/transport/car/carv2/`
- **CAR v1 basic fixtures:** `https://ipld.io/specs/transport/car/carv1-basic/`
- **CAR v2 basic fixtures:** `https://ipld.io/specs/transport/car/carv2-basic/`
- **DAG-CBOR specification (used for CAR headers):** `https://ipld.io/specs/codecs/dag-cbor/spec/`
- **CID specification:** `https://github.com/multiformats/cid`
- **Multicodec table (for codec codes):** `https://github.com/multiformats/multicodec/blob/master/table.csv`
- **Trustless Gateway specification (CAR export consumer):** `https://specs.ipfs.tech/http-gateways/trustless-gateway/`
- **GraphSync specification (CAR-like payload consumer):** `https://ipld.io/specs/transport/graphsync/`

Reference implementations for interoperability verification:

- **Kubo:** `https://github.com/ipfs/kubo` (commands `kubo dag import`, `kubo car import`, `kubo car export`).
- **Helia:** `https://github.com/ipfs/helia` with `@helia/car`.
- **go-car / go-car/v2:** `https://github.com/ipld/go-car` and `https://github.com/ipld/go-car/v2`.

---

## 3. Current State in dart_ipfs

The custom protobuf-based CAR codec has been replaced with the standard API described in this specification.

- **File:** `lib/src/core/ipld/codecs/advanced_codecs.dart` previously contained a non-standard `CarCodec` class that serialized CAR data through a generated protobuf `CarProto` message. That class has been removed and is no longer registered in `IPLDHandler`.
- **File:** `lib/src/core/data_structures/car.dart` now implements the standard `CarHeader`, `CarSection`, and `IndexBuilder` data model instead of the legacy protobuf `CarProto` message. The legacy `CAR`, `CarHeader`, and `CarIndex` classes have been replaced by the standard `CarReader` / `CarWriter` / `CarHeader` / `CarSection` / `IndexBuilder` API defined in this specification, per `MAINTAINER_DECISION_CAR_MIGRATION.md`.
- **Resolved:** The output bytes now conform to CAR v1/v2 and are accepted by `kubo dag import` and Helia's `@helia/car`.
- **Resolved:** CAR v2 pragma, header, index payload, and footer are now supported.
- **Resolved:** CAR sections are framed as `[varint | CID | Block]` and the header is DAG-CBOR.
- **Resolved:** The in-memory CAR API is built on top of the standard byte layer and is reusable.
- **Dependency:** CAR v2 headers are DAG-CBOR maps, so this backlog item depends on the DAG-CBOR codec being spec-compliant. The unified `IPLDCodec` interface from `MAINTAINER_DECISION_IPLDCODEC_RECONCILIATION.md` is in place.

---

## 4. Target State / Requirements

### 4.1 Wire Format

#### CAR v1

A CAR v1 file is a concatenation of a single header followed by zero or more sections:

```text
[ varint | DAG-CBOR Header ] [ varint | CID | Block ] [ varint | CID | Block ] ...
```

- **Header:** A single DAG-CBOR-encoded map with the exact schema `{ "roots": [CID, CID, ...], "version": 1 }`. At least one root must be present. Every root CID must appear in the data section of the CAR.
- **Section framing:** Each section begins with an unsigned LEB128/varint length that measures the combined byte length of the raw CID and the block, followed by the raw CID bytes, followed by the block bytes. The length value excludes the varint itself.
- **CID parsing:** A decoder must parse the CID to determine the boundary between the CID and the block; there is no separate length field for the CID.
- **Ordering:** Sections are append-only and need not be in DAG order. Duplicate CIDs are allowed but are not required; a decoder may deduplicate or retain duplicates depending on the consumer's needs.
- **Streaming:** The format is inherently streamable because each section is length-prefixed. A decoder may produce sections without loading the entire file into memory.

#### CAR v2

A CAR v2 file wraps a complete CAR v1 payload inside a structured envelope with an optional index for random access:

```text
[ 11-byte Pragma ] [ 40-byte Header ] [ padding ] [ CARv1 data payload ] [ padding ] [ optional Index payload ]
```

- **Pragma (11 bytes):** The fixed byte sequence `0x0aa16776657273696f6e02`. This is a valid CBOR map `{ "version": 2 }` with a leading length byte. A CAR v1 decoder that reads the first byte as a version will see `0x0a` (10) and reject it because it only supports version 1.
- **Header (40 bytes):**
  - `Characteristics` (16 bytes): A bitfield. All bits must be zero for v2.0. The high bit is reserved for `fully-indexed` and must not be set unless the index is guaranteed to cover every section.
  - `dataOffset` (8 bytes, unsigned little-endian): Byte offset from the start of the pragma to the beginning of the CARv1 data payload.
  - `dataSize` (8 bytes, unsigned little-endian): Byte length of the embedded CARv1 payload.
  - `indexOffset` (8 bytes, unsigned little-endian): Byte offset from the start of the pragma to the beginning of the optional index payload, or `0` if no index is present.
- **Data payload:** A complete CAR v1 file (header + sections). Extraction to CAR v1 is a zero-copy slice `[dataOffset, dataOffset + dataSize)` relative to the start of the pragma.
- **Index payload:** Optional. The v2.0 implementation must support both `IndexSorted` (`0x0400`) and `MultihashIndexSorted` (`0x0401`). The index begins with a 4-byte little-endian format code, followed by sorted records. For `IndexSorted`, each record is `[varint | multihash digest length | multihash digest bytes | varint | section offset]`. Records are sorted by the raw bytes of the multihash digest. For `MultihashIndexSorted`, each record is prefixed with the multihash code. An `indexOffset` of `0` means no index is present.
- **Padding:** Padding bytes may appear between the header and the data payload and between the data payload and the index payload. Padding must consist of zero bytes and must be skipped by the decoder. Writers may insert padding to align payloads to disk block boundaries.

### 4.2 Data Structures and Public API

The public API must keep the same conceptual shape as the current in-memory CAR API but use standard bytes underneath.

- **`CarHeader`** — Immutable value object:
  - `int version` (1 or 2)
  - `List<CID> roots`
  - Equality based on value, not identity.
- **`CarSection`** — Immutable value object:
  - `CID cid`
  - `Uint8List bytes`
  - Helper `int get serializedSize` returning the on-wire size of the section (varint length + CID length + block length).
- **`CarReader`** — Streaming/iterable reader:
  - `CarReader.fromBytes(Uint8List bytes)`
  - `CarReader.fromStream(Stream<Uint8List> stream)`
  - `Future<CarHeader> get header`
  - `Stream<CarSection> sections()` — yields each section in file order.
  - `Future<int?> findCID(CID cid)` for CAR v2 with index — returns the byte offset of the section containing the CID, or `null` if not present. Must use the index if available; otherwise falls back to a streaming scan.
- **`CarWriter`** — Append-only writer:
  - `CarWriter({required List<CID> roots, bool v2 = false, bool index = false, ...})`
  - `Future<void> write(CID cid, Uint8List block)` — writes a single section; for CAR v2 with index, records the section offset and multihash digest.
  - `Future<Uint8List> close()` — emits the complete file as bytes.
  - `Stream<Uint8List> closeStream()` — emits the complete file as a stream for large archives.
- **`IndexBuilder`** (optional, CAR v2 only):
  - Collects `(multihash, offset)` pairs during writing.
  - Supports both in-memory and disk-backed accumulation for large archives.
  - Emits the sorted index payload on close.

### 4.3 Block Store Integration

- A `BlockStore.exportCar(CID root, {bool v2 = false, bool recursive = true})` helper should produce a CAR containing the root and, when `recursive` is true, every reachable block.
- A `BlockStore.importCar(Stream<CarSection>)` helper should store every section and return the list of roots from the CAR header.
- The trustless gateway must use the CAR writer to produce `application/vnd.ipld.car` responses. IPNS record responses use a separate MIME type and are not emitted by the CAR writer.
- GraphSync responses must be able to attach blocks from a CAR-like stream (the exact GraphSync message format is defined in the networking backlog, but the block payload must be standard CID/block pairs).

---

## 5. Acceptance Criteria

1. **Kubo import (CAR v1):** A CAR v1 file written by dart_ipfs can be imported by `kubo dag import` and `kubo car import` without error, and the roots declared in the header are preserved in Kubo's output.
2. **Kubo export (CAR v1):** A CAR v1 file exported by `kubo car export` can be read by dart_ipfs, and every `(CID, block)` pair matches the expected multihash.
3. **CAR v2 round-trip:** The same import/export test works for CAR v2 files with and without an index, using both Kubo's `kubo car` commands and Helia's `@helia/car`.
4. **Legacy removal:** The non-standard `CarCodec` class is removed from `lib/src/core/ipld/codecs/advanced_codecs.dart` or marked `@deprecated` with a no-op body, and the build no longer depends on the old protobuf `CarProto` generated code.
5. **Malformed input rejection:** The CAR reader rejects invalid varints, missing roots, roots that are not present in the data section, truncated sections, unknown CAR versions, and malformed CAR v2 headers. Each error must produce a distinct exception class with a clear message.
6. **Index correctness:** For CAR v2 with an index, `findCID` returns the correct offset for every CID in the file, and returns `null` for CIDs not present. The index must be sorted and must be parseable by go-car v2.
7. **Zero-copy extraction:** CAR v2 to CAR v1 extraction is performed by slicing the underlying byte buffer without re-encoding when the input is a byte buffer.
8. **Streaming:** A CAR v1 or v2 file can be written and read as a stream without buffering the entire file in memory.

---

## 6. Security Considerations

- **Untrusted input handling:** CAR decoders must treat all input as untrusted. Enforce parser limits before allocating memory: maximum varint length (e.g., 10 bytes), maximum block size (configurable, default 32 MiB), maximum CAR section count (configurable, default 1 million), and maximum total file size.
- **CID integrity:** Every block CID must match the hash of the block bytes. The decoder must optionally verify hashes on read; the writer must always compute correct CIDs. Identity CIDs (`0x00`) must be rejected in untrusted contexts unless the caller explicitly opts in, because they bypass hash verification and can be used to embed arbitrary data.
- **Memory exhaustion:** A malformed varint or length field can claim a huge section size. The decoder must validate lengths against the configured maximum and against the remaining input before allocating a buffer.
- **Index validation:** When a CAR v2 index is present, the decoder must verify that index offsets point inside the file and that indexed section offsets are within the data payload. A mismatch between the index and the data payload must be treated as an error.
- **Canonical DAG-CBOR header:** The header is encoded as DAG-CBOR and must follow canonical key ordering (`roots` before `version`). Deviations produce a different header CID and break interoperability.
- **DoS via duplicate roots:** The decoder must validate that every root appears at least once in the data section; a missing root indicates a malformed CAR.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- **Header parsing:** Test parsing of valid CAR v1 and v2 headers, empty root list rejection, and unknown version rejection.
- **Section framing:** Test correct parsing of single and multiple sections, empty CAR, oversized varints, and truncated sections.
- **CAR v2 layout:** Test pragma detection, header field layout, dataOffset/dataSize/indexOffset calculations, and padding skipping.
- **Index tests:** Build a CAR v2 with `IndexSorted` and `MultihashIndexSorted`, verify record sorting, and verify lookup by multihash digest.
- **Error cases:** Test invalid varints, negative lengths, roots missing from data section, and malformed DAG-CBOR headers.

### 7.2 Round-Trip Tests

- Encode a CAR v1 with a known set of blocks, decode it, and verify that every `(CID, block)` pair round-trips.
- Encode a CAR v2 with and without an index, decode it, and verify that the extracted CAR v1 payload is identical to the original CAR v1.
- Verify that the CAR v2 header offsets are correct and that the embedded CAR v1 can be extracted by go-car v2 without re-encoding.

### 7.3 Interoperability Tests with Kubo and Helia

Create a CI job or local Docker Compose stack that runs the latest Kubo and Helia stable versions and exercises:

- **CAR import:** dart_ipfs exports a CAR v1/v2 file; Kubo and Helia import it and the roots match.
- **CAR export:** Kubo and Helia export a CAR file; dart_ipfs reads all sections and the CIDs match the expected multihashes.
- **Trustless gateway:** A dart_ipfs trustless gateway responds with a valid CAR v2 payload for `Accept: application/vnd.ipld.car` requests; Kubo and Helia clients can reconstruct the DAG.
- **GraphSync payload:** GraphSync response blocks produced by dart_ipfs are accepted by a Kubo or Helia GraphSync client.

Use fixed fixtures from the IPLD specs for determinism, and add a smaller set of randomized property-based tests to fuzz the varint and padding edge cases.

### 7.4 Regression Tests

- Add a test that asserts the legacy `CarCodec` class is no longer present or is marked deprecated.
- Regenerate any CAR files that were previously produced by the old custom codec and verify they now pass Kubo import.

---

## 8. Dependencies and Ordering

1. **DAG-CBOR P0 (prerequisite):** CAR v1/v2 headers and selector payloads are DAG-CBOR. The DAG-CBOR codec must be spec-compliant before CAR v2 can be fully verified.
2. **CID codec (prerequisite):** Reading and writing CAR sections requires correct CID parsing and serialization, including multibase and multihash handling.
3. **This CAR backlog item:** Land after DAG-CBOR. This unblocks trustless gateway CAR export, MFS import/export, and GraphSync block attachment.
4. **UnixFS P0 (dependent):** UnixFS directories must be round-tripped through CAR files to Kubo and Helia.
5. **GraphSync P1 (dependent):** GraphSync responses use the CAR writer to attach selected blocks.

---

## 9. Backward Compatibility Notes

- **v2.0 breaking change:** The legacy `CarCodec` and its protobuf `CarProto` output are removed. Any CAR files produced by dart_ipfs v1.x are not valid CAR v1 and cannot be imported by other implementations. The release notes must state that users must re-export content using the new CAR writer; there is no automatic conversion path.
- **API contract changes:** The in-memory CAR API (`CarReader`, `CarWriter`, `sections`, `roots`) keeps the same conceptual names, but the underlying byte format changes. Document this in `CHANGELOG.md` and pin the breaking change to the v2.0 major version.
- **Internal consumers:** The MFS service, gateway service, and any GraphSync handler that previously used `CarCodec` must be updated to use the new `CarWriter`/`CarReader`. If any internal code depends on the protobuf structure, refactor it to use the standard API before v2.0 ships.
- **Interop default:** After landing, the default CI checks must pass against the latest Kubo and Helia stable versions. Any future regression that breaks interoperability is a release blocker for v2.0 and subsequent releases.
