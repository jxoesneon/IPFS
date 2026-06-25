# dart_ipfs v2.0 — DAG-JSON Codec Specification

**Status:** Council of Five Approved P1 Backlog (Modified: consolidate to a single implementation)  
**Target Release:** v2.0  
**Priority:** P1 — Unifies the codec suite and enables human-readable IPLD serialization  

---

## 1. Goal and Scope

This specification defines the work required to consolidate dart_ipfs DAG-JSON support into a single, spec-compliant implementation. DAG-JSON is the canonical JSON representation of the IPLD Data Model and is used for human-readable APIs, configuration files, debugging, and many IPFS RPC responses. After completion, dart_ipfs must encode and decode DAG-JSON strings that match the canonical form produced by Kubo, Helia, go-ipld-prime, and js-ipld-dag-json, and must produce the same CIDs as the corresponding DAG-CBOR representations for nodes that can be represented in both codecs.

Scope includes:

- Removal or deprecation of the duplicate `dag_json_codec.dart` implementation and its duplicate `IPLDCodec` interface.
- Promotion of `DagJsonCodec` in `lib/src/codec/standard_codecs.dart` to be the single, spec-compliant DAG-JSON codec.
- Implementation of the reserved namespace encoding for bytes and CID links.
- Canonical key sorting, whitespace stripping, and correct integer/float distinction.
- Strict validation of reserved-namespace maps during decode.

Out of scope for this backlog item: extending JSON beyond the IPLD Data Model; full JSON Schema validation; arbitrary JSON with comments or trailing commas.

---

## 2. Official References

All behavior must be derived from the current IPLD DAG-JSON specification and its cross-codec fixtures.

- **DAG-JSON specification:** `https://ipld.io/specs/codecs/dag-json/spec/`
- **DAG-JSON cross-codec fixtures:** `https://ipld.io/specs/codecs/dag-json/cross-codec/`
- **IPLD Data Model:** `https://ipld.io/specs/data-model/`
- **CID specification:** `https://github.com/multiformats/cid`
- **Multicodec table (DAG-JSON code `0x0129`):** `https://github.com/multiformats/multicodec/blob/master/table.csv`
- **Base32 lowercase encoding (RFC 4648):** `https://www.rfc-editor.org/rfc/rfc4648.html`
- **Base64url encoding without padding (RFC 4648 Section 5):** `https://www.rfc-editor.org/rfc/rfc4648.html#section-5`
- **JSON Pointer escaping (RFC 6901):** `https://www.rfc-editor.org/rfc/rfc6901.html`
- **Multibase specification:** `https://github.com/multiformats/multibase`

Reference implementations for interoperability verification:

- **go-ipld-prime:** `https://github.com/ipld/go-ipld-prime` with the DAG-JSON codec.
- **js-ipld-dag-json:** `https://github.com/ipld/js-ipld-dag-json`.
- **Kubo:** `https://github.com/ipfs/kubo` (DAG-JSON is used for `dag get` with JSON formatting and some RPC responses).
- **Helia:** `https://github.com/ipfs/helia` with `@ipld/dag-json`.

---

## 3. Current State in dart_ipfs

The current DAG-JSON implementation is fragmented and not spec-compliant.

- **File:** `lib/src/codec/dag_json_codec.dart` defines a duplicate `IPLDCodec` interface and a separate DAG-JSON codec implementation. This duplicates the work in `lib/src/codec/standard_codecs.dart` and confuses consumers.
- **File:** `lib/src/codec/standard_codecs.dart` contains a `DagJsonCodec` class that is closer to the spec but still incomplete.
- **Gap:** Two competing implementations exist. The Council of Five verdict is to remove the duplicate and consolidate on the standard codecs file.
- **Gap:** The reserved namespace for bytes and CID links is not implemented correctly.
- **Gap:** Object keys are not sorted canonically, and whitespace is not stripped, leading to non-canonical strings and different CIDs when hashing.
- **Gap:** Integers and floats are not distinguished correctly (e.g., `1.0` may encode as `1`).
- **Dependency:** DAG-JSON shares the same `IPLDNode` data model as DAG-CBOR. The DAG-CBOR codec should be solid before DAG-JSON is consolidated, so that cross-codec tests can be run against the same node types.

---

## 4. Target State / Requirements

### 4.1 Encoding Rules

The encoder must produce canonical DAG-JSON strings that match the IPLD specification and the reference implementations.

- **Whitespace:** No whitespace is emitted. The output is a compact JSON string with no line breaks, indentation, or spaces outside string values. Keys are sorted by the raw UTF-8 bytes of the string, first by length and then lexicographically, matching the IPLD canonical map ordering.
- **Integers:** Encoded as JSON numbers without fractional or exponent notation. Dart `int` is arbitrary precision, but the encoder must only emit a plain JSON number when the value is within the safe integer range recognized by the DAG-JSON spec (i.e., values that can be represented without loss in a JSON number). For values outside that range, the encoder must either emit a BigInt-aware representation that preserves precision or fail with a clear `DagJsonIntegerRangeError` if the underlying JSON library cannot represent the value without loss. The decoded value must round-trip as an integer.
- **Floats:** Encoded with a decimal point (e.g., `1.0`) even when there is no fractional component, so they are distinguishable from integers on decode. Values such as `1e10` are represented in JSON scientific notation, which is unambiguously a float. `NaN` and `Infinity` are not representable in JSON and must be rejected.
- **Bytes:** Encoded as the reserved namespace `{ "/": { "bytes": "<base64url-no-padding>" } }`. The base64url encoding follows RFC 4648 Section 5 with no padding characters (`=`). The decoder must reject any padding or incorrect alphabet characters.
- **CID links:** Encoded as `{ "/": "<cid-string>" }`.
  - CIDv0: The string is the Base58 multibase string (the only valid encoding for CIDv0). The string begins with `Qm`.
  - CIDv1: The string is the Multibase Base32 lowercase string, prefixed with `b` (e.g., `bafy...`). No padding is used.
- **Reserved namespace validation:** The encoder must reject maps that illegally use `/` as a first key when the value is a string but the map has other keys, or when the inner `bytes` map is malformed. Only the two valid forms described above are allowed for the reserved namespace.
- **Strings:** UTF-8 strings are encoded as JSON strings. Control characters and special characters are escaped according to RFC 8259.
- **Null, boolean, list:** Use standard JSON syntax: `null`, `true`, `false`, and arrays.

### 4.2 Decoding Rules

The decoder must parse a JSON string into an `IPLDNode` and must strictly validate the reserved namespace.

- **Reserved namespace parse rules:**
  - A map with exactly one key `/` whose value is a string is interpreted as a CID link. The string must be a valid CID in either Base58 (CIDv0) or Multibase Base32 (CIDv1) form. Any other map with a `/` key and additional keys is invalid and must be rejected.
  - A map with exactly one key `/` whose value is a map containing exactly one key `bytes` whose value is a string is interpreted as a bytes value. The string must be base64url without padding. Any other shape (e.g., extra keys, wrong inner type) is invalid and must be rejected.
  - A map that contains `/` as one of several keys is invalid and must be rejected.
- **Integer/float distinction:** JSON numbers without a fractional or exponent component decode as `Int`. JSON numbers with a fractional component or exponent decode as `Float`. The decoder must preserve this distinction even when the numeric value is mathematically an integer (e.g., `1.0` decodes as a float, `1` decodes as an integer).
- **Map key validation:** Map keys must be strings. Non-string keys are not valid in the IPLD Data Model and must be rejected. Duplicate map keys are rejected in strict mode.
- **Strict mode:** By default, the decoder rejects any input that does not conform to the DAG-JSON subset. A lenient mode may be provided for legacy data but must not be used for hashing or CID computation.
- **Path escaping (RFC 6901):** When a DAG-JSON path or selector key contains a literal `/`, it must be escaped as `~1` and a literal `~` as `~0`. This applies to path resolution and selector field names, not to the JSON serialization of the key itself. The codec does not need to perform path resolution, but it must preserve the key strings so that path resolution can apply the escaping rules.

### 4.3 Public API

- **`String encodeDagJson(IPLDNode node)`** — Returns the compact canonical DAG-JSON string. Throws `DagJsonEncodingError` for unsupported values (e.g., non-finite floats, invalid reserved-namespace maps, unsupported integer values).
- **`IPLDNode decodeDagJson(String json, {bool strict = true})`** — Returns the IPLD data-model node represented by the JSON string. In strict mode, rejects invalid reserved-namespace maps, duplicate keys, and unsupported JSON features. In lenient mode, relaxes some rules but still validates CID and bytes forms.
- **`CID computeCidDagJson(IPLDNode node)`** — Convenience that encodes the node as DAG-JSON and hashes the UTF-8 bytes with the DAG-JSON multicodec (`0x0129`) and the default hash function (sha2-256 unless configured otherwise). For nodes that can also be represented as DAG-CBOR, the CID will differ from the DAG-CBOR CID because the codec code is different, but the logical content is equivalent.
- **Codec identity:** The public codec must expose `codecCode = 0x0129` and `name = 'dag-json'`.
- **Cross-codec helper:** `IPLDNode fromDagCbor(Uint8List bytes)` and `Uint8List toDagCbor(IPLDNode node)` helpers may be provided, but the DAG-JSON codec itself must only deal with JSON strings.

### 4.4 Consolidation Requirements

- `lib/src/codec/dag_json_codec.dart` is deleted, or its body is replaced by a deprecated re-export that points to `lib/src/codec/standard_codecs.dart`.
- The duplicate `IPLDCodec` interface defined in `dag_json_codec.dart` is removed.
- `lib/src/codec/standard_codecs.dart` is the single source of truth for the `DagJsonCodec` class.
- All internal imports of `dag_json_codec.dart` are updated to import from `standard_codecs.dart`.
- If external consumers depend on the old `IPLDCodec` interface, a short compatibility shim may be introduced in v2.0.0-rc and removed in v2.1.

---

## 5. Acceptance Criteria

1. **Consolidation:** `lib/src/codec/dag_json_codec.dart` is deleted or its body is replaced by a deprecated re-export of `standard_codecs.dart`. The duplicate `IPLDCodec` interface is removed.
2. **Cross-codec fixtures:** All DAG-JSON cross-codec fixtures from the IPLD specs round-trip and match the reference CIDs or logical content produced by go-ipld-prime and js-ipld-dag-json.
3. **Bytes and CID links:** Encoding bytes and CID links produces the exact reserved-namespace forms described above. Decoding those forms returns the original bytes and CID values.
4. **Invalid reserved namespace:** Invalid reserved-namespace maps are rejected during decode. Examples include maps with a `/` key and other keys, maps with `{ "/": { "bytes": "...", "extra": "..." } }`, and maps with `{ "/": { "not-bytes": "..." } }`.
5. **Integer/float distinction:** A float `1.0` encodes with a decimal point; an integer `1` encodes without; decoding distinguishes them.
6. **Canonical output:** Two maps with the same logical content but different key insertion order produce identical canonical strings and the same CID.
7. **Whitespace:** The encoded string contains no whitespace characters outside of string values.
8. **Codec identity:** The codec reports `codecCode = 0x0129` and `name = 'dag-json'`.
9. **Internal imports:** All internal code that previously imported `dag_json_codec.dart` now imports `standard_codecs.dart` and uses the spec-compliant `DagJsonCodec`.

---

## 6. Security Considerations

- **Untrusted input:** DAG-JSON decoders operate on untrusted data from the network and from RPC clients. Enforce parser limits before allocating memory: maximum string length (configurable, default 8 MiB), maximum nesting depth (configurable, default 1024), maximum object size (configurable, default 1 million entries), and maximum total document size (configurable, default 32 MiB).
- **Reserved namespace injection:** An attacker could craft a JSON object that looks like a CID or bytes value but contains malicious data. The decoder must validate that CID strings parse to valid CIDs and that base64url strings decode to the expected bytes. Invalid forms must be rejected rather than interpreted as plain maps.
- **Deterministic hashing:** Canonical ordering and whitespace stripping are required for content addressing. Any deviation from canonical DAG-JSON produces a different CID and breaks deduplication, verifiability, and interoperability.
- **JSON parsing safety:** The underlying JSON parser must be safe against deeply nested structures, extremely long strings, and number overflows. If the parser returns doubles for all numbers, the decoder must distinguish integers from floats by inspecting the raw JSON token before conversion.
- **No eval:** The decoder must be a pure JSON parser. Do not use `eval`, `dart:mirrors`, or dynamic code execution to interpret JSON structures.
- **CID validation:** CID strings in the reserved namespace must be validated against the CID specification. Unknown multibase prefixes, invalid lengths, and malformed multihash bytes must be rejected.
- **Backward compatibility shim:** If a compatibility shim is introduced for the old `IPLDCodec` interface, it must be clearly marked as deprecated and scheduled for removal in v2.1. It must not be used for new code or for hashing.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- **Reserved namespace:** Test encoding and decoding of bytes and CID links, including CIDv0 and CIDv1. Verify base64url without padding and Base32 lowercase for CIDv1.
- **Invalid reserved namespace:** Test rejection of maps with malformed `/` keys, extra keys, wrong inner types, and invalid base64url/CID strings.
- **Key sorting:** Test maps with keys of varying lengths and lexicographic similarity. Verify the order is by length then lexicographic bytes.
- **Whitespace:** Test that encoded strings contain no whitespace and that decoding accepts standard JSON whitespace (which is discarded during parsing).
- **Integer/float distinction:** Test encoding of `1` vs `1.0`, `0` vs `0.0`, and large integers. Test decoding of numbers with and without fractional/exponent components.
- **Big integers:** Test behavior for integers outside the safe JSON range, including exact round-trip when supported and clear errors when unsupported.
- **Round-trip primitives:** Test null, boolean, string, list, and nested map values.

### 7.2 Round-Trip Tests

- Encode a representative set of IPLD nodes as DAG-JSON, decode them, and verify the decoded nodes equal the originals.
- For nodes that can be represented in both DAG-CBOR and DAG-JSON, encode to both codecs and verify that the logical content is identical. The CIDs will differ because the codec codes differ.
- Round-trip the cross-codec fixtures from the IPLD DAG-JSON spec and compare the decoded nodes to the corresponding DAG-CBOR fixtures.

### 7.3 Interoperability Tests with Kubo and Helia

Create a CI job or local Docker Compose stack that runs the latest Kubo and Helia stable versions and exercises:

- **DAG get/put:** Dart_ipfs stores a DAG-JSON node; Kubo `dag get` returns the same canonical JSON string and CID. Reverse direction also works.
- **RPC responses:** Dart_ipfs RPC endpoints that return JSON use the DAG-JSON reserved namespace for bytes and CIDs, matching Kubo's behavior.
- **Cross-codec CID consistency:** A node encoded as DAG-CBOR and DAG-JSON yields the expected logical content in both Kubo and Helia, even though the CIDs differ by codec.
- **Fixture parity:** The DAG-JSON cross-codec fixtures decode to the same nodes in dart_ipfs, Kubo, and Helia.

Use fixed fixtures from the IPLD specs for determinism, and add a smaller set of randomized property-based tests to fuzz the encoder/decoder with nested maps, CIDs, and byte strings.

### 7.4 Regression Tests

- Add a test that asserts `lib/src/codec/dag_json_codec.dart` no longer contains a competing implementation or that it re-exports `standard_codecs.dart`.
- Add a test that asserts the duplicate `IPLDCodec` interface is removed.
- Regenerate any JSON fixtures that were previously produced by the old implementation and verify they now match the canonical forms.

---

## 8. Dependencies and Ordering

1. **IPLD Data Model types (prerequisite):** The same `IPLDNode` types used by DAG-CBOR must be used by DAG-JSON.
2. **DAG-CBOR P0 (prerequisite):** The DAG-JSON consolidation should land after DAG-CBOR is solid so that cross-codec tests can be run against the same node types and the same data-model semantics.
3. **CID codec (prerequisite):** DAG-JSON must parse and serialize CIDs correctly, including CIDv0 Base58 and CIDv1 Base32.
4. **Base64/base58/base32 encoders (prerequisite):** Standard Dart libraries or multiformats packages must provide correct base64url-no-padding, Base58, and Base32 lowercase encoders.
5. **This DAG-JSON P1 backlog item:** Land after DAG-CBOR. This completes the core codec suite for v2.0.
6. **CAR v1/v2 P0 (dependent):** CAR headers are DAG-CBOR, but some gateway and RPC consumers may use DAG-JSON for debugging or configuration.
7. **IPLD Selectors P0 (dependent):** Selectors may be serialized as DAG-JSON for human-readable debugging, but the canonical form is DAG-CBOR.
8. **GraphSync P1 (dependent):** GraphSync message metadata may use DAG-JSON for debugging, but block payloads are binary.

---

## 9. Backward Compatibility Notes

- **v2.0 breaking change:** The duplicate `dag_json_codec.dart` implementation and its `IPLDCodec` interface are removed. Any code that imported `dag_json_codec.dart` must import the `DagJsonCodec` from `lib/src/codec/standard_codecs.dart`. Document this in `CHANGELOG.md` and the migration guide.
- **Compatibility shim:** If external consumers depend on the old `IPLDCodec` interface, introduce a short compatibility shim in v2.0.0-rc that re-exports the new interface under the old name, and remove it in v2.1. The shim must be clearly marked as deprecated.
- **Canonical output change:** The old `DagJsonCodec` may have emitted whitespace or non-canonical key ordering. The new output will be compact and canonical. Any stored DAG-JSON strings that were hashed or compared as strings will need to be regenerated.
- **Internal consumers:** Update all internal callers that previously used the old DAG-JSON implementation. This includes RPC handlers, logging, and any configuration files that use DAG-JSON for IPLD data.
- **Interop default:** After landing, the default CI checks must pass against the latest Kubo and Helia stable versions. Any future regression that breaks DAG-JSON fixture parity or canonical output is a release blocker.
