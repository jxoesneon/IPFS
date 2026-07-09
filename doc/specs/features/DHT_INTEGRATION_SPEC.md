# Amino DHT Network Integration Specification for dart_ipfs

**Document:** `DHT_INTEGRATION_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\DHT_INTEGRATION_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Maintainer review (2026-06-25)  
**Status:** P0 Modified — implementation pending  
**Scope:** Iterative Kademlia DHT queries, provider-record validation, and reprovide sweep for public Amino DHT participation.

---

## 1. Goal and Scope

### 1.1 Goal

Finish `DHTClient` so dart_ipfs can join the public Amino DHT, bootstrap against `bootstrap.libp2p.io`, and be discoverable by Kubo and Helia. This requires iterative `FIND_NODE` and `GET_PROVIDERS`, request/response correlation, proper multiaddr encoding, provider validation, and a periodic reprovide sweep.

### 1.2 Scope

- Iterative Kademlia query algorithm for `FIND_NODE`, `GET_PROVIDERS`, and `GET_VALUE`.
- Correct request/response correlation with a request map or framing envelope.
- Multiaddr byte encoding for `Peer` entries.
- Provider record validation.
- Reprovide sweep for pinned and MFS roots.
- `ADD_PROVIDER` with XOR-ordered closest peers and batching.

### 1.3 Non-Goals

- DHT server-side record signing enforcement is deferred; validation of signed records is handled per record type (IPNS).
- Advanced Kademlia bucket refresh optimization beyond the reprovide sweep is out of scope.
- Persistence of the routing table is not required for v2.1.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| libp2p Kademlia DHT | https://github.com/libp2p/specs/blob/master/kad-dht/README.md | FIND_NODE, GET_PROVIDERS, ADD_PROVIDER, PUT_VALUE, GET_VALUE |
| libp2p Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Peer routing key derivation |
| multiformats / multiaddr | https://github.com/multiformats/multiaddr | Proper address byte encoding |
| IPNS Record | https://specs.ipfs.tech/ipns/ipns-record/ | DHT value format for IPNS records |
| Bitswap | https://specs.ipfs.tech/bitswap-protocol/ | Content routing consumers |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/dht/dht_client.dart` — current DHT client with single-hop queries.
- `lib/src/proto/dht/kademlia.proto` — protobuf message definitions.
- `lib/src/core/config/dht_config.dart` — DHT configuration.
- `lib/src/transport/libp2p_router.dart` — transport layer for DHT messages.

### 3.2 Gaps

- `findProviders` and `findPeer` only query the closest peers in the local routing table once; no iterative expansion.
- Raw multiaddr strings are sent as UTF-8 bytes instead of proper multiaddr byte encoding.
- Request/response correlation is missing; the client cannot match outbound requests to inbound responses.
- Provider records are not validated for signature, expiration, or address sanity.
- Reprovide sweep is not implemented.
- `ADD_PROVIDER` only sends to the closest peers without XOR ordering or batching.

---

## 4. Target State / Requirements

### 4.1 Protocol ID

- DHT protocol ID: `/ipfs/kad/1.0.0`

### 4.2 Message Format

Continue using the `Message` from `lib/src/proto/dht/kademlia.proto`:

- `type`: `PING`, `FIND_NODE`, `GET_PROVIDERS`, `ADD_PROVIDER`, `GET_VALUE`, `PUT_VALUE`.
- `key`: raw multihash bytes for content routing; peer ID bytes for peer routing.
- `clusterLevelRaw`: always 0.
- `providerPeers`: repeated `Peer` entries.
- `closerPeers`: repeated `Peer` entries.
- `record`: DHT record value.

Fix `Peer` address encoding to use proper multiaddr bytes:

```dart
kad.Peer()
  ..id = peerId.value
  ..addrs.addAll(addresses.map((a) => MultiAddr(a).toBytes()));
```

### 4.3 Request/Response Correlation

Introduce a request ID map:

```dart
class DHTClient {
  final Map<String, Completer<Uint8List>> _pendingRequests = {};

  Future<Uint8List> _sendRequest(PeerId peer, String protocol, Uint8List request) {
    final requestId = _generateRequestId();
    final completer = Completer<Uint8List>();
    _pendingRequests[requestId] = completer;
    _router.sendMessage(peer.toBase58(), _wrapRequest(requestId, request));
    return completer.future.timeout(_config.dht.requestTimeout);
  }

  void _handlePacket(NetworkPacket packet) {
    final wrapped = WrappedMessage.fromBuffer(packet.datagram);
    final completer = _pendingRequests.remove(wrapped.requestId);
    if (completer != null) completer.complete(wrapped.payload);
  }
}
```

If `RouterInterface` cannot support request IDs transparently, add a thin framing envelope:

```protobuf
message DHTEnvelope {
  bytes request_id = 1;
  bytes payload = 2;
}
```

### 4.4 Iterative Query Algorithm

```dart
Future<List<PeerId>> findProviders(String cid) async {
  final target = getRoutingKey(cid);
  final alpha = _config.dht.alpha;
  final k = _config.dht.bucketSize;
  final queried = <PeerId>{};
  final closest = PriorityQueue<PeerId>(byXORDistance(target));
  final providers = <PeerId>{};

  // Seed from routing table.
  closest.addAll(_routingTable.findClosestPeers(target, k));

  while (closest.isNotEmpty && queried.length < k * 2) {
    final batch = closest.takeUnqueried(alpha, queried);
    if (batch.isEmpty) break;

    final responses = await Future.wait(batch.map((p) => _getProviders(p, cid)));
    for (final r in responses) {
      providers.addAll(r.providerPeers.map(_convertKadPeerToPeerId));
      closest.addAll(r.closerPeers.map(_convertKadPeerToPeerId));
      queried.add(r.peer);
    }
  }
  return providers.toList();
}
```

### 4.5 Provider Record Validation

```dart
bool isValidProviderRecord(PeerId provider, String cid, DateTime? ttl) {
  // 1. Provider ID must be a valid peer ID.
  if (provider.value.isEmpty) return false;
  // 2. Address list must contain at least one parseable multiaddr.
  if (addrs.none((a) => MultiAddr.tryParse(a) != null)) return false;
  // 3. TTL if present must be in the future.
  if (ttl != null && ttl.isBefore(DateTime.now())) return false;
  // 4. (Optional) Sign record if DHT record signing is enabled.
  return true;
}
```

### 4.6 Reprovide Sweep (Owned by `REPROVIDE_SPEC.md`)

The periodic reprovide sweep is specified in `REPROVIDE_SPEC.md`. `DHT_INTEGRATION_SPEC.md` provides the primitive DHT operations (`ADD_PROVIDER`, iterative `GET_PROVIDERS`, etc.) that the reprovider consumes. Do not duplicate reprovide strategy logic here.

`DHTConfig` may expose the primitives the reprovider needs:

```dart
final int maxProvidersPerKey;
final bool validateProviderRecords;
```

### 4.7 APIs

```dart
class DHTClient {
  Future<List<PeerId>> findProviders(String cid);
  Future<PeerId?> findPeer(PeerId id);
  Future<void> addProvider(String cid, String providerId);
  Future<void> storeValue(String key, Uint8List value);
  Future<Uint8List?> getValue(String key);
  Future<void> reprovide();
}
```

---

## 5. Detailed Acceptance Criteria

- dart_ipfs can query `GET_PROVIDERS` iteratively and find providers for a CID published by Kubo.
- `ADD_PROVIDER` uses XOR-ordered closest peers and batching.
- Invalid provider records are dropped and not returned to callers.
- Request/response correlation matches every outbound DHT request to its inbound response.
- The primitive operations required by the reprovider (see `REPROVIDE_SPEC.md`) are available and correctly wired.
- `Peer` addresses are encoded as multiaddr bytes, not UTF-8 strings.
- `findPeer` returns a reachable peer via iterative peer routing.

---

## 6. Security Considerations

- **Sybil/eclipse**: Maintain Kademlia k-buckets with XOR distance. Limit incoming peers per bucket. Validate provider records.
- **Record poisoning**: Validate IPNS signatures and DHT record expiration. Reject records with mismatched public keys.
- **Amplification**: Rate-limit `ADD_PROVIDER` and `GET_PROVIDERS` per peer. Limit concurrent iterative queries.
- **Address spoofing**: Verify that provider addresses are parseable multiaddrs and that the provider ID is a valid peer ID before trusting a record.
- **Request flooding**: Cap the number of in-flight DHT requests and time them out to prevent memory exhaustion.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥85%)

- XOR distance ordering and priority queue behavior.
- Iterative query convergence with synthetic routing tables.
- Request/response correlation including timeout and cleanup.
- Provider record validation (valid, expired, malformed addresses).
- Multiaddr byte encoding round-trip.

### 7.2 Local DHT Network Tests

- Spin up 3–5 dart_ipfs nodes on localhost.
- Bootstrap from a local bootstrapper.
- Publish a CID and verify another node finds providers.
- Test iterative query convergence with `k=20`.
- Test provider record validation rejects malformed records.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command / Helia API | Expected Result |
|----------|--------------------------|-----------------|
| DHT provide/find | `ipfs dht provide <cid>` then dart_ipfs `findProviders` | dart_ipfs finds Kubo |
| DHT find peer | Kubo publishes its peer record; dart_ipfs `findPeer` | dart_ipfs resolves Kubo's addresses |
| ADD_PROVIDER | dart_ipfs `addProvider` for a CID, Kubo `ipfs dht findprovs <cid>` | Kubo finds dart_ipfs |
| Store/get value | Kubo `ipfs dht put <key> <value>`; dart_ipfs `getValue` | dart_ipfs reads the value |

### 7.4 CI Integration

- Add Kubo and Helia containers to the interop workflow.
- Run the DHT matrix nightly and on PRs touching `lib/src/protocols/dht`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- `RouterInterface` must support sending messages to a specific peer by protocol ID.
- `MultiAddr` must support `.toBytes()` and `.tryParse()`.

### 8.2 Order Relative to Other Features

- **Before**: IPNS DHT-first records (relies on `storeValue`/`getValue`), Bitswap content discovery (relies on `findProviders`), GraphSync server (uses DHT for provider discovery).
- **Parallel with**: QUIC, Gossipsub.
- **After**: Basic TCP transport and identity.

### 8.3 External Dependencies

- Kademlia protobuf generated code (existing in `lib/src/proto/dht`).
- Priority queue or heap implementation in Dart (`package:collection` or custom).

---

## 9. Backward Compatibility Notes

- `DHTClient` will add new `storeValue`, `getValue`, and `reprovide` methods; existing `findProviders`, `findPeer`, and `addProvider` signatures remain but behavior becomes iterative.
- The multiaddr byte encoding fix is wire-compatible with Kubo but may break existing dart_ipfs-only deployments that decoded the old string format. This is considered acceptable because the old format was non-compliant.
- No datastore migration is needed; the DHT routing table format remains compatible.
