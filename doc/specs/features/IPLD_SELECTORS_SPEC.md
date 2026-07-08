# dart_ipfs v2.0 — IPLD Selector Execution Specification

**Status:** Council of Five Approved P0 Backlog  
**Target Release:** v2.0  
**Priority:** P0 — Blocker for GraphSync responses and selective DAG retrieval  

---

## 1. Goal and Scope

This specification defines the work required to replace the custom `SelectorType` model in dart_ipfs with the official IPLD selector vocabulary and a spec-compliant selector interpreter. IPLD selectors are queries that describe a traversal over a DAG and return a subset of nodes and links. They are the core mechanism used by GraphSync to request and transfer only the relevant portion of a DAG, and they are used by IPFS for partial traversal, indexing, and trustless retrieval.

After completion, dart_ipfs must:

- Represent selectors as a typed AST that mirrors the official IPLD selector schema.
- Parse selectors from DAG-CBOR and DAG-JSON forms into the typed AST, rejecting unknown or malformed selectors.
- Execute selectors against the local block store, yielding every matched node with its CID and optional path.
- Respect configurable budgets for recursion depth and total node count to prevent resource exhaustion.
- Wire selector execution into `IPLDHandler` and `GraphsyncHandler` so that GraphSync responses can attach the exact blocks selected by a request.

Scope includes the full selector vocabulary used by IPFS and GraphSync. Out of scope for this backlog item: custom selector extensions not in the official vocabulary; full IPLD Schema validation of selector shapes (deferred to P2); selector optimization for extremely large DAGs beyond the configured budgets.

---

## 2. Official References

All behavior must be derived from the current IPLD selector specification and its fixtures.

- **IPLD Selectors specification:** `https://ipld.io/specs/selectors/`
- **Selector fixtures 1:** `https://ipld.io/specs/selectors/selector-fixtures-1/`
- **Selector fixtures recursion:** `https://ipld.io/specs/selectors/selector-fixtures-recursion/`
- **IPLD Data Model:** `https://ipld.io/specs/data-model/`
- **DAG-CBOR specification (selectors are encoded as DAG-CBOR):** `https://ipld.io/specs/codecs/dag-cbor/spec/`
- **DAG-JSON specification:** `https://ipld.io/specs/codecs/dag-json/spec/`
- **GraphSync specification (selector consumer):** `https://ipld.io/specs/transport/graphsync/`
- **Trustless Gateway specification (selectors for partial retrieval):** `https://specs.ipfs.tech/http-gateways/trustless-gateway/`
- **CID specification:** `https://github.com/multiformats/cid`

Reference implementations for interoperability verification:

- **go-ipld-prime selectors:** `https://github.com/ipld/go-ipld-prime/tree/master/traversal/selector`.
- **js-ipld-selectors:** `https://github.com/ipld/js-ipld-selectors`.
- **Kubo:** `https://github.com/ipfs/kubo` (GraphSync and `ipfs dag get` with selectors).
- **Helia:** `https://github.com/ipfs/helia` with GraphSync provider support.
- **go-graphsync:** `https://github.com/ipfs/go-graphsync`.

---

## 3. Current State in dart_ipfs

The current selector implementation is custom and not compatible with the official vocabulary.

- **File:** `lib/src/core/ipfs_node/ipld_handler.dart` uses a hand-rolled `SelectorType` model that does not match the official selector schema.
- **Gap:** The custom selector model cannot be serialized as DAG-CBOR or DAG-JSON, so it cannot be exchanged with Kubo, Helia, or any other IPLD implementation.
- **Gap:** The custom selector model cannot be traversed to produce a set of blocks, so `GraphsyncHandler` cannot use it for selective block retrieval.
- **Gap:** The selector vocabulary does not include `exploreRecursive`, `exploreInterpretAs`, `matcher`, `limit`, or `condition`, which are required for GraphSync.
- **Gap:** There is no budget enforcement for recursion depth or node count, so a malicious selector could exhaust memory or CPU.
- **Dependency:** IPLD selectors are encoded as DAG-CBOR nodes, so this backlog item depends on the DAG-CBOR codec being spec-compliant. GraphSync integration also depends on the CAR v1/v2 codec for block payload framing.

---

## 4. Target State / Requirements

### 4.1 Selector Vocabulary

The implementation must support the official selector types used by IPFS and GraphSync. Selectors are represented as DAG-CBOR (or DAG-JSON) maps with a single canonical key per selector.

- **`exploreAll`** — Traverse every key/value pair of a map or every index of a list. The selector applies the `next` selector to each child.
- **`exploreFields`** — Traverse a named set of fields. The selector contains a map `fields` from string keys to selectors, and applies the corresponding selector to each named field.
- **`exploreIndex`** — Traverse a single list index. The selector contains an `index` and a `next` selector.
- **`exploreRange`** — Traverse a range of list indices. The selector contains `start`, `end`, and `next` selectors. The range is half-open: `[start, end)`.
- **`exploreRecursive`** — Recursive descent with a `limit` and a `sequence` selector. The limit controls how deep the recursion goes. The sequence may contain `exploreRecursiveEdge` markers that terminate the recursion pattern at the current depth.
- **`exploreRecursiveEdge`** — Marker that terminates the recursion pattern inside `exploreRecursive`. It is a placeholder that is replaced by the recursive continuation when the interpreter expands the pattern.
- **`exploreUnion`** — Apply a list of selectors to the same node. The selector contains a `members` list of selectors.
- **`exploreInterpretAs`** — Traverse with an Advanced Data Layout (ADL) interpretation. The selector contains a string `adl` (e.g., `"hamt/sha3-256"` or similar) and a `next` selector. This is required for traversing HAMT-sharded UnixFS directories in P1.
- **`matcher`** — Select the current node and return it. This is the leaf selector that causes nodes to be yielded by the interpreter.
- **`limit`** — Recursion limit helpers. The official vocabulary includes `depth` limits and the `recursiveEdge` sentinel. The implementation must parse and enforce `limit` nodes correctly.
- **`condition`** — P1 selector that includes or excludes nodes based on a condition. It may be deferred until GraphSync P1 fixtures require it, but if implemented it must support the official condition forms.

Example selector shapes:

```text
{ "exploreAll": { "next": { "matcher": {} } } }
{ "exploreRecursive": { "limit": { "depth": 3 }, "sequence": { "exploreAll": { "next": { "exploreRecursiveEdge": {} } } } } }
{ "exploreFields": { "fields": { "foo": { "matcher": {} }, "bar": { "exploreAll": { "next": { "matcher": {} } } } } } }
```

### 4.2 Typed Selector AST

Define a typed selector AST that mirrors the spec and can be parsed from and serialized to DAG-CBOR/DAG-JSON. Suggested class hierarchy (pseudo-code):

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

The AST must be immutable and equality must be value-based. Unknown selector keys or malformed shapes must be rejected at parse time with a clear `SelectorParseError`.

### 4.3 Selector Parsing

- **`Selector parseSelector(dynamic dagCborNode)`** — Deserialize a DAG-CBOR (or DAG-JSON) node into the typed AST. The input is typically an `IPLDMap`. The function must reject:
  - Unknown top-level selector keys.
  - Missing required fields (e.g., `exploreAll` without `next`).
  - Malformed field types (e.g., `index` that is not an integer, `fields` that is not a map).
  - `exploreRecursiveEdge` outside of an `exploreRecursive` sequence.
- The parser must be strict by default. A lenient mode may be provided for debugging but must not be used for network-received selectors.
- The parser must support both DAG-CBOR and DAG-JSON input because selectors may be received over the network in either form, but the canonical form is DAG-CBOR.

### 4.4 Selector Execution

- **`Stream<SelectedNode> executeSelector(CID root, Selector selector, {int? maxDepth, int? maxNodes, bool includePath = false})`** — Traverse the block store starting at `root`, following the selector, and yield every matched node.
  - `root`: the CID of the starting node.
  - `selector`: the parsed selector AST.
  - `maxDepth`: optional maximum recursion depth. The default must be a small, safe value (e.g., 32) and must be configurable. If the traversal exceeds the limit, throw `SelectorBudgetExceeded`.
  - `maxNodes`: optional maximum number of nodes to visit (matched or not). The default must be a small, safe value (e.g., 10,000) and must be configurable. If the traversal exceeds the limit, throw `SelectorBudgetExceeded`.
  - `includePath`: if true, each `SelectedNode` includes the IPLD path from the root to the node as a string. Paths must follow the IPLD path syntax and escape `/` and `~` per RFC 6901.
- **`SelectedNode`** contains:
  - `cid`: the CID of the selected block.
  - `node`: the IPLD data-model node (decoded from the block using the appropriate codec).
  - `path`: optional IPLD path string from the root to the node.
  - `remainingDepth`: the remaining recursion budget at the point of selection.
- The interpreter must load blocks from the block store lazily. It must not load the entire DAG before starting traversal.
- The interpreter must handle links correctly: when a selector follows a CID link, it fetches the linked block, decodes it, and applies the next selector to the decoded node.
- The interpreter must handle ADL interpretation: when `exploreInterpretAs` is encountered with a recognized ADL (e.g., HAMT), the interpreter must load the ADL data layout and traverse it as if it were a plain map or list.

### 4.5 GraphSync Integration

- In `GraphsyncHandler`, when a request contains a selector, decode it, call `executeSelector(request.root, selector)`, and attach the resulting blocks to the `GraphsyncMessage.blocks` field of the response.
- The response must include every block that is selected by the selector, including the root block. The order of blocks in the response is not significant for correctness, but the implementation should preserve a deterministic order for testing.
- The selector must be serialized as DAG-CBOR before being sent in a GraphSync request and parsed on the receiving side. Round-trip must preserve semantics.
- The GraphSync message format itself (header, request/response ids, extensions) is defined in the networking backlog, but the block attachment contract is: every selected block appears as a CID/block pair in the response.

### 4.6 IPLDHandler Integration

- `IPLDHandler` must expose a method to execute a selector against a root CID and return the selected nodes or a stream of selected nodes.
- The old `SelectorType` model is removed. Any internal code that used the old model is refactored to use the official selector AST and parser.
- `IPLDHandler` may provide a convenience method to accept a selector as a DAG-CBOR/DAG-JSON string and parse it before execution.

---

## 5. Acceptance Criteria

1. **Fixture parity:** All selector fixtures from `selector-fixtures-1` and `selector-fixtures-recursion` produce the same set of selected CIDs as the reference Go implementation (go-ipld-prime selectors).
2. **Matcher:** A `matcher` selector returns exactly the root node (and no other nodes).
3. **Recursive limits:** An `exploreRecursive` selector with a `depth` limit stops at the correct depth and does not follow links beyond the budget.
4. **Selector vocabulary:** `exploreFields`, `exploreIndex`, `exploreRange`, `exploreUnion`, and `exploreAll` are tested independently and in combination. `exploreInterpretAs` is tested against HAMT-sharded UnixFS directories in P1.
5. **GraphSync response:** The GraphSync handler can respond to a selector request with the requested blocks. A Kubo or Helia GraphSync client can decode the response and materialize the selected DAG.
6. **Selector round-trip:** Selectors are serialized to DAG-CBOR before being sent and parsed on the receiving side; round-trip preserves semantics and the same selected CID set.
7. **Budget enforcement:** `executeSelector` throws `SelectorBudgetExceeded` when `maxDepth` or `maxNodes` is exceeded. The default budgets are small and safe for network-received selectors.
8. **Malformed selector rejection:** Unknown selector keys, missing required fields, and malformed shapes are rejected with a clear `SelectorParseError`.
9. **Legacy removal:** The custom `SelectorType` model in `IPLDHandler` is removed and replaced by the official selector AST.

---

## 6. Security Considerations

- **Selector budgets:** `exploreRecursive` and `exploreAll` on large DAGs can exhaust memory or CPU. Always run selectors with `maxDepth` and `maxNodes` budgets. If a selector is received over the network, default budgets must be small and configurable. A selector that exceeds the budget must be rejected with `SelectorBudgetExceeded`, not allowed to consume resources.
- **Untrusted selectors:** A remote peer can send a selector designed to traverse a huge DAG or follow a cycle. The interpreter must:
  - Track visited CIDs to avoid revisiting the same block in the same traversal (unless the selector explicitly allows revisiting for a specific use case, which GraphSync does not).
  - Enforce `maxDepth` and `maxNodes` before loading blocks.
  - Refuse to load blocks larger than the configured maximum block size.
- **Path traversal:** If `includePath` is true, the path string must be constructed safely and must not rely on user-supplied data without escaping. IPLD paths must escape `/` and `~` per RFC 6901 to avoid ambiguity.
- **No eval:** Selector execution and schema validation must be interpreters, not code generators. Do not use `dart:mirrors` or string-to-code evaluation to implement selector logic. Selectors are data structures, not programs.
- **ADL safety:** `exploreInterpretAs` can load ADL interpreters such as HAMT. The interpreter must validate the ADL name and must not load arbitrary code based on the ADL string. Only recognized ADLs (e.g., HAMT with known hash functions) are allowed.
- **Block decoding:** Selected blocks are decoded using the appropriate codec (DAG-CBOR, DAG-PB, DAG-JSON, etc.). The decoder must be the spec-compliant decoder, not a lenient fallback, so that decoded content matches the selector's expectations.
- **Deterministic execution:** Given the same root, selector, and block store, the set of selected CIDs must be deterministic. This is required for GraphSync verifiability and for testing against fixtures.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- **Selector parsing:** Test parsing of each selector type from DAG-CBOR and DAG-JSON. Test rejection of unknown keys, missing fields, and malformed shapes.
- **Selector execution:** Test each selector type against hand-constructed DAGs:
  - `matcher` returns the root.
  - `exploreAll` traverses every child of a map/list.
  - `exploreFields` traverses only the named fields.
  - `exploreIndex` and `exploreRange` traverse list indices correctly.
  - `exploreUnion` applies all members.
  - `exploreRecursive` with `depth` limits stops at the correct depth.
- **Budget enforcement:** Test that `maxDepth` and `maxNodes` limits are enforced and that `SelectorBudgetExceeded` is thrown with a clear message.
- **Cycle detection:** Test that a cyclic DAG does not cause infinite recursion when the selector would otherwise revisit nodes.
- **Error cases:** Test malformed selectors, missing root blocks, and blocks that fail to decode.

### 7.2 Round-Trip Tests

- Parse a selector from DAG-CBOR, serialize it back to DAG-CBOR, and verify the bytes are identical (or at least semantically equivalent and produce the same selected CID set).
- Parse a selector from DAG-JSON, convert to DAG-CBOR, and verify the canonical DAG-CBOR form matches the reference fixture.
- Execute a selector against a root, serialize the selected nodes back to blocks, and verify the CIDs match the original blocks.

### 7.3 Interoperability Tests with Kubo and Helia

Create a CI job or local Docker Compose stack that runs the latest Kubo and Helia stable versions and exercises:

- **Selector fixtures:** A known selector fixture is executed against the same DAG in both dart_ipfs and a reference implementation; the selected CID sets are identical.
- **GraphSync:** A Kubo or Helia GraphSync client requests a selector from a dart_ipfs node. The client can decode the response and reconstruct the selected DAG. The reverse (dart_ipfs client requesting from Kubo/Helia) is tested where supported.
- **DAG traversal parity:** A selector that traverses a UnixFS directory or a custom DAG produces the same selected nodes in dart_ipfs and go-ipld-prime.
- **ADL parity (P1):** A selector that uses `exploreInterpretAs` to traverse a HAMT-sharded UnixFS directory produces the same selected nodes as Kubo and Helia.

Use fixed selector fixtures from the IPLD specs for determinism, and add a smaller set of randomized property-based tests to fuzz selector construction and execution against random DAGs.

### 7.4 Regression Tests

- Add a test that asserts the old `SelectorType` model is no longer present in `IPLDHandler` or is marked deprecated.
- Add tests that verify GraphSync responses include the exact blocks selected by a request.
- Regenerate any selector fixtures that were previously encoded with the custom model and verify they now match the official fixtures.

---

## 8. Dependencies and Ordering

1. **IPLD Data Model types (prerequisite):** The selector interpreter operates on `IPLDNode` values and needs the data-model types to be stable.
2. **DAG-CBOR P0 (prerequisite):** Selectors are encoded as DAG-CBOR. The DAG-CBOR codec must be spec-compliant before selectors can be parsed or serialized correctly.
3. **DAG-JSON P1 (prerequisite):** Selectors may be received as DAG-JSON for debugging or human-readable interfaces. The consolidated DAG-JSON codec must be available, though DAG-CBOR is the canonical form.
4. **CID codec (prerequisite):** The interpreter follows CID links and must parse and serialize CIDs correctly.
5. **Block store (prerequisite):** The interpreter needs a block store that supports get-by-CID and batch get operations.
6. **This IPLD Selectors P0 backlog item:** Land after DAG-CBOR. This unblocks GraphSync and selective DAG retrieval.
7. **CAR v1/v2 P0 (related):** CAR export may be used to package selected blocks, but the selector engine itself does not depend on CAR.
8. **UnixFS P0/P1 (related):** Selectors may traverse UnixFS DAGs. HAMT interpretation in selectors depends on the UnixFS P1 HAMT implementation.
9. **GraphSync P1 (dependent):** GraphSync handler wiring depends on the selector interpreter. The exact GraphSync message format is defined in the networking backlog, but the selector/block attachment contract is defined here.

---

## 9. Backward Compatibility Notes

- **v2.0 breaking change:** The custom `SelectorType` model in `IPLDHandler` is replaced by the official selector AST. Any stored selector JSON/CBOR must be re-encoded. If the project serializes selectors in configuration, a migration script should convert the old format to the new one or fail loudly if the old format is encountered.
- **API contract changes:** The public API for selector execution changes from the old `SelectorType` model to `Selector` AST and `executeSelector`. Document this in `CHANGELOG.md` and the migration guide.
- **Internal consumers:** Update all internal callers that previously used the old `SelectorType` model. This includes GraphSync handler integration, any RPC endpoints that accept selectors, and any indexing or traversal code.
- **GraphSync behavior change:** GraphSync responses will now include only the blocks selected by the request selector, rather than any custom behavior the old handler may have implemented. This is the correct spec behavior but may change test expectations.
- **Interop default:** After landing, the default CI checks must pass against the latest Kubo and Helia stable versions. Any future regression that breaks selector fixture parity or GraphSync selector response behavior is a release blocker.
