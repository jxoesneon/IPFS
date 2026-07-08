# IPNS DHT-First Signed Records Specification for dart_ipfs

**Document:** `IPNS_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\IPNS_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** P0 Modified — implementation pending  
**Scope:** DHT-first IPNS record publishing and resolution with Ed25519 signed records, name derivation from public keys, and optional PubSub notifications gated behind Gossipsub compliance.

---

## 1. Goal and Scope

### 1.1 Goal

Make dart_ipfs a full IPNS participant: derive names from Ed25519 public keys, publish signed CBOR records to the DHT via `DHTClient.storeValue`, resolve names via `DHTClient.getValue` with signature verification, and interop with Kubo and Helia. Remove the hardcoded fallback CID and the base64 PubSub broadcast hack.

### 1.2 Scope

- IPNS name derivation from Ed25519 public keys.
- CBOR record format with `Value`, `Validity`, `ValidityType`, `Sequence`, `TTL`, `PublicKey`, and `Signature`.
- Signable data construction per the IPNS Record spec.
- DHT publish and resolve algorithms.
- Optional Gossipsub-based PubSub notifications.
- Caching and validation.

### 1.3 Non-Goals

- IPNS over DNSLink is out of scope.
- IPNS over PubSub is the fallback/optional notification path only; DHT remains the primary source.
- Advanced key rotation is not required for v2.1.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| IPNS Record | https://specs.ipfs.tech/ipns/ipns-record/ | Record format, signing, name derivation, CBOR encoding |
| IPNS PubSub | https://specs.ipfs.tech/ipns/ipns-pubsub/ | Optional real-time notifications |
| libp2p Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Public key to peer ID mapping |
| libp2p Kademlia DHT | https://github.com/libp2p/specs/blob/master/kad-dht/README.md | PUT_VALUE / GET_VALUE for IPNS records |
| multiformats / CID | https://github.com/multiformats/cid | CID encoding in record value |
| CBOR | https://datatracker.ietf.org/doc/html/rfc8949 | Record serialization |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/ipns/ipns_handler.dart` — current resolution and publish logic.
- `lib/src/protocols/ipns/ipns_record.dart` — CBOR record model.
- `lib/src/protocols/dht/dht_client.dart` — DHT client used for publishing and resolving.
- `lib/src/core/config/ipfs_config.dart` — top-level IPFS configuration.

### 3.2 Gaps

- `IPNSHandler.resolve` returns a hardcoded fallback CID `QmResolvedCid` when DHT lookup fails.
- `_publishToDHT` is stubbed; it does not actually call `DHTClient.storeValue`.
- `publish()` broadcasts a base64-encoded CID via PubSub without a signed IPNS record.
- IPNS names are not derived from public keys; the handler treats arbitrary `keyName` strings as names.
- Signature verification is not required during resolve.
- `PeerId` (`lib/src/core/types/peer_id.dart`) is missing `fromPublicKey`, `toBase36()`, and `fromBase36()`; these primitives are required for IPNS name derivation.

---

## 4. Target State / Requirements

### 4.1 Name Derivation

IPNS name = base36-encoded `PeerId` from Ed25519 public key:

```dart
String deriveIpnsName(Uint8List publicKey) {
  final peerId = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
  return peerId.toBase36(); // e.g., k51qzi5uqu5...
}
```

**Prerequisite:** `PeerId` must implement `fromPublicKey(Uint8List publicKey, {required String type})`, `toBase36()`, and `fromBase36(String name)` before IPNS implementation begins.

### 4.2 Record Format

Reuse `IPNSRecord` (CBOR) with fields:

- `Value`: `/ipfs/<CID>` bytes
- `Validity`: ISO-8601 UTC bytes
- `ValidityType`: `0` (EOL)
- `Sequence`: int
- `TTL`: microseconds
- `PublicKey`: Ed25519 public key bytes
- `Signature`: Ed25519 signature bytes

Signable data per the IPNS Record spec:

```dart
Uint8List getSignableData() {
  final map = CborMap({
    'Value': value,
    'Validity': validityBytes,
    'ValidityType': 0,
    'Sequence': sequence,
    'TTL': ttl.inMicroseconds,
  });
  return Uint8List.fromList(
    utf8.encode('ipns-signature:') + cbor.encode(map),
  );
}
```

### 4.3 DHT Key

DHT key for an IPNS record:

```dart
Uint8List ipnsDHTKey(String name) {
  return Uint8List.fromList(utf8.encode('/ipns/$name'));
}
```

### 4.4 Resolve Algorithm

```dart
Future<IPNSRecord> resolve(String name) async {
  // 1. Validate name format.
  final peerId = PeerId.fromBase36(name);

  // 2. Check cache first.
  final cached = _cache.get(name);
  if (cached != null && !cached.isExpired && await cached.verify()) {
    return cached;
  }

  // 3. Query DHT for value at '/ipns/$name'.
  final bytes = await _dhtClient.getValue(utf8.encode('/ipns/$name'));
  if (bytes == null) throw IpnsResolutionError('No record found for $name');

  // 4. Decode and verify.
  final record = IPNSRecord.fromCBOR(bytes);
  if (!await record.verify()) throw IpnsValidationError('Invalid signature');
  if (record.isExpired) throw IpnsValidationError('Record expired');
  if (!_nameMatchesPublicKey(name, record.publicKey)) {
    throw IpnsValidationError('Name does not match public key');
  }

  // 5. Cache and return.
  _cache.put(name, record);
  return record;
}

### 4.5 Name/Public-Key Matching

```dart
bool nameMatchesPublicKey(String name, Uint8List publicKey) {
  final expected = PeerId.fromPublicKey(publicKey, type: 'Ed25519').toBase36();
  return name == expected;
}
```

### 4.6 Publish Algorithms

Keep the existing keystore-based API for backward compatibility and add the key-pair overload for advanced callers:

```dart
// v2.1 convenience API (loads key from SecurityManager)
Future<void> publish(String cid, {String? keyName}) async {
  final resolvedKeyName = keyName ?? 'self';
  final keyPair = await _securityManager.loadKey(resolvedKeyName);
  return publishWithKeyPair(CID.decode(cid), keyPair);
}

// Advanced API for callers that already have a key pair
Future<void> publishWithKeyPair(CID cid, SimpleKeyPair keyPair, {int? sequence}) async {
  final publicKey = await _extractPublicKey(keyPair);
  final name = deriveIpnsName(publicKey);

  final record = await IPNSRecord.create(
    value: cid,
    keyPair: keyPair,
    sequence: sequence ?? await _nextSequence(name),
    validity: const Duration(hours: 24),
    ttl: const Duration(hours: 1),
  );

  await _dhtClient.storeValue(
    Uint8List.fromList(utf8.encode('/ipns/$name')),
    record.toCBOR(),
  );

  // Optional PubSub notification after Gossipsub is landed.
  if (_gossipsub != null && _config.enableIpnsPubSub) {
    await _gossipsub.publish('/ipns/$name', record.toCBOR());
  }
}

Future<void> publishRecord(IPNSRecord record) async {
  await _dhtClient.storeValue(
    Uint8List.fromList(utf8.encode('/ipns/${record.name}')),
    record.toCBOR(),
  );
}
```

### 4.7 Configuration

```dart
class IPNSConfig {
  final bool enablePubSubNotifications; // default false until Gossipsub P0
  final Duration recordValidity;
  final Duration recordTtl;
  final int maxCacheSize;
  final bool requireSignatureVerification; // default true
}
```

### 4.8 APIs

```dart
class IPNSHandler {
  Future<void> start();
  Future<void> stop();
  Future<IPNSRecord> resolve(String name);
  Future<String> resolveAsString(String name);   // compatibility helper
  Future<void> publish(String cid, {String? keyName});               // existing API
  Future<void> publishWithKeyPair(CID cid, SimpleKeyPair keyPair, {int? sequence});
  Future<void> publishRecord(IPNSRecord record);
  Future<Map<String, dynamic>> getStatus();
}
```

---

## 5. Detailed Acceptance Criteria

- dart_ipfs publishes an IPNS record that Kubo can resolve (`ipfs name resolve /ipns/<name>`).
- dart_ipfs resolves a Kubo-published IPNS record and validates its Ed25519 signature.
- Unsigned, expired, or mismatched records are rejected with a clear validation error.
- The hardcoded fallback CID `QmResolvedCid` is removed from `resolve`.
- PubSub path is not used unless `enablePubSubNotifications` is true and `GossipsubHandler` is compliant.
- `publishRecord` can store a pre-constructed record for advanced callers.
- `PeerId` supports `fromPublicKey`, `toBase36()`, and `fromBase36()` before IPNS implementation begins.
- Existing `publish(String, {String? keyName})` callers continue to compile and work during v2.1.

---

## 6. Security Considerations

- IPNS records must verify the Ed25519 signature and name/public-key binding before caching or returning.
- Reject records with expired validity; do not cache them.
- Validate the CID in the record value is well-formed before returning it to callers.
- Do not publish records with a sequence number lower than the last published record for the same key to prevent replay attacks.
- Gate IPNS PubSub notifications behind user consent and Gossipsub compliance.
- Protect private keys used for signing; do not serialize them into logs or config files.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥85%)

- Name derivation from Ed25519 public keys and base36 encoding.
- `PeerId.fromBase36` / `PeerId.toBase36` round-trip.
- CBOR record encode/decode round-trip.
- Signable data construction and signature verification.
- Resolve flow with cache hit, DHT miss, expired record, invalid signature, and mismatched key.
- Publish flow sequence increment and DHT store call.
- `nameMatchesPublicKey` validation.
- Backward compatibility of the existing `publish(String, {String? keyName})` API.

### 7.2 Local Network Tests

- Run two dart_ipfs nodes locally; publish an IPNS record from one and resolve it from the other via the DHT.
- Verify cache behavior and TTL expiration.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command / Helia API | Expected Result |
|----------|--------------------------|-----------------|
| IPNS publish | dart_ipfs publishes; Kubo `ipfs name resolve /ipns/<name>` | Kubo resolves to the correct CID |
| IPNS resolve | Kubo publishes; dart_ipfs `resolve` | dart_ipfs resolves and validates signature |
| Record expiry | Publish with short validity; wait; resolve | Resolution fails with expired error |
| Invalid signature | Mutate signature bytes; resolve | Resolution fails with validation error |

### 7.4 CI Integration

- Run interop tests against Kubo and Helia nightly.
- Add coverage thresholds for `lib/src/protocols/ipns`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- `PeerId` must implement `fromPublicKey`, `toBase36()`, and `fromBase36()` (hard blocker; see acceptance criteria).
- `DHTClient.storeValue` and `DHTClient.getValue` must be implemented (DHT Integration feature).
- Ed25519 key support must be available in the crypto layer.
- `GossipsubHandler` must be compliant before PubSub notifications can be enabled.

### 8.2 Order Relative to Other Features

- **Before**: IPNS PubSub notifications (optional, requires Gossipsub).
- **Parallel with**: Gossipsub (only after DHT Integration is stable).
- **After**: DHT Integration and the missing `PeerId` base36 primitives.

### 8.3 External Dependencies

- CBOR encoding/decoding library (`package:cbor` or `package:cbor2`).
- Ed25519 signing from `package:cryptography` or `package:libp2p_crypto`.
- Base36 peer ID encoding in the multiformats stack.

---

## 9. Backward Compatibility Notes

- `IPNSHandler.publish(String cid, {String? keyName})` remains a convenience wrapper during v2.1; it is deprecated and will be removed in v2.3.
- `IPNSHandler.resolve(String name)` returns `IPNSRecord`; keep `resolveAsString(String name)` as a compatibility helper during v2.1.
- Existing IPNS cache format remains compatible; no migration needed.
- The removal of the hardcoded fallback CID may break tests that relied on `QmResolvedCid`; those tests must be updated to use real signed records.
- Custom JSON/HMAC PubSub broadcast for IPNS is removed; real-time notifications use Gossipsub only when enabled.
