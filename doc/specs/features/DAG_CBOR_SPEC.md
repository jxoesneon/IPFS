# dart_ipfs v2.0 — DAG-CBOR Codec Specification

**Status:** Council of Five Approved P0 Backlog  
**Target Release:** v2.0  
**Priority:** P0 — Foundation for CAR headers, IPLD selectors, and content-addressed data  

---

## 1. Goal and Scope

This specification defines the work required to make the dart_ipfs DAG-CBOR codec fully compliant with the IPLD DAG-CBOR specification. DAG-CBOR is the canonical binary representation for a large subset of IPLD data and is the encoding used for CAR v1/v2 headers, IPLD selectors, and many protocol messages. After completion, dart_ipfs must encode and decode DAG-CBOR blocks that produce the same canonical bytes and content identifiers (CIDs) as Kubo, Helia, go-ipld-prime, and js-ipld-dag-cbor.

Scope includes:

- Replacement or correction of the current `EnhancedCBORHandler` in `lib/src/codec/cbor/EnhancedCBORHandler.dart` so that it follows the official DAG-CBOR encoding rules.
- Correct encoding of CIDs as CBOR tag 42 on a prefixed byte string.
- Correct encoding of raw bytes as plain CBOR byte strings, with no non-standard tag 45.
- Support for canonical map key ordering, big integers, and strict decoding rules.
- A public API that exposes `encodeDagCbor`, `decodeDagCbor`, and `computeCidDagCbor`.
- Full removal of the non-standard CBOR tag 45 behavior from the codebase.

Out of scope for this backlog item: full CBOR diagnostic notation parser; CBOR Sequence (RFC 8742) support; non-IPLD CBOR extensions.

---

## 2. Official References

All behavior must be derived from the current IPLD DAG-CBOR specification and its cross-codec fixtures.

- **DAG-CBOR specification:** `https://ipld.io/specs/codecs/dag-cbor/spec/`
- **DAG-CBOR cross-codec fixtures:** `https://ipld.io/specs/codecs/dag-cbor/cross-codec/`
- **IPLD Data Model:** `https://ipld.io/specs/data-model/`
- **CID specification:** `https://github.com/multiformats/cid`
- **Multicodec table (DAG-CBOR code `0x71`):** `https://github.com/multiformats/multicodec/blob/master/table.csv`
- **CBOR specification (RFC 8949):** `https://www.rfc-editor.org/rfc/rfc8949.html`
- **CBOR deterministic encoding (RFC 8949 Section 4.2):** `https://www.rfc-editor.org/rfc/rfc8949.html#section-4.2`

Reference implementations for interoperability verification:

- **go-ipld-prime:** `https://github.com/ipld/go-ipld-prime` with the DAG-CBOR codec.
- **js-ipld-dag-cbor:** `https://github.com/ipld/js-ipld-dag-cbor`.
- **Kubo:** `https://github.com/ipfs/kubo` (DAG-CBOR is used for `dag put` and CAR headers).
- **Helia:** `https://github.com/ipfs/helia` with `@ipld/dag-cbor`.

---

## 3. Current State in dart_ipfs

The current DAG-CBOR implementation is not spec-compliant and produces different bytes and CIDs than reference implementations.

- **File:** `lib/src/codec/cbor/EnhancedCBORHandler.dart` contains the existing DAG-CBOR encoder/decoder.
- **Gap:** CIDs are encoded incorrectly; they are not serialized as CBOR tag 42 on a byte string prefixed with `0x00` followed by the raw CID bytes.
- **Gap:** Raw bytes are encoded with the non-standard CBOR tag 45, which is not recognized by any other IPLD implementation. The tag 45 behavior must be removed entirely.
- **Gap:** Canonical map key ordering is not enforced, so maps with the same logical content but different key insertion order produce different CIDs.
- **Gap:** Big integers outside the 64-bit signed/unsigned CBOR range are not handled according to the spec (CBOR tags 2 and 3 on big-endian byte strings).
- **Gap:** Strict decoding is not enforced: unsupported tags, duplicate map keys, indefinite-length strings, and malformed floats may be accepted.
- **Dependency:** DAG-CBOR is a prerequisite for the CAR v1/v2 backlog item (CAR headers are DAG-CBOR) and for the IPLD selectors backlog item (selectors are encoded as DAG-CBOR).

---

## 4. Target State / Requirements

### 4.1 Encoding Rules

The encoder must produce canonical DAG-CBOR bytes that match the IPLD specification and the reference implementations.

- **CIDs:** A CID is encoded as CBOR tag `42` applied to a CBOR byte string. The byte string must be prefixed with the single byte `0x00`, followed by the raw CID bytes (including the multibase prefix, version, codec, and multihash). The `0x00` prefix distinguishes a binary CID from an ordinary byte string that happens to be tagged with 42. For example, a CIDv1 with raw bytes `[0x01, 0x55, ...]` is encoded as tag 42 on the byte string `[0x00, 0x01, 0x55, ...]`.
- **Bytes:** Raw bytes are encoded as plain CBOR byte strings (major type 2). No tag is applied. The legacy tag 45 must be removed and must produce an error on decode if encountered.
- **Integers:**
  - Values in the unsigned CBOR range (`0` to `2^64 - 1`) use CBOR major type 0.
  - Values in the negative CBOR range (`-1` to `-2^64`) use CBOR major type 1.
  - Values outside those ranges use CBOR big-integer tags `2` (positive) or `3` (negative) on a byte string containing the absolute value in big-endian, with no leading zero bytes except where the value itself requires them.
- **Floats:** Encoded as CBOR floats (major type 7). Only finite values are allowed. `NaN`, positive infinity, and negative infinity must be rejected during encoding. Decoding must reject non-finite values by default.
- **Strings:** UTF-8 strings use CBOR major type 3. The encoder must validate that strings are valid UTF-8 and reject invalid surrogate pairs or byte sequences.
- **Lists and maps:** Use standard CBOR major types 4 and 5.
- **Map canonical key ordering:** Map keys must be sorted by the raw UTF-8 bytes of the key string. The sorting order is: first by length, then lexicographically. This is the IPLD canonical CBOR ordering and must be deterministic for hashing. Numeric keys are not permitted in the IPLD Data Model, so only string keys are considered for canonical ordering.
- **Deterministic encoding:** The encoder must follow RFC 8949 Section 4.2 for preferred serialization: use the shortest encoding for integers, floats, and lengths; avoid indefinite-length strings and byte strings; use the shortest float representation that preserves value (e.g., `1.0` must be encoded as a 16-bit float if the implementation chooses the shortest form, but the spec allows any deterministic choice as long as it is consistent). For IPLD compatibility, the canonical choice must match the reference implementations tested against the cross-codec fixtures.
- **Null and boolean:** `null` is encoded as CBOR `0xf6`; `true` as `0xf5`; `false` as `0xf4`.

### 4.2 Decoding Rules

The decoder must be strict by default and reject data that does not conform to the DAG-CBOR subset.

- **Allowed tags:** Only CBOR tags `2`, `3`, and `42` are permitted. Any other tag must cause decoding to fail with a clear `UnsupportedTagError`.
- **Tag type validation:**
  - Tag 2 and tag 3 must be applied to a byte string. The decoded value is a big integer (positive for tag 2, negative for tag 3).
  - Tag 42 must be applied to a byte string. The byte string must have a leading `0x00` byte; the remaining bytes are the raw CID. The decoded value is a `CID` object, not a tagged byte string.
- **Duplicate map keys:** Decoding must fail by default when a map contains duplicate keys. A lenient mode may be provided for legacy data but must not be used for hashing or CID computation.
- **Indefinite-length strings and byte strings:** Rejected in strict mode. Indefinite-length arrays and maps are also rejected in strict mode.
- **Unsupported CBOR features:** Rejected features include tags other than 2/3/42, unassigned break codes, malformed floats, and major type 7 values other than `false`, `true`, `null`, and finite floats.
- **Data model validation:** The decoder must map CBOR types to the IPLD Data Model kinds: integer -> `Int`, bytes -> `Bytes`, string -> `String`, list -> `List`, map -> `Map`, tag 42 -> `Link` (CID), tag 2/3 -> `Int`, true/false -> `Bool`, null -> `Null`. Maps with non-string keys must be rejected because they are not valid IPLD Data Model maps.

### 4.3 Public API

- **`Uint8List encodeDagCbor(IPLDNode node)`** — Returns canonical DAG-CBOR bytes for the given IPLD data-model node. Throws `DagCborEncodingError` for unsupported values (e.g., non-finite floats, non-string map keys, invalid UTF-8 strings).
- **`IPLDNode decodeDagCbor(Uint8List bytes, {bool strict = true})` — Returns the IPLD data-model node represented by the bytes. In strict mode, rejects unsupported tags, duplicate keys, indefinite-length strings, and non-finite floats. In lenient mode, relaxes some rules but still decodes CIDs and big integers according to the spec.
- **`CID computeCidDagCbor(IPLDNode node)`** — Convenience that encodes the node and hashes the bytes with the DAG-CBOR multicodec (`0x71`) and the default hash function (sha2-256 unless configured otherwise). The returned CID must match the CID produced by go-ipld-prime for the same node.
- **Codec identity:** The public codec must expose `codecCode = 0x71` and `name = 'dag-cbor'`, matching the multicodec table.
- **Streaming API (optional):** A `Stream<Uint8List> encodeDagCborStream(IPLDNode node)` may be provided for large nodes, but the output bytes must be identical to the non-streaming encoder.

### 4.4 IPLD Node Representation

The implementation must define an `IPLDNode` type or set of types that directly represent the IPLD Data Model:

- `IPLDNull`, `IPLDBool`, `IPLDInt`, `IPLDString`, `IPLDBytes`, `IPLDList`, `IPLDMap`, `IPLDLink` (CID).
- Map iteration must be deterministic; the encoder sorts keys at serialization time, but the internal representation may use any map as long as equality is semantic.
- Equality must be value-based: two nodes with the same logical content compare equal, regardless of construction order.

---

## 5. Acceptance Criteria

1. **Cross-codec fixtures:** All DAG-CBOR cross-codec fixtures from the IPLD specs round-trip and CID-match the reference outputs produced by go-ipld-prime or js-ipld-dag-cbor.
2. **CID encoding:** A node containing a CID link decodes back to a CID object, not a tagged byte string. The encoded bytes match the tag-42-with-`0x00`-prefix form.
3. **Bytes encoding:** A node containing raw bytes encodes and decodes as a plain CBOR byte string. Adding the old tag 45 to bytes either produces an error on encode or is rejected on decode.
4. **Canonical map ordering:** Two maps with the same logical content but different key insertion order produce identical canonical bytes and the same CID.
5. **Big integers:** Values outside the 64-bit signed/unsigned range round-trip with exact equality and use CBOR tags 2 or 3.
6. **Float handling:** Finite floats round-trip; non-finite floats (`NaN`, `Infinity`, `-Infinity`) are rejected.
7. **Strict decoding:** Unsupported tags, duplicate map keys, indefinite-length strings, and indefinite-length arrays/maps are rejected in strict mode.
8. **Codec identity:** The codec reports `codecCode = 0x71` and `name = 'dag-cbor'`.
9. **Legacy removal:** The old tag-45 encoding logic is removed from `EnhancedCBORHandler.dart` and from any other files that may reference it. No test fixture expects tag 45.

---

## 6. Security Considerations

- **Untrusted input:** DAG-CBOR decoders operate on untrusted data from the network. Enforce parser limits before allocating memory: maximum byte length (configurable, default 32 MiB), maximum recursion depth (configurable, default 1024), maximum map size (configurable, default 1 million entries), and maximum string/bytes length (configurable, default 8 MiB).
- **Memory exhaustion:** A malformed CBOR length can claim a huge container size. The decoder must validate lengths against the remaining input and the configured maximum before allocating buffers. Indefinite-length items are rejected in strict mode to prevent unbounded streaming attacks.
- **Deterministic hashing:** Canonical ordering and deterministic encoding are required for content addressing. Any deviation from canonical DAG-CBOR produces a different CID and breaks deduplication, verifiability, and interoperability.
- **Tag 42 validation:** A tag 42 applied to a non-byte-string or a byte string without the leading `0x00` must be rejected. This prevents attackers from injecting arbitrary tagged data that looks like a CID but does not represent a valid link.
- **No code evaluation:** The decoder must be a pure interpreter. Do not use `dart:mirrors`, dynamic evaluation, or any mechanism that treats decoded data as code.
- **Big integer safety:** Big integers can be arbitrarily large. The decoder must limit the size of big-integer byte strings to prevent CPU exhaustion during parsing or comparison.
- **Duplicate keys:** In strict mode, duplicate map keys are rejected to prevent ambiguity in content addressing. In lenient mode, the decoder must document which value is retained and must not use lenient mode for CID computation.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- **CID tag 42:** Test encoding and decoding of CIDv0, CIDv1, and CIDs with different hash functions and codecs. Verify the leading `0x00` prefix and the raw CID bytes.
- **Raw bytes:** Test encoding and decoding of empty and non-empty byte strings. Verify that tag 45 is rejected.
- **Map canonical ordering:** Test maps with keys of varying lengths, including keys that are lexicographically similar but different lengths. Verify the sorted order is by length then lexicographic bytes.
- **Big integers:** Test values at the 64-bit boundary and well beyond it. Verify tag 2/3 encoding and round-trip equality.
- **Floats:** Test finite floats, including values that can be represented as 16-bit, 32-bit, or 64-bit CBOR floats. Verify rejection of `NaN` and infinities.
- **Strict mode:** Test rejection of unsupported tags, duplicate keys, indefinite-length strings, indefinite-length arrays/maps, and non-string map keys.
- **Error messages:** Verify that each failure mode produces a distinct exception class with a clear message.

### 7.2 Round-Trip Tests

- Encode a representative set of IPLD nodes (null, bool, int, string, bytes, list, map, CID link, nested structures) and verify that decode returns a node equal to the original.
- For content-addressed nodes, verify that the CID of the encoded bytes matches the CID produced by go-ipld-prime or a known fixture.
- Round-trip the cross-codec fixtures from the IPLD DAG-CBOR spec and compare the decoded nodes to the corresponding DAG-JSON fixtures.

### 7.3 Interoperability Tests with Kubo and Helia

Create a CI job or local Docker Compose stack that runs the latest Kubo and Helia stable versions and exercises:

- **DAG put/get:** Dart_ipfs stores a DAG-CBOR node; Kubo `dag get` returns the same bytes and CID. Reverse direction also works.
- **CAR headers:** CAR v1/v2 headers produced by dart_ipfs are accepted by Kubo and Helia. The header is a DAG-CBOR map with the correct key ordering.
- **Selector encoding:** IPLD selectors encoded by dart_ipfs as DAG-CBOR are parsed by go-ipld-prime and js-ipld-selectors.
- **CID parity:** A representative DAG-CBOR node produces the same CID in dart_ipfs, Kubo, and Helia.

Use fixed fixtures from the IPLD specs for determinism, and add a smaller set of randomized property-based tests to fuzz the encoder/decoder with nested maps, CIDs, and big integers.

### 7.4 Regression Tests

- Add a test that specifically verifies the legacy tag-45 bytes are rejected on decode.
- Add a test that verifies the old `EnhancedCBORHandler` behavior is no longer present.
- Regenerate any test fixtures that were previously encoded with tag 45 and verify they now match the cross-codec fixtures.

---

## 8. Dependencies and Ordering

1. **IPLD Data Model types (prerequisite):** Define or stabilize the `IPLDNode` representation before implementing the codec.
2. **CID codec (prerequisite):** The DAG-CBOR codec must parse and serialize CIDs correctly.
3. **CBOR library (prerequisite):** An underlying CBOR library may be used, but it must be configurable or post-processable to enforce the DAG-CBOR subset. The library must allow custom tag handling for 42 and big integers.
4. **This DAG-CBOR P0 backlog item:** Land first. This is the foundation for CAR v1/v2 headers, IPLD selectors, and many protocol messages.
5. **DAG-JSON P1 consolidation (dependent):** Once DAG-CBOR is solid, unify DAG-JSON so the codec suite is consistent and the same IPLD nodes round-trip across both codecs.
6. **CAR v1/v2 P0 (dependent):** CAR headers are DAG-CBOR. The CAR encoder depends on this codec.
7. **IPLD Selectors P0 (dependent):** Selectors are encoded as DAG-CBOR and parsed by this codec.
8. **GraphSync P1 (dependent):** GraphSync messages may carry selectors and DAG-CBOR payloads.

---

## 9. Backward Compatibility Notes

- **v2.0 breaking change:** The non-standard tag-45 encoding is removed. Any DAG-CBOR blocks produced by dart_ipfs v1.x that use tag 45 for bytes are not valid DAG-CBOR and cannot be decoded by other implementations. The release notes must state that users must re-encode any stored blocks using the new codec; old blocks remain addressable by their old CID but will not be produced by the new encoder.
- **API contract changes:** If `EnhancedCBORHandler` exposed public methods that took raw CBOR tags or produced non-canonical output, those methods must be deprecated or removed. Document the new `encodeDagCbor`, `decodeDagCbor`, and `computeCidDagCbor` APIs in `CHANGELOG.md`.
- **Internal consumers:** Update all internal callers that previously used `EnhancedCBORHandler` to use the new API. This includes CAR header encoding, selector encoding/decoding, and any RPC payloads that use DAG-CBOR.
- **Lenient mode caveat:** A lenient decoder may be provided for emergency recovery of old data, but it must be clearly marked as not suitable for hashing or CID computation. The default mode must be strict.
- **Interop default:** After landing, the default CI checks must pass against the latest Kubo and Helia stable versions. Any future regression that breaks DAG-CBOR CID parity or fixture compatibility is a release blocker.
