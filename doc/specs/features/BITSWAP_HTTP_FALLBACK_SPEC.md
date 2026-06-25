# Bitswap HTTP Fallback Specification for dart_ipfs

**Document:** `BITSWAP_HTTP_FALLBACK_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\BITSWAP_HTTP_FALLBACK_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** P1 Modified — implementation pending  
**Scope:** Integrate `HttpGatewayClient` as a fallback inside `BitswapHandler` after P2P attempts fail, and verify every HTTP-fetched block against its CID before storage.

---

## 1. Goal and Scope

### 1.1 Goal

Allow dart_ipfs to fetch blocks from HTTP gateways when P2P Bitswap fails or times out. Every block fetched over HTTP must be verified against the requested CID before it is stored or returned to callers. This increases content availability without weakening the trust model of content-addressed data.

### 1.2 Scope

- P2P Bitswap attempt with timeout.
- HTTP fallback to a configurable list of gateways.
- CID verification for raw blocks and CAR responses.
- Verified block caching in the local blockstore.
- Configuration of gateways, timeouts, and verification policy.

### 1.3 Non-Goals

- HTTP gateway upload/publishing is not required.
- CAR streaming parsing for multi-block responses is out of scope for the initial fallback; raw block fallback is the primary path.
- Gateway payment or authentication is deferred.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| IPFS Bitswap | https://specs.ipfs.tech/bitswap-protocol/ | P2P block exchange protocol |
| HTTP Gateway | https://specs.ipfs.tech/http-gateways/ | Trustless gateway endpoints and response formats |
| Trustless Gateway | https://specs.ipfs.tech/http-gateways/trustless-gateway/ | `/ipfs/<cid>?format=raw` and CAR semantics |
| CID | https://github.com/multiformats/cid | CID verification |
| multicodec | https://github.com/multiformats/multicodec | Codec constants for verification |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/bitswap/bitswap_handler.dart` — current P2P-only Bitswap handler.
- `lib/src/services/gateway/http_gateway_client.dart` — HTTP gateway client (to be integrated).
- `lib/src/core/config/ipfs_config.dart` — configuration where fallback settings should live.
- `lib/src/storage/blockstore.dart` — local blockstore for caching verified blocks.

### 3.2 Gaps

- `BitswapHandler` does not have an HTTP fallback; it only retries P2P.
- HTTP-fetched blocks are never verified against the requested CID.
- There is no configuration for fallback gateway URLs or timeouts.

---

## 4. Target State / Requirements

### 4.1 Protocol IDs

- P2P Bitswap: `/ipfs/bitswap/1.2.0`
- HTTP trustless gateway endpoints:
  - `/ipfs/<cid>?format=raw` (raw block)
  - `/ipfs/<cid>?format=car` (CAR) (optional)

### 4.2 Fallback Flow

```dart
Future<Block?> _getBlock(String cidStr, {Duration? p2pTimeout}) async {
  // 1. Try blockstore.
  final local = await _blockStore.getBlock(cidStr);
  if (local.found) return local.block;

  // 2. Try P2P Bitswap.
  try {
    final p2p = await _getBlockFromBitswap(cidStr).timeout(p2pTimeout ?? _config.p2pTimeout);
    if (p2p != null) return p2p;
  } catch (e) {
    _logger.debug('P2P Bitswap failed for $cidStr: $e');
  }

  // 3. Try HTTP gateway fallback.
  for (final gateway in _config.httpFallbackGateways) {
    try {
      final block = await _httpGatewayClient.fetchRawBlock(gateway, cidStr);
      if (block != null && _verifyBlock(block, cidStr)) {
        await _blockStore.putBlock(cidStr, block);
        return block;
      }
    } catch (e) {
      _logger.warning('HTTP fallback failed for $cidStr from $gateway: $e');
    }
  }
  return null;
}
```

### 4.3 CID Verification

```dart
bool _verifyBlock(Block block, String expectedCidStr) {
  final expectedCid = CID.decode(expectedCidStr);
  final actualHash = _hash(expectedCid.codec, block.data);
  return _listEquals(actualHash, expectedCid.multihash.digest);
}
```

If the codec is raw (`0x55`), verify the hash directly. If the codec is DAG-PB/DAG-CBOR/etc., verify the serialized block hash matches the CID multihash.

### 4.4 Configuration

Extend `BitswapConfig`:

```dart
class BitswapConfig {
  ...
  final List<String> httpFallbackGateways; // e.g., ['https://gateway.ipfs.io']
  final Duration p2pTimeout;
  final Duration httpTimeout;
  final bool verifyHttpBlocks;
}
```

### 4.5 APIs

```dart
class BitswapHandler {
  ...
  Future<Block?> getBlock(String cidStr, {bool useHttpFallback = true});
}
```

### 4.6 HTTP Gateway Client Requirements

- `fetchRawBlock(String gatewayUrl, String cidStr)` must issue a GET to `$gatewayUrl/ipfs/$cidStr?format=raw`.
- Respect `httpTimeout`.
- Return raw bytes or `null` on failure.
- Support CAR fallback only if the gateway does not support raw block format.

---

## 5. Detailed Acceptance Criteria

- P2P Bitswap is attempted first for every block request.
- HTTP fallback is used only after P2P timeout/failure.
- Every HTTP block is verified against the CID; mismatched blocks are discarded and logged.
- Verified HTTP blocks are stored in the local blockstore.
- The next request for the same CID returns the cached block without re-fetching.
- Gateway failures are retried against the next configured gateway.
- `verifyHttpBlocks` defaults to true and cannot be disabled in production builds.

---

## 6. Security Considerations

- Verification is mandatory by default. Untrusted HTTP gateways cannot inject invalid blocks because the multihash must match.
- Use `format=raw` to receive the canonical block bytes; avoid trusting gateway-rendered content.
- Validate gateway URLs to prevent open redirects or SSRF (e.g., reject `localhost`, `127.0.0.1`, and private ranges unless explicitly allowed).
- Limit the size of HTTP responses to prevent memory exhaustion; reject blocks larger than a configurable maximum.
- Do not send request metadata that could identify the user to untrusted gateways unless required by the gateway.
- HTTPS gateways should be preferred; HTTP gateways should log a warning.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- Fallback ordering: blockstore hit, P2P success, P2P failure then HTTP success.
- CID verification for raw, DAG-PB, and DAG-CBOR blocks.
- HTTP gateway failure and retry to the next gateway.
- Caching behavior after a verified HTTP fetch.
- `verifyHttpBlocks` false path (discouraged but testable in tests).

### 7.2 Local Network Tests

- Start a local HTTP gateway mock that serves a known block and verify dart_ipfs fetches and verifies it after P2P failure.
- Simulate a bad gateway returning wrong bytes and verify dart_ipfs discards them.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo / Helia Setup | Expected Result |
|----------|---------------------|-----------------|
| P2P success | Kubo has the block | dart_ipfs fetches via Bitswap |
| HTTP fallback | Kubo offline; public gateway has the block | dart_ipfs fetches and verifies via HTTP |
| Verification failure | Gateway returns wrong bytes | dart_ipfs discards and tries next gateway |

### 7.4 CI Integration

- Add HTTP gateway mock to unit tests.
- Run interop tests with a Kubo node and a mock gateway in CI.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- `HttpGatewayClient` must support `fetchRawBlock`.
- Blockstore must support `getBlock`/`putBlock`.
- CID and multihash verification utilities must be available.

### 8.2 Order Relative to Other Features

- **Before**: GraphSync server (uses Bitswap fallback).
- **Parallel with**: DHT Integration, IPNS, Gateway TLS.
- **After**: P2P Bitswap baseline.

### 8.3 External Dependencies

- `package:http` or equivalent for HTTP requests.
- `package:multihash` or equivalent for hash verification.

---

## 9. Backward Compatibility Notes

- `BitswapConfig` gains new optional fields; existing configs continue to work with P2P-only behavior.
- `getBlock` gains an optional `useHttpFallback` parameter defaulting to true; callers that previously assumed pure P2P can set it to false.
- The HTTP fallback introduces a new trust assumption (the gateway) but mitigates it with mandatory CID verification. Document this for operators.
- No wire-format changes to P2P Bitswap.
