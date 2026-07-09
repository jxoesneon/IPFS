# Server-Side GraphSync MVP Specification for dart_ipfs

**Document:** `GRAPHSYNC_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\GRAPHSYNC_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Maintainer review (2026-06-25)  
**Status:** P1 Modified — implementation pending  
**Scope:** Server-side response to GraphSync requests with selected blocks, selector budgets, Bitswap fallback, and unicast-only responses. Client-side matching and bidirectional pause/resume are deferred.

---

## 1. Goal and Scope

### 1.1 Goal

Respond to a single requesting peer with selected blocks in `GraphsyncMessage.blocks`, enforce selector depth, block-count, and byte budgets, and fall back to Bitswap for missing blocks. Stop broadcasting responses to all peers; use the existing `RouterInterface.sendMessage` unicast method. Bidirectional pause/resume and client-side response matching are deferred.

### 1.2 Scope

- GraphSync protocol registration (`/ipfs/graphsync/1.0.0`, optional `2.0.0`).
- Request validation and selector parsing.
- Traversal with budgets.
- Bitswap fallback for missing blocks.
- Unicast response to the requester.
- Configuration of default budgets and fallback behavior.

### 1.3 Non-Goals

- Bidirectional GraphSync pause/resume is deferred.
- Client-side response matching and request state machine are deferred; this spec covers server-side responses only.
- GraphSync 2.0 full selector support is optional and depends on the P0 IPLD selector implementation (`IPLD_SELECTORS_SPEC.md`).

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| IPFS GraphSync | https://specs.ipfs.tech/graphsync/ | Message format, request/response flow, selectors |
| IPLD Selectors | https://ipld.io/specs/selectors/ | Selector parsing and traversal |
| Bitswap | https://specs.ipfs.tech/bitswap-protocol/ | Fallback block retrieval |
| CID | https://github.com/multiformats/cid | Block identification |
| libp2p protocol negotiation | https://github.com/libp2p/specs/blob/master/connections/ | Stream protocol registration |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/graphsync/graphsync_handler.dart` — current response handler.
- `lib/src/proto/graphsync/graphsync.proto` — protobuf definitions.
- `lib/src/protocols/bitswap/bitswap_handler.dart` — Bitswap fallback target.

### 3.2 Gaps

- `GraphsyncHandler._handleNewRequest` broadcasts responses to all connected peers instead of unicasting to the requester.
- Responses contain only progress/completion metadata; `GraphsyncMessage.blocks` is never populated.
- `requestGraph()` falls back to Bitswap for the root block only.
- No selector depth or block-count budgets.

---

## 4. Target State / Requirements

### 4.1 Protocol IDs

- `/ipfs/graphsync/1.0.0` (required)
- `/ipfs/graphsync/2.0.0` (optional, depends on selector support)

### 4.2 Message Format

Use `lib/src/proto/graphsync/graphsync.proto`:

```protobuf
message GraphsyncMessage {
  bytes request_id = 1;
  repeated GraphsyncRequest requests = 2;
  repeated GraphsyncResponse responses = 3;
  repeated Block blocks = 4;
  bytes extensions = 5;
  bool complete = 6;
}

message Block {
  bytes prefix = 1;
  bytes data = 2;
}
```

`Block.prefix` must contain the CID prefix bytes (version + codec + hash function + hash length), not the full CID. For example, call `cid.toPrefixBytes()` if available, or construct the prefix from the CID header fields.

### 4.3 Request Handling

```dart
Future<void> _handleNewRequest(String peer, GraphsyncRequest request) async {
  // 1. Validate.
  if (!request.hasRoot() || !request.hasSelector()) {
    await _sendError(peer, request.id, 'missing root or selector');
    return;
  }

  // 2. Parse selector and budget.
  final budget = _parseBudget(request.extensions);
  final selector = await IPLDSelector.fromBytesAsync(request.selector);
  final root = CID.fromBytes(request.root);

  // 3. Collect blocks.
  final blocks = <Block>[];
  try {
    await _traverse(
      root,
      selector,
      budget,
      onBlock: (cid, data) {
        blocks.add(Block(prefix: cid.toPrefixBytes(), data: data));
      },
      onMissing: (cid) async {
        // Fall back to Bitswap for missing blocks using the existing API.
        final block = await _bitswap.wantBlock(cid.toString());
        if (block != null) {
          blocks.add(Block(prefix: cid.toPrefixBytes(), data: block.data));
        }
      },
    );
  } on BudgetExceededError catch (e) {
    await _sendError(peer, request.id, 'budget exceeded: ${e.message}');
    return;
  }

  // 4. Unicast response to requester.
  final response = _protocol.createResponse(
    requestId: request.id,
    status: ResponseStatus.RS_FULL,
    blocks: blocks,
  );
  await _sendResponseToPeer(peer, response);
}
```

### 4.4 Budgets

```dart
class SelectorBudget {
  final int maxDepth;
  final int maxBlocks;
  final int maxBytes;
  int _currentDepth = 0;
  int _currentBlocks = 0;
  int _currentBytes = 0;

  void checkBlock(int size) {
    if (++_currentBlocks > maxBlocks) throw BudgetExceededError('block count');
    _currentBytes += size;
    if (_currentBytes > maxBytes) throw BudgetExceededError('byte count');
  }

  void enterDepth() {
    if (++_currentDepth > maxDepth) throw BudgetExceededError('depth');
  }

  void leaveDepth() {
    if (_currentDepth > 0) _currentDepth--;
  }
}
```

Depth tracking must increment when entering a nested DAG node and decrement when leaving it; it must not count every visited block as a new depth level.

Default budgets:

- `maxDepth`: 32
- `maxBlocks`: 1024
- `maxBytes`: 16 MiB

### 4.5 Unicast Response Requirement

`GraphsyncHandler` must send responses only to the requesting peer. `RouterInterface.sendMessage(String peerIdStr, Uint8List message, {String? protocolId})` is already a unicast method, so the handler uses it directly. Broadcast fallback is prohibited.

```dart
Future<void> _sendResponseToPeer(String peer, GraphsyncMessage response) async {
  await _router.sendMessage(peer, response.writeToBuffer(), protocolId: protocolId);
}
```

### 4.6 Configuration

```dart
class GraphsyncConfig {
  final bool enabled;
  final int defaultMaxDepth;
  final int defaultMaxBlocks;
  final int defaultMaxBytes;
  final bool fallBackToBitswap;
}
```

### 4.7 APIs

```dart
class GraphsyncHandler {
  Future<void> start();
  Future<void> stop();
  Future<void> handleRequest(String peerId, GraphsyncRequest request);
  Future<void> _sendResponseToPeer(String peerId, GraphsyncMessage response);
}
```

---

## 5. Detailed Acceptance Criteria

- Server-side GraphSync responds to a single requester with blocks in `GraphsyncMessage.blocks`.
- Selector depth and block-count budgets are enforced and result in a clear error response when exceeded.
- Missing blocks fall back to Bitswap when `fallBackToBitswap` is true.
- No broadcast of GraphSync responses; unicast is required.
- Invalid requests (missing root or selector) return an error response to the requester.
- Response status codes follow the GraphSync spec (`RS_FULL`, `RS_PARTIAL`, `RS_REJECTED`, etc.).

---

## 6. Security Considerations

- Enforce budgets to prevent unbounded traversal and resource exhaustion.
- Validate selector bytes before parsing; reject malformed selectors.
- Do not traverse into blocks not reachable from the requested root CID to prevent arbitrary block exposure.
- Bitswap fallback must verify the CID of fetched blocks before including them in the GraphSync response.
- Do not allow recursive GraphSync requests triggered by fallback blocks to exceed the original budget.
- Limit the number of concurrent server-side requests to prevent DoS.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- GraphSync protobuf encode/decode round-trip.
- Selector traversal with simple recursive selectors.
- Budget enforcement at depth, block count, and byte limits.
- Bitswap fallback path and missing block handling.
- Unicast routing via `RouterInterface.sendMessage` with a specific peer.
- Invalid request handling.

### 7.2 Local Network Tests

- Serve a small DAG from a dart_ipfs node and request it from another dart_ipfs node.
- Verify that only the requester receives the response.
- Trigger budget exceeded and verify the error response.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo / Helia Client | Expected Result |
|----------|---------------------|-----------------|
| Full DAG request | Kubo requests a DAG via GraphSync | dart_ipfs returns all blocks |
| Budget exceeded | Request a large DAG with small budget | dart_ipfs returns `RS_REJECTED` / budget error |
| Bitswap fallback | Root exists but some child blocks missing | dart_ipfs fetches missing blocks via Bitswap and completes the response |

### 7.4 CI Integration

- Run GraphSync interop tests against Kubo and Helia clients.
- Enforce coverage thresholds for `lib/src/protocols/graphsync`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- **P0 IPLD selector implementation:** `IPLDSelector.fromBytesAsync` and selector execution must be implemented per `IPLD_SELECTORS_SPEC.md` before GraphSync can traverse DAGs correctly. GraphSync is sequenced after the selector implementation is complete.
- `RouterInterface.sendMessage(String peerIdStr, Uint8List message, {String? protocolId})` already provides unicast delivery; no new `supportsUnicast` guard is needed.
- `BitswapHandler.wantBlock` / `want` must be available for fallback.

### 8.2 Order Relative to Other Features

- **Before**: Client-side GraphSync (deferred).
- **Parallel with**: Bitswap HTTP Fallback (after the P0 IPLD selector is complete).
- **After**: Bitswap P2P, DHT, Circuit Relay, and the P0 IPLD selector implementation.

### 8.3 External Dependencies

- GraphSync protobuf generated code (existing in `lib/src/proto/graphsync`).
- IPLD selector implementation or bindings.
- Bitswap handler integration.

---

## 9. Backward Compatibility Notes

- GraphSync broadcast responses are removed immediately in v2.1; this is a breaking behavior change for any existing dart_ipfs-only GraphSync users, but it aligns with the spec.
- Bidirectional pause/resume and client-side response matching remain deferred; no new public APIs are introduced for them.
- `GraphsyncConfig` is additive; existing configs without it default to enabled with standard budgets.
