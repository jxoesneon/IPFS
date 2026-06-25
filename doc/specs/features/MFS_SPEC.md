# MFS Completeness Specification

**Document ID:** `MFS_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P0 (must ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.1

---

## 1. Goal and Scope

The goal of this specification is to complete the Mutable File System (MFS) layer in dart_ipfs so that it is a Kubo-compatible implementation of the `/api/v0/files/*` RPC surface. The scope covers the existing `MFSManager` in `lib/src/core/mfs/mfs_manager.dart` plus all new RPC handlers required to expose MFS operations over HTTP. This work is a prerequisite for any tool that expects to use dart_ipfs as a drop-in replacement for a Kubo node when manipulating mutable files, directories, and roots.

Specifically, this specification addresses:

- Materializing MFS mutations to the blockstore (`flush`, `flushAll`, `sync`).
- Full Kubo-compatible `read`, `write`, `stat`, `ls`, `cp`, `mv`, `rm`, `mkdir`, and `chcid` semantics.
- The complete `/api/v0/files/*` endpoint matrix.
- Preservation of the root CID in `/mfs/root` after every mutation.
- Path normalization, traversal prevention, and additive API changes only.

Out of scope: UnixFS chunking algorithm changes, write-back caching, remote MFS, and FUSE mounts.

---

## 2. Official References

- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — endpoint paths, query parameters, request/response formats, and NDJSON streaming.
- [Kubo `files` command reference](https://docs.ipfs.tech/reference/kubo/cli/#ipfs-files) — MFS semantics, `flush`, `write`, `read`, `stat`, `ls`, `chcid`, and flag defaults.
- [IPFS Gateway Specification - Path Gateway](https://specs.ipfs.tech/http-gateways/path-gateway/) — path routing conventions that MFS content may later be served through.
- [IPLD DAG-PB specification](https://ipld.io/specs/codecs/dag-pb/spec/) — underlying data model for UnixFS directories and files.
- [UnixFS specification](https://specs.ipfs.tech/unixfs/) — file and directory node encoding rules that MFS must honor when building and mutating DAGs.

---

## 3. Current State in dart_ipfs

The current MFS implementation is in `lib/src/core/mfs/mfs_manager.dart` and persists its root CID via `/mfs/root` in the datastore. The `MFSManager` constructor is at lines 17–19 and `init()` is at lines 28–42; the constructor takes an `IBlockStore` and a `Datastore`, and `init()` loads the root CID from `/mfs/root` or creates an empty root directory. The following methods exist today:

- `mkdir(String path, {bool recursive = false})`
- `cp(String src, String dest)`
- `rm(String path, {bool recursive = false})`
- `ls(String path)` — returns `List<PBLink>` instead of Kubo-compatible `MFSListEntry`.
- `stat(String path)` — returns a `Map<String, dynamic>` with a reduced field set and an incomplete cumulative size calculation.
- `write(String path, Stream<List<int>> data, {bool create = true})`
- `read(String path)` — returns `Stream<List<int>>` but does not support `offset` or `count`.

Key gaps:

- No `flush`/`sync` semantics; mutations are applied immediately but the root CID persistence logic is not explicit and may not match Kubo semantics.
- No `mv`, `chcid`, `flushAll`, or `flush(path)` methods.
- `stat` does not return `WithLocal`, `Local`, `Mode`, `Mtime`, or the correct Kubo field names (`Hash`, `Size`, `CumulativeSize`, `Blocks`, `Type`).
- `ls` does not return the Kubo `Entries` wrapper with `Name`, `Type`, `Size`, `Hash`, `Mode`, `Mtime`.
- No `/api/v0/files/*` RPC handlers exist in `lib/src/services/rpc/rpc_handlers.dart`.
- Path traversal (`../`) is not explicitly normalized and rejected at the root boundary.
- The `write` method does not support `offset`, `truncate`, or partial file updates.

---

## 4. Target State / Requirements

### 4.1 Internal API

Extend `MFSManager` in `lib/src/core/mfs/mfs_manager.dart` with the following method signatures. All changes are additive; existing signatures must remain source-compatible.

```text
MFSManager
├── Future<CID> flush({String? path})
├── Future<CID> flushAll()
├── Future<void> sync()
├── Future<MFSStat> stat(String path, {bool withLocal = false})
├── Future<List<MFSListEntry>> ls(String path, {bool long = false, bool u = false})
├── Future<Stream<List<int>>> read(String path, {int? offset, int? count})
├── Future<void> write(
│       String path,
│       Stream<List<int>> data,
│       {bool create = true, int? offset, bool truncate = true})
├── Future<void> cp(String src, String dst)
├── Future<void> mv(String src, String dst)
├── Future<void> rm(String path, {bool recursive = false, bool force = false})
├── Future<void> mkdir(String path, {bool recursive = false, bool parents = false})
└── Future<void> chcid(String path, {String? cid, String? hash = 'sha2-256'})
```

`MFSManager` is constructed with an `IBlockStore` and a `Datastore` and must be registered as an `ILifecycle` service in `LifecycleManager`. RPC handlers obtain the shared instance from `IPFSNode` (or a service locator) so that internal API tests can instantiate `MFSManager` directly without starting the RPC server.

**Semantics:**

- `flush([path])` ensures the current MFS state is persisted and returns the current root CID. The existing implementation already persists the root CID after every mutation (`_modifyPath` at lines 259–273), so `flush` is effectively a synchronous root-CID accessor that may return the existing root without re-hashing. If a future implementation introduces a write-back cache, `flush` must force any pending mutations to the blockstore and persist the root CID to `/mfs/root` before returning.
- `flushAll()` is equivalent to `flush('/')`.
- `sync()` waits for all in-flight MFS operations to complete and ensures the root CID is persisted. It returns `void` and does not guarantee a new CID if no writes are pending.
- `stat` returns Kubo-compatible metadata with field names `Hash`, `Size`, `CumulativeSize`, `Blocks`, `Type`, and optional `WithLocal`, `Local`, `Mode`, `Mtime`.
- `ls` returns entries with `Name`, `Type` (0=raw, 1=directory, 2=file per Kubo), `Size`, `Hash`, and optional `Mode`/`Mtime` when `long=true`.
- `write` supports `offset` for partial writes, `truncate=true` to replace existing content, and `truncate=false` with `offset=0` to require an existing file. Throws `ArgumentError` if `offset` is beyond file size and `truncate=false`. For `truncate=false`, the implementation must read the existing UnixFS file, replace the affected byte range, and re-chunk only the modified segment if possible; unmodified bytes should preserve existing chunk boundaries and CIDs to the extent the chunking algorithm allows, which is required for Kubo parity.
- `chcid` re-hashes the CID for a path (or the whole MFS root if `path='/'`) using the requested multihash function. The current `CID.fromContent` accepts a `hashType` parameter but only supports `sha2-256` (it throws `UnsupportedError` for other hashes). Therefore, changing the hash function to anything other than `sha2-256` requires a full re-encode/re-layout pass of the affected DAG. Re-hashing with `sha2-256` is effectively a no-op for already-present data.

### 4.2 Data Models

```text
MFSStat
  Hash: String          // CID string
  Size: int             // file bytes, 0 for directories
  CumulativeSize: int   // UnixFS cumulative size
  Blocks: int           // link count
  Type: String          // "file" | "directory" | "raw"
  WithLocal: bool?      // present when requested
  Local: bool?          // present when requested
  Mode: int?            // optional UNIX mode
  Mtime: int?           // optional seconds since epoch

MFSListEntry
  Name: String
  Type: int             // Kubo: 0=raw, 1=directory, 2=file
  Size: int
  Hash: String
  Mode: int?            // when long=true
  Mtime: int?           // when long=true
```

### 4.3 RPC Endpoints

Register the following handlers in `lib/src/services/rpc/rpc_handlers.dart` and wire them in `RPCServer`:

| Method | Endpoint | Kubo-compatible parameters |
|--------|----------|------------------------------|
| POST | `/api/v0/files/ls` | `arg` (path), `long`, `U` (unsorted) |
| POST | `/api/v0/files/stat` | `arg`, `with-local`, `size` (hash only), `cid-base` |
| POST | `/api/v0/files/read` | `arg`, `offset`, `count` |
| POST | `/api/v0/files/write` | `arg` (multipart file body), `create`, `offset`, `truncate`, `count`, `raw-leaves`, `cid-version` |
| POST | `/api/v0/files/mkdir` | `arg`, `parents`/`recursive`, `cid-version`, `hash` |
| POST | `/api/v0/files/cp` | `arg` (source), `arg` (destination) — two `arg` params |
| POST | `/api/v0/files/mv` | `arg` (source), `arg` (destination) |
| POST | `/api/v0/files/rm` | `arg`, `recursive`, `force` |
| POST | `/api/v0/files/flush` | `arg` (default `/`) |
| POST | `/api/v0/files/chcid` | `arg`, `cid-version`, `hash` |

**Response formats:**

- `files/ls` returns a single JSON object with `Entries` array and `Hash`.
- `files/stat` returns Kubo-style JSON.
- `files/read` returns raw bytes with `Content-Type: application/octet-stream`.
- `files/write` returns `200 OK` with empty body on success; multipart body is identical to `/api/v0/add`.
- `files/flush` returns JSON `{ "Hash": "<root-cid>" }`.
- `files/cp`, `files/mv`, `files/rm`, `files/mkdir`, `files/chcid` return `200 OK` with empty body on success, or Kubo-style error JSON on failure.

---

## 5. Detailed Acceptance Criteria

- [ ] `MFSManager` passes a Kubo parity test matrix for `write/read/stat/ls/cp/mv/rm/mkdir/flush` on both files and directories.
- [ ] `flush` persists the root CID in `/mfs/root` and returns the correct root CID.
- [ ] All `/api/v0/files/*` endpoints listed above are registered and return Kubo-compatible JSON.
- [ ] Path validation rejects traversal outside the MFS root (`../` must be normalized and blocked at the root boundary).
- [ ] Multipart `files/write` supports the same file-size limits and boundary parsing as `handleAdd`.
- [ ] No existing MFS public API signatures are removed; only additive changes are allowed.
- [ ] `stat` cumulative size matches the Kubo definition for both files and directories.
- [ ] `write` with `offset` and `truncate=false` correctly patches existing file content without changing unmodified bytes.
- [ ] `write` with `offset` and `truncate=false` is validated against Kubo (not only unit tests) and preserves unmodified chunk CIDs where possible.
- [ ] `mkdir` with `parents=true` creates missing intermediate directories.
- [ ] `flush` on an already-persistent MFS returns the same root CID idempotently.
- [ ] `MFSManager` remains usable without RPC (internal API tests are standalone).

---

## 6. Security Considerations

- Path traversal: `MFSManager` must normalize paths and reject any attempt to escape above the MFS root (`/`) before any filesystem operation. This prevents RPC callers from accessing host paths or the parent namespace.
- Input validation: CID strings, offsets, and counts must be validated before use. Invalid input must return `400 Bad Request` with a Kubo-style error JSON.
- Denylist integration: when `Content Blocking / Compact Denylist` is enabled, MFS content is not automatically blocked at the MFS layer, but gateway/RPC serving of MFS-derived CIDs must still honor the denylist service.
- Root CID integrity: every mutation must atomically update the MFS root CID and persist it to `/mfs/root`. Concurrent mutations must be serialized to avoid a torn root.
- Resource limits: `files/write` must enforce the same multipart size limits as `handleAdd` to prevent unbounded memory consumption.

---

## 7. Testing Strategy

### 7.1 Unit Tests

Target greater than or equal to 80% coverage per MFS file:

- `MFSManager.flush` and `flushAll` on empty and populated MFS roots.
- `sync` with in-flight writes and no pending writes.
- `stat` for files, directories, and raw blocks, with and without `withLocal=true`.
- `ls` with `long=true` and `u=true`, and for empty directories.
- `write` with `create`, `offset`, `truncate=true/false`, and beyond-end offsets.
- `cp`, `mv`, `rm` (recursive and non-recursive), and `mkdir` (with and without `parents`).
- `chcid` with supported and unsupported multihash functions.
- Path normalization and traversal rejection.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to verify request/response contracts without starting a real HTTP server:

- All `/api/v0/files/*` endpoints return the correct JSON structure and status codes.
- Missing required `arg` parameters return Kubo-style error JSON with `Code` and `Message`.
- `files/read` returns `application/octet-stream` with correct byte ranges.
- `files/write` accepts the same multipart boundary parsing as `handleAdd`.

### 7.3 Interoperability Tests

Spin up a Kubo v0.42.0+ node and a dart_ipfs node in CI and verify:

- `dart_ipfs files/write` and `files/flush` produce CIDs that Kubo can `cat`.
- Kubo `files/stat` and dart_ipfs `files/stat` return identical metadata for the same UnixFS DAG.
- `dart_ipfs files/ls` and Kubo `files/ls` return the same entry ordering and fields.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| `CID` / `Block` / `UnixFSBuilder` | MFS mutations are built on top of these primitives. |
| `Datastore` / `IBlockStore` | Root CID persistence and block retrieval. |
| `MetricsCollector` | MFS RPC calls must be counted under `ipfs_rpc_requests_total` once metrics are implemented. |
| Real metrics collection (P0) | Required for acceptance criteria that count RPC requests. |

**Implementation order:**

1. Extend `MFSManager` internal API and data models.
2. Add RPC handlers for `/api/v0/files/*` and register them in `RPCServer`.
3. Wire path validation and traversal prevention.
4. Add unit and contract tests.
5. Run Kubo interoperability tests.

MFS completeness is a Phase 1 P0 foundation item and can be implemented in parallel with trustless gateway and metrics work.

---

## 9. Backward Compatibility Notes

- All existing `MFSManager` public method signatures must remain source-compatible. New parameters must be optional with sensible defaults.
- Existing behavior that immediately persists the root CID after every mutation (`_modifyPath` at lines 259–273) may continue to do so internally. In this mode `flush` and `sync` are synchronous root-CID accessors that return the current root CID without introducing a separate in-memory delta layer.
- No existing MFS RPC endpoints exist today, so no RPC backward compatibility constraint applies.
- If a future implementation introduces a write-back cache, `flush`/`sync` must still force persistence to the blockstore and must not change the public API.
