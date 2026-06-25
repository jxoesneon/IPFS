# dart_ipfs v2.0 — UnixFS Specification

**Status:** Council of Five Approved Backlog  
**Target Release:** v2.0 (basic directories P0; HAMT sharding and symlinks P1)  
**Priority:** P0 — Blocker for MFS, gateway path resolution, and content import/export  

---

## 1. Goal and Scope

This specification defines the work required to make dart_ipfs produce and resolve standard UnixFS directories, files, and (in P1) HAMT-sharded directories and symbolic links. UnixFS is the IPFS user-facing file system layer encoded on top of DAG-PB. After completion, dart_ipfs must build UnixFS DAGs that yield the same CIDs as Kubo and Helia for the same input data, and must resolve UnixFS paths against those DAGs in a manner compatible with the IPFS path resolution rules.

Scope is divided into two phases:

- **P0 — Basic directories and files:** Correct DAG-PB node construction, cumulative `Tsize` computation, file chunking, and path resolution for non-sharded directories.
- **P1 — HAMT sharding and symlinks:** Hash-Array Mapped Trie (HAMT) directory sharding for large directories, symlink nodes, and symlink-aware path resolution with cycle detection.

Out of scope for this backlog item: custom UnixFS metadata extensions; file mode and mtime handling beyond the standard Data message; UnixFS v1.5 feature flags; FUSE mount (deferred to v2.2/v3.0).

---

## 2. Official References

All implementation must be driven by the current versions of the UnixFS and DAG-PB specifications.

- **UnixFS specification:** `https://specs.ipfs.tech/unixfs/`
- **UnixFS path resolution:** `https://specs.ipfs.tech/unixfs/path-resolution/`
- **DAG-PB specification (codec used for UnixFS nodes):** `https://ipld.io/specs/codecs/dag-pb/spec/`
- **HAMT specification (UnixFS sharding):** `https://ipld.io/specs/advanced-data-layouts/hamt/spec/`
- **IPLD Data Model:** `https://ipld.io/specs/data-model/`
- **CID specification:** `https://github.com/multiformats/cid`
- **Multihash specification:** `https://github.com/multiformats/multihash`
- **Trustless Gateway specification:** `https://specs.ipfs.tech/http-gateways/trustless-gateway/`

Reference implementations for interoperability verification:

- **Kubo:** `https://github.com/ipfs/kubo` (commands `ipfs add -r`, `ipfs cat`, `ipfs ls`, `ipfs dag get`).
- **Helia:** `https://github.com/ipfs/helia` with `@helia/unixfs`.
- **go-unixfs:** `https://github.com/ipfs/go-unixfs`.
- **js-ipfs-unixfs:** `https://github.com/ipfs/js-ipfs-unixfs`.

---

## 3. Current State in dart_ipfs

The current UnixFS implementation can create directory PBNodes but is not yet fully compatible with other implementations.

- **File:** `lib/src/core/unixfs/` contains directory construction and path resolution logic.
- **Gap:** Cumulative `Tsize` values on directory links are wrong or missing, leading to different CIDs than Kubo and Helia for the same directory.
- **Gap:** Path resolution is not fully integrated with the block store; resolving a path may fail to fetch intermediate directory blocks or may use a stale in-memory cache.
- **Gap:** HAMT-sharded directories are not implemented, so very large directories cannot be represented with the same structure as Kubo.
- **Gap:** Symlink nodes (`Type = Symlink`) are not implemented, and the path resolver has no cycle guard for symlink following.
- **Dependency:** UnixFS nodes are encoded as DAG-PB, so the DAG-PB codec must be correct and deterministic. The DAG-PB codec depends on a correct protobuf encoder and on the CID codec.

---

## 4. Target State / Requirements

### 4.1 Data Structures

UnixFS nodes are encoded as DAG-PB nodes. The DAG-PB schema is:

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

The `data` field of a PBNode contains a protobuf `Data` message defined as:

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

#### Directory Nodes

- `Type = Directory`
- `data` field of the PBNode is absent or empty (the `Data` message is omitted for pure directories).
- `links` field contains one PBLink per child, with:
  - `hash` = CID of the child node.
  - `name` = the file or directory name as a UTF-8 string (path segment, no slash).
  - `tsize` = cumulative serialized size of the entire child subtree (the sum of the serialized sizes of every block reachable through the child, including the child block itself).

#### File Nodes

- `Type = File`
- `filesize` = total logical size of the file in bytes.
- `blocksizes` = logical size of each file chunk, in order, for chunked files. For a single-block inline file, `blocksizes` is empty and `filesize` equals the length of `Data`.
- `Data` field contains the raw file bytes when the file is small enough to fit in a single block (typically 256 KiB or less, depending on the chunker configuration). For larger files, the `Data` field is empty and the file is linked through `PBLink` entries.
- `links` field for chunked files contains one PBLink per chunk, with `name` empty and `tsize` equal to the serialized size of the chunk subtree (typically just the chunk block size).

#### Tsize Semantics

The `Tsize` of a `PBLink` is the cumulative serialized byte size of the DAG reachable through that link. It is computed as:

```text
Tsize(link) = serialized_size(link.hash) + sum(Tsize(child_link) for child_link in linked_node.links)
```

This value must be exact. It is used by path resolution, `ipfs ls`, and gateway responses. A single-byte difference produces a different CID for the parent directory and breaks interoperability with Kubo.

### 4.2 P0 — Basic Directory and File API

- **`UnixFSNode createDirectory(List<PBLink> links)`** — Builds a DAG-PB directory node, computes the CID, stores the block in the block store, and returns an immutable node object containing the CID, the block bytes, and the decoded UnixFS metadata.
- **`UnixFSNode addChildToDirectory(CID dirCid, String name, CID childCid, int childTsize)`** — Returns a new directory node without mutating the original. The directory is content-addressed; adding a child produces a new CID. This operation must fetch the existing directory, append or replace the named link, recompute the parent `Tsize`, and store the new block.
- **`int computeTsize(CID root)`** — Recursively computes the cumulative serialized size of a UnixFS subtree. Must respect a configurable maximum recursion depth and a configurable block size budget. Must detect cycles in the DAG and throw a `DAGCycleError` if a cycle is encountered.
- **`UnixFSPathResolver`** — Path resolution service:
  - `Future<CID> resolve(CID root, String path)` or `Future<UnixFSNode> resolve(root, path)`.
  - Splits `path` on `/`, ignoring empty segments and leading/trailing slashes.
  - Fetches each directory node from the block store, matches the next segment against `PBLink.name` using exact byte comparison, and follows the link.
  - Returns the final node or CID, or throws `PathResolutionError` if the path is invalid or a link is missing.
  - Rejects `..`, `.`, empty segments, and absolute paths that would escape the root.

### 4.3 P1 — HAMT-Sharded Directories

A HAMT-sharded directory is used when a directory exceeds a configured fanout threshold (Kubo defaults to 256 entries per shard). The HAMT encodes the directory as a trie keyed by the hash of the child names.

- **HAMTShard node:** `Type = HAMTShard`, `fanout` set to the shard fanout (typically 256), `hashType` set to the multihash code used to hash names (typically `0x12` for sha2-256), and `data` contains the UnixFS Data message with the HAMTShard type. The node's links point either to child shards or to leaf entries.
- **Shard construction:** When adding a child to a directory that exceeds the fanout threshold, the directory is converted into a HAMT shard. The shard must use the bitfield and child link layout defined by the IPLD HAMT spec. The link names encode the hash prefix and distinguish leaf entries from internal trie nodes.
- **Shard traversal:** Path resolution must detect a HAMTShard node and follow the appropriate trie path based on the hash of the remaining path segment. The traversal must respect the configured `fanout` and `hashType`.
- **Interoperability:** The shard structure must match Kubo and Helia so that a directory exported from dart_ipfs yields the same root CID as a directory exported from Kubo for the same file set.

### 4.4 P1 — Symlinks

- **Symlink node:** `Type = Symlink`, `data` field contains the target path as a UTF-8 byte string. Symlink nodes have no links.
- **Path resolution:** When the resolver encounters a Symlink node, it reads the target path and follows it relative to the link's parent directory. A symlink with an absolute target is resolved relative to the current resolution root.
- **Cycle guard:** The resolver must maintain a `Set<CID>` of visited symlink CIDs. If a symlink is encountered whose CID is already in the set, the resolver throws `SymlinkCycleError`. The cycle guard must be scoped to the current resolution request.
- **Symlink targets:** Targets may contain `..` and `.` segments, but the resolver must normalize them within the resolved root and must never escape above the root CID of the request.

---

## 5. Acceptance Criteria

### 5.1 P0 — Basic Directories and Files

1. A directory created by dart_ipfs and exported via `kubo dag get /ipfs/<cid>` returns the same PBNode bytes and CID as a directory created by Kubo for the same file set.
2. `Tsize` values on every directory link are equal to the cumulative block size of the linked subtree and match Kubo exactly.
3. A file chunked into multiple blocks produces the same `blocksizes`, `filesize`, and root CID as Kubo for the same chunker configuration.
4. `ipfs cat /ipfs/<dir-cid>/<sub-path>` against a dart_ipfs gateway (or a Kubo gateway pointed at a dart_ipfs-provided DAG) resolves the file and returns the correct bytes.
5. Path resolution rejects `..`, `.`, empty segments, and missing links with a clear `PathResolutionError`.
6. Round-trip: import a directory from Kubo via CAR, re-export it, and the resulting CID and CAR bytes are identical.

### 5.2 P1 — HAMT Sharding and Symlinks

7. A directory with more than the configured fanout threshold is encoded as a HAMT-sharded directory, and the root CID matches Kubo for the same input.
8. Path resolution through a HAMT-sharded directory returns the correct child node and behaves identically to Kubo for the same paths.
9. Symlink nodes are encoded with `Type = Symlink` and the target path stored in the `data` field.
10. Path resolution follows symlinks and detects cycles, throwing `SymlinkCycleError` before entering an infinite loop.
11. A symlink target containing `..` is normalized within the resolution root and cannot escape the root.

---

## 6. Security Considerations

- **Path traversal:** UnixFS path resolution must never allow a path to escape above the root CID. Reject `..`, empty segments, and absolute paths that resolve outside the root. This is critical for gateway security and for any RPC that accepts user-supplied paths.
- **Symlink safety:** Symlink targets (P1) must be resolved relative to the link and must be checked against a cycle guard before following. A malicious DAG can contain symlink cycles that exhaust memory or CPU if the resolver does not track visited links.
- **DAG cycles:** The `computeTsize` recursion and path resolution must detect cycles in the general DAG structure and throw a `DAGCycleError` rather than looping or overflowing the stack.
- **Resource limits:** Enforce a configurable maximum recursion depth, maximum path length, and maximum number of traversed nodes during path resolution. Large directories or deep symlinks must not exhaust memory.
- **Untrusted blocks:** All UnixFS nodes are content-addressed and decoded from untrusted blocks. The decoder must validate that the `Type` field is one of the known values, that lengths are consistent, and that the CID of the block matches the multihash of the bytes.
- **Deterministic encoding:** DAG-PB encoding must be deterministic. Protobuf field ordering, omitted optional fields, and zero-valued integers must match the canonical output used by Kubo and Helia. Any deviation changes the CID and breaks deduplication.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- **Directory creation:** Test that `createDirectory` produces a PBNode with the correct `Type`, links, and `Tsize` for a single child, multiple children, and an empty directory.
- **Tsize calculation:** Test `computeTsize` against hand-calculated values and against reference values from Kubo for small directories and single files.
- **File chunking:** Test that a file larger than the chunk size produces the expected number of links, the correct `blocksizes` array, and the correct `filesize`.
- **Path resolution:** Test resolution of valid paths, missing links, `..`, `.`, empty segments, and paths with consecutive slashes.
- **Error cases:** Test that malformed PBNode data, unknown `DataType` values, and missing `Type` fields are rejected.

### 7.2 Round-Trip Tests

- Build a directory in dart_ipfs, encode it as a DAG-PB block, decode it, and verify the decoded structure equals the original.
- Import a directory from Kubo via CAR, re-export it, and verify that the root CID and all intermediate CIDs match.
- Round-trip a file through `createFile` -> encode -> decode -> `ipfs cat` and verify the bytes are unchanged.

### 7.3 Interoperability Tests with Kubo and Helia

Create a CI job or local Docker Compose stack that runs the latest Kubo and Helia stable versions and exercises:

- **Directory CID parity:** Kubo `ipfs add -r` a directory; dart_ipfs imports the resulting DAG and the root CID matches. Dart_ipfs builds a directory; Kubo `ipfs cat /ipfs/<cid>/path` returns the same files.
- **CAR round-trip:** Export a UnixFS directory from Kubo as a CAR, import it into dart_ipfs, export it again, and compare the CAR bytes to the original.
- **Gateway path resolution:** A dart_ipfs gateway resolves `/ipfs/<dir-cid>/<sub-path>` and returns the same bytes as a Kubo gateway for the same CID and path.
- **HAMT parity (P1):** Create a directory with thousands of entries in Kubo and dart_ipfs and compare the root CIDs and selected path resolutions.
- **Symlink parity (P1):** Create symlinks in Kubo and dart_ipfs, resolve them through both gateways, and verify cycle detection behaves the same way.

Use fixed test fixtures for determinism, and add a smaller set of randomized property-based tests for fuzzing path resolution and directory construction.

### 7.4 Regression Tests

- Add tests that verify old incorrect `Tsize` values are no longer produced.
- Add tests that verify the CID of a known small directory matches a Kubo-generated fixture.
- Regenerate any test DAGs that were previously created with the buggy implementation and verify they now match reference values.

---

## 8. Dependencies and Ordering

1. **DAG-PB codec (prerequisite):** UnixFS nodes are encoded as DAG-PB. The DAG-PB codec must be deterministic and correct before UnixFS work can be verified.
2. **DAG-CBOR P0 (related but not blocking):** CAR v2 headers use DAG-CBOR, but UnixFS directory construction itself only requires DAG-PB. CAR export/import for UnixFS tests requires the CAR backlog item.
3. **CID codec (prerequisite):** Link CIDs must be parsed and serialized correctly.
4. **Block store integration (prerequisite):** Path resolution must fetch blocks from the block store; the block store must support get-by-CID and batch put operations.
5. **This UnixFS P0 backlog item:** Land after DAG-PB and block store. This unblocks MFS, gateway path resolution, and content import/export.
6. **CAR P0 (dependent):** UnixFS directories must be round-tripped through CAR files to Kubo and Helia.
7. **HAMT + symlinks P1 (dependent):** Add after basic directories are correct and tested. HAMT sharding depends on correct directory and path resolution semantics.
8. **GraphSync P1 (dependent):** GraphSync may use selectors to traverse UnixFS DAGs; the selector engine must understand DAG-PB links and, for P1, HAMT interpretation.

---

## 9. Backward Compatibility Notes

- **v2.0 breaking change:** Any UnixFS directories created by dart_ipfs v1.x that have incorrect `Tsize` values will produce different CIDs after this work. This is expected and desirable; the new CIDs will match Kubo and Helia. The old CID-based references will remain valid because content is still addressable by its CID, but new directories will have different root CIDs.
- **API contract changes:** If the current `UnixFSNode` API exposes mutable fields or non-standard metadata, refactor it to immutable value objects before v2.0. Document all breaking changes in `CHANGELOG.md`.
- **Internal consumers:** The MFS service, gateway path resolver, and content service must be updated to use the new `Tsize`-correct `createDirectory` and `addChildToDirectory` APIs. Any in-memory caching of directory CIDs must be invalidated when the directory is rebuilt.
- **Migration guidance:** Users who have stored incorrect UnixFS CIDs in persistent storage should be informed that re-importing the raw content through dart_ipfs v2.0 will produce new, standard CIDs. There is no in-place migration because the CID is the hash of the bytes.
- **Interop default:** After landing, the default CI checks must pass against the latest Kubo and Helia stable versions. Any future regression that breaks UnixFS CID parity or path resolution is a release blocker.
