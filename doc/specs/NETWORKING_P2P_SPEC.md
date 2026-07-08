# dart_ipfs v2.1 Networking, Naming & Full P2P Specification

**Document:** `NETWORKING_P2P_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\NETWORKING_P2P_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** Draft specification — implementation pending  
**Scope:** P2P transport layer, libp2p protocol compliance, DHT, IPNS, Gossipsub, Circuit Relay v2, browser transports, GraphSync, Bitswap fallbacks, and gateway TLS.

---

## 1. Overview / Goal

### 1.1 Purpose

This document defines the v2.1 backlog for dart_ipfs networking, naming, and full peer-to-peer interoperability. The goal is to transform the current partial/stub implementations into a spec-compliant, production-capable P2P node that can:

1. Join the public IPFS/libp2p DHT and discover/provide content.
2. Publish and resolve IPNS names using signed records over the DHT.
3. Exchange messages via standard libp2p Gossipsub (pubsub) wire format.
4. Dial and listen on modern transports: TCP, QUIC, WebRTC, WebTransport, and Circuit Relay v2.
5. Serve blocks efficiently via GraphSync (server-side MVP) and Bitswap with HTTP fallback.
6. Secure gateway traffic with optional TLS/AutoTLS.

### 1.2 Non-Goals

- **P2P datastore backends** (Badger/Pebble) are deferred to P2; this spec does not define them.
- **Bidirectional GraphSync pause/resume** and client-side response matching are deferred until the router supports unicast response streams.
- **Full WebRTC Maturity** is replaced by browser transport hardening (WebTransport + configurable STUN/TURN).

### 1.3 Success Criteria

- dart_ipfs can join the public Amino DHT, bootstrap against `bootstrap.libp2p.io`, and be discoverable by Kubo and Helia.
- IPNS names created by dart_ipfs resolve correctly in Kubo and Helia, and vice versa.
- Gossipsub messages are accepted by go-libp2p-pubsub and js-libp2p-pubsub.
- QUIC and WebTransport listen/dial addresses are advertised correctly.
- Circuit Relay v2 client can establish a relayed connection to a peer behind NAT.
- GatewayServer can terminate TLS/AutoTLS for public WSS/HTTPS gateway deployments.
- All new code maintains ≥80% line coverage per the project Iron Law of verification.

---

## 2. References

### 2.1 libp2p Specifications

| Spec | URL | Relevance |
|------|-----|-----------|
| libp2p Connection establishment | https://github.com/libp2p/specs/blob/master/connections/ | Noise, TLS, secio replacement |
| QUIC transport | https://github.com/libp2p/specs/blob/master/transports/quic.md | QUIC native transport |
| WebTransport transport | https://github.com/libp2p/specs/blob/master/webtransport/README.md | Browser transport hardening |
| Circuit Relay v2 | https://github.com/libp2p/specs/blob/master/relay/circuit-v2.md | Relay client dialing |
| Gossipsub v1.1 | https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md | Wire format and peer scoring |
| Kademlia DHT (Amino) | https://github.com/libp2p/specs/blob/master/kad-dht/README.md | FIND_NODE, GET_PROVIDERS, ADD_PROVIDER, PUT_VALUE/GET_VALUE |
| Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Identity and key derivation |
| multiformats / multiaddr | https://github.com/multiformats/multiaddr | Address parsing and composition |

### 2.2 IPFS Specifications

| Spec | URL | Relevance |
|------|-----|-----------|
| IPNS Record | https://specs.ipfs.tech/ipns/ipns-record/ | Ed25519 signing, CBOR encoding, name derivation |
| IPNS PubSub | https://specs.ipfs.tech/ipns/ipns-pubsub/ | Optional real-time notifications |
| Bitswap | https://specs.ipfs.tech/bitswap-protocol/ | Block exchange |
| GraphSync | https://specs.ipfs.tech/graphsync/ | DAG exchange with selectors |
| HTTP Gateway | https://specs.ipfs.tech/http-gateways/ | Trustless gateway and TLS termination |

### 2.3 Multiaddr Protocols Used

- `/ip4/<addr>/tcp/<port>` — TCP baseline
- `/ip4/<addr>/udp/<port>/quic-v1` — QUIC (RFC 9000)
- `/ip4/<addr>/udp/<port>/quic-v1/webtransport` — WebTransport
- `/ip4/<addr>/tcp/<port>/ws` / `/wss` — WebSocket
- `/p2p/<peerId>` — peer identity
- `/p2p-circuit/p2p/<peerId>` — Circuit Relay v2
- `/webrtc` / `/webrtc-direct` — WebRTC variants

### 2.4 Internal References

- `lib/src/transport/libp2p_router.dart`
- `lib/src/protocols/dht/dht_client.dart`
- `lib/src/protocols/ipns/ipns_handler.dart`
- `lib/src/protocols/ipns/ipns_record.dart`
- `lib/src/protocols/graphsync/graphsync_handler.dart`
- `lib/src/protocols/bitswap/bitswap_handler.dart`
- `lib/src/core/config/network_config.dart`
- `lib/src/core/config/gateway_config.dart`
- `lib/src/core/config/dht_config.dart`
- `lib/src/core/config/ipfs_config.dart`

---

## 3. Current-State Gaps in dart_ipfs

### 3.1 Transport Layer

- `Libp2pRouter` only configures `TCPTransport` from `package:ipfs_libp2p`; QUIC transport is not instantiated even though `NetworkConfig.defaultListenAddresses` includes `/udp/4002/quic-v1/webtransport`.
- WebTransport dialer/listener exist but IO listener and certhash validation are incomplete; WebTransport `Conn` metadata throws `UnimplementedError`.
- WebRTC hardcodes Google STUN (`stun:stun.l.google.com:19302`) with no TURN fallback.

### 3.2 Gossipsub

- No dedicated Gossipsub implementation exists; `pubsub_client.dart` uses a custom JSON/HMAC wire format that is incompatible with libp2p Gossipsub.
- No peer scoring, no message history cache, no message signing with peer keys.

### 3.3 DHT

- `DHTClient.findProviders` and `findPeer` only query the closest peers in the local routing table once; there is no iterative Kademlia query expansion.
- `DHTClient` sends raw multiaddr strings as UTF-8 bytes instead of proper multiaddr byte encoding.
- Request/response correlation is missing; the client does not match outbound requests to inbound responses.
- Provider records are not validated (signature, expiration, address sanity).
- Reprovide sweep is not implemented.
- `ADD_PROVIDER` only sends to the closest peers without XOR ordering or batching.

### 3.4 IPNS

- `IPNSHandler.resolve` returns a hardcoded fallback CID `QmResolvedCid` when DHT lookup fails.
- `_publishToDHT` is stubbed; it does not actually call `DHTClient.storeValue`.
- `publish()` broadcasts a base64-encoded CID via PubSub without a signed IPNS record.
- IPNS names are not derived from public keys; the handler treats arbitrary `keyName` strings as names.
- Signature verification is not required during resolve.

### 3.5 Circuit Relay v2

- `CircuitRelayClient` exists but the relayed client dialing path is incomplete after reservation.

### 3.6 GraphSync

- `GraphsyncHandler._handleNewRequest` broadcasts responses to all connected peers instead of unicasting to the requester.
- Responses contain only progress/completion metadata; `GraphsyncMessage.blocks` is never populated.
- `requestGraph()` falls back to Bitswap for the root block.
- No selector depth or block-count budgets.

### 3.7 Bitswap

- `BitswapHandler` does not have an HTTP fallback; it only retries P2P.
- HTTP-fetched blocks are never verified against the requested CID.

### 3.8 Gateway

- `GatewayConfig` has no TLS fields.
- `GatewayServer` does not support `SecurityContext` or ACME/AutoTLS.

---

## 4. Detailed Per-Item Specification

### 4.1 P0 APPROVED — QUIC Transport

#### 4.1.1 Goal

Add a native QUIC transport plugged into `Libp2pRouter`, advertise `/udp/.../quic-v1` listen addresses, and keep TCP as the fallback transport.

#### 4.1.2 Protocol ID

- Transport multiaddr: `/quic-v1`
- libp2p security handshake: Noise over QUIC (or TLS 1.3 as per libp2p QUIC spec)

#### 4.1.3 Configuration

Extend `NetworkConfig`:

```dart
NetworkConfig({
  ...
  this.enableQuic = true,          // default true
  this.quicListenPort = 4002,    // default
  this.quicMaxStreams = 100,
  this.preferQuic = true,         // dial QUIC before TCP if both advertised
});
```

YAML/JSON keys:

```yaml
network:
  enableQuic: true
  quicListenPort: 4002
  preferQuic: true
```

#### 4.1.4 Implementation

1. Add a `QuicTransport` wrapper around `package:ipfs_libp2p` QUIC transport if available, or a custom Dart QUIC binding (select the most mature available dependency).
2. In `Libp2pRouter.start()`, conditionally add `Libp2p.transport(QuicTransport(...))` when `enableQuic` is true.
3. Build listen addresses from `NetworkConfig.listenAddresses` and synthesize `/ip4/0.0.0.0/udp/$quicListenPort/quic-v1` and `/ip6/::/udp/$quicListenPort/quic-v1` if not already present.
4. If `package:ipfs_libp2p` does not expose QUIC, fall back to TCP-only and log a warning.

#### 4.1.5 State Machine

- `Libp2pRouter.start()`:
  1. Initialize identity.
  2. Collect TCP + QUIC + WebTransport + WebRTC transports based on config flags.
  3. Add listen addrs.
  4. Call `host.start()`.
  5. Emit `listeningAddresses` including QUIC addresses.

#### 4.1.6 APIs

```dart
abstract class RouterInterface {
  ...
  List<String> get listeningAddresses;
  bool get supportsQuic;
  Future<bool> connect(String multiaddr); // must understand /quic-v1
}
```

#### 4.1.7 Acceptance Criteria

- `Libp2pRouter.listeningAddresses` contains at least one `/quic-v1` address when enabled.
- A dart_ipfs node can be dialed by Kubo over QUIC.
- TCP fallback remains operational when QUIC fails or is disabled.

---

### 4.2 P0 APPROVED — Full libp2p Gossipsub Compliance

#### 4.2.1 Goal

Replace the custom JSON/HMAC PubSub wire format with spec-compliant Gossipsub v1.1 protobuf messages, peer-key message signing, message-history cache, and peer scoring.

#### 4.2.2 Protocol IDs

- Protocol ID: `/meshsub/1.1.0` (Gossipsub v1.1)
- Optional compatibility: `/meshsub/1.0.0`

#### 4.2.3 Message Formats

Use the canonical Gossipsub protobuf:

```protobuf
message RPC {
  repeated Subscription subscriptions = 1;
  repeated Message publish = 2;
  optional ControlMessage control = 3;
  repeated string subscriptions_ = 1 [deprecated];
}

message Subscription {
  optional bool subscribe = 1;
  optional string topicid = 2;
}

message Message {
  optional bytes from = 1;
  optional bytes data = 2;
  optional bytes seqno = 3;
  optional string topic = 4;
  optional bytes signature = 5;
  optional bytes key = 6;
}

message ControlMessage {
  repeated ControlIHave ihave = 1;
  repeated ControlIWant iwant = 2;
  repeated ControlGraft graft = 3;
  repeated ControlPrune prune = 4;
}
```

Implement peer-key signing per [Gossipsub spec §2.4](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md#message-signing):

- `from` = sender `PeerId` bytes.
- `signature` = Ed25519 signature over the protobuf prefix plus `data`, `seqno`, `topic`.
- `key` = sender public key (may be omitted if `from` can be decoded to key).
- `seqno` = 8-byte big-endian monotonic counter.

#### 4.2.4 Message-History Cache

```dart
class MessageCache {
  /// Maximum messages per topic retained.
  final int capacityPerTopic;

  /// Store seen (msgId -> Message) per topic.
  void add(String topic, String msgId, Message msg);

  /// Get messages for a list of IHAVE message IDs.
  List<Message> getForIWant(String topic, List<String> ids);

  /// Generate message ID: SHA-256 of (from || seqno || topic || data).
  String messageId(Message msg);
}
```

#### 4.2.5 Peer Scoring

Implement per-topic scoring per Gossipsub v1.1:

| Parameter | Default | Description |
|-----------|---------|-------------|
 `topicScoreCap` | 100.0 | max score from a topic |
 `timeInMeshQuantum` | 1h | mesh presence bonus |
 `firstMessageDeliveries` | 5.0 | bonus for first deliveries |
 `meshMessageDeliveries` | threshold | expected deliveries per window |
 `meshFailurePenalty` | -1.0 | penalty for under-delivery |
 `invalidMessageDeliveries` | -10.0 | penalty for invalid messages |
 `decayInterval` | 1 minute |

Keep a `PeerScore` table keyed by `PeerId`.

#### 4.2.6 State Machine

```
[Stopped] -> start() -> [Initializing]
[Initializing] -> router.registerProtocol('/meshsub/1.1.0') -> [Subscribing]
[Subscribing] -> subscribe(topic) -> [Gossip]
[Gossip] -> receive PRUNE -> update mesh -> [Mesh]
[Mesh] -> receive GRAFT -> validate score -> add/remove peer
```

#### 4.2.7 Configuration

```dart
class PubSubConfig {
  final String protocolId;       // '/meshsub/1.1.0'
  final int historyLength;       // 5
  final int gossipFactor;        // 3
  final int d;                   // 6 (topic mesh degree)
  final int dLow;                // 4
  final int dHigh;               // 12
  final int heartbeatIntervalMs; // 1000
  final bool signMessages;       // true
  final bool strictSign;         // true
  final int maxMessageSize;      // 1 MiB
  final Map<String, TopicScoreParams> topicScoreParams;
}
```

#### 4.2.8 APIs

```dart
class GossipsubHandler {
  Future<void> start();
  Future<void> stop();
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
  Future<void> publish(String topic, Uint8List data);
  Stream<GossipsubMessage> onMessage(String topic);
  Future<PeerScore> getPeerScore(String peerId);
}
```

#### 4.2.9 Acceptance Criteria

- dart_ipfs can subscribe/publish to a topic with Kubo and receive signed messages.
- Invalid signatures are rejected and score penalized.
- Duplicate messages are suppressed using message cache.
- Gossipsub IHAVE/IWANT/GRAFT/PRUNE control messages are sent and parsed correctly.

---

### 4.3 P0 MODIFIED — Real Amino DHT Network Integration

#### 4.3.1 Goal

Finish iterative `FIND_NODE` / `GET_PROVIDERS`, add provider-record validation, implement reprovide sweep, fix request/response correlation in `DHTClient` so the node can join the public DHT.

#### 4.3.2 Protocol ID

- `/ipfs/kad/1.0.0`

#### 4.3.3 Message Format

Continue using `lib/src/proto/dht/kademlia.proto` `Message` with fields:

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

#### 4.3.4 Request/Response Correlation

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

#### 4.3.5 Iterative Query Algorithm

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

#### 4.3.6 Provider Record Validation

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

#### 4.3.7 Reprovide Sweep

```dart
class ReproviderService {
  Future<void> start();
  Future<void> stop();

  /// Re-announce all pinned roots and MFS roots every `reprovideInterval`.
  Future<void> sweep();
}
```

Config additions in `DHTConfig`:

```dart
final Duration reprovideInterval;
final int maxProvidersPerKey;
final bool validateProviderRecords;
```

#### 4.3.8 APIs

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

#### 4.3.9 Acceptance Criteria

- dart_ipfs can query `GET_PROVIDERS` iteratively and find providers for a CID published by Kubo.
- `ADD_PROVIDER` uses XOR-ordered closest peers and batching.
- Invalid provider records are dropped.
- Reprovide sweep runs periodically and logs success/failure.

---

### 4.4 P0 MODIFIED — IPNS DHT-First Signed Records

#### 4.4.1 Goal

Use the existing `IPNSRecord` Ed25519 signing + `DHTClient.storeValue/getValue`, derive names from public keys, require signature verification on resolve. PubSub notifications are gated behind Gossipsub compliance.

#### 4.4.2 Name Derivation

IPNS name = base36-encoded `PeerId` from Ed25519 public key:

```dart
String deriveIpnsName(Uint8List publicKey) {
  final peerId = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
  return peerId.toBase36(); // e.g., k51qzi5uqu5...
}
```

#### 4.4.3 Record Format

Reuse `IPNSRecord` (CBOR) with fields:

- `Value`: `/ipfs/<CID>` bytes
- `Validity`: ISO-8601 UTC bytes
- `ValidityType`: `0` (EOL)
- `Sequence`: int
- `TTL`: microseconds
- `PublicKey`: Ed25519 public key bytes
- `Signature`: Ed25519 signature bytes

Signable data per [IPNS Record spec](https://specs.ipfs.tech/ipns/ipns-record/):

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

#### 4.4.4 DHT Key

DHT key for IPNS record:

```dart
Uint8List ipnsDHTKey(String name) {
  return Uint8List.fromList(utf8.encode('/ipns/$name'));
}
```

#### 4.4.5 Resolve Algorithm

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
```

#### 4.4.6 Publish Algorithm

```dart
Future<void> publish(CID cid, SimpleKeyPair keyPair, {int? sequence}) async {
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
```

#### 4.4.7 Configuration

```dart
class IPNSConfig {
  final bool enablePubSubNotifications; // default false until Gossipsub P0
  final Duration recordValidity;
  final Duration recordTtl;
  final int maxCacheSize;
  final bool requireSignatureVerification; // default true
}
```

#### 4.4.8 APIs

```dart
class IPNSHandler {
  Future<void> start();
  Future<void> stop();
  Future<IPNSRecord> resolve(String name);
  Future<void> publish(CID cid, SimpleKeyPair keyPair, {int? sequence});
  Future<void> publishRecord(IPNSRecord record);
  Future<Map<String, dynamic>> getStatus();
}
```

#### 4.4.9 Acceptance Criteria

- dart_ipfs publishes an IPNS record that Kubo can resolve (`ipfs name resolve /ipns/<name>`).
- dart_ipfs resolves a Kubo-published IPNS record and validates its signature.
- Unsigned, expired, or mismatched records are rejected.
- PubSub path is not used unless `enablePubSubNotifications` is true and Gossipsub is compliant.

---

### 4.5 P0 APPROVED — Circuit Relay v2 Client Dialing

#### 4.5.1 Goal

Complete relayed client dialing path via `/p2p-circuit` multiaddr semantics after reservation.

#### 4.5.2 Protocol ID

- Reservation protocol: `/libp2p/circuit/relay/0.2.0/hop`
- Relayed transport: `/p2p-circuit`

#### 4.5.3 Multiaddr Semantics

- Relay listen: `/ip4/.../tcp/.../p2p/<relay-peer-id>/p2p-circuit/p2p/<target-peer-id>`
- Relay reservation: `/ip4/.../tcp/.../p2p/<relay-peer-id>/p2p-circuit`

#### 4.5.4 State Machine

```
[Idle] -> discover relay -> [RelayDiscovered]
[RelayDiscovered] -> reserve slot -> [Reserved]
[Reserved] -> dial target via circuit -> [Connected]
[Connected] -> disconnect -> [Reserved]
```

#### 4.5.5 Reservation Flow

```protobuf
// HopMessage
message HopMessage {
  enum Type { RESERVE = 1; CONNECT = 2; STATUS = 3; }
  optional Type type = 1;
  optional Peer peer = 2;
  optional Reservation reservation = 3;
  optional Status status = 4;
}

message Reservation {
  optional uint64 expire = 1; // Unix seconds
  repeated bytes addrs = 2;
}
```

#### 4.5.6 Implementation

1. Extend `CircuitRelayClient` to send a `RESERVE` hop message to the relay.
2. Parse `Reservation` response; store `expire` and relay addresses.
3. On `connect(targetPeerId)`, send a `CONNECT` hop message with the target peer.
4. Wait for `SUCCESS` status; then upgrade the stream to a `Conn` object usable by the router.
5. Expose the relayed connection through `RouterInterface` so Bitswap/DHT/IPNS can use it transparently.

#### 4.5.7 Configuration

```dart
class CircuitRelayConfig {
  final bool enabled;
  final List<String> staticRelays;
  final Duration reservationTimeout;
  final Duration reservationRefreshInterval;
  final int maxCircuits;
}
```

#### 4.5.8 APIs

```dart
class CircuitRelayClient {
  Future<void> start();
  Future<void> stop();
  Future<RelayReservation> reserve(String relayAddr);
  Future<Connection> connectThroughRelay(String relayAddr, String targetPeerId);
  List<String> get activeRelayAddrs;
}
```

#### 4.5.9 Acceptance Criteria

- dart_ipfs can reserve a slot on a Kubo relay v2.
- dart_ipfs can dial a peer behind NAT via the relay.
- The relayed connection appears in `RouterInterface.connectedPeers`.

---

### 4.6 P1 MODIFIED — Browser Transport Hardening

#### 4.6.1 Goal

Implement WebTransport IO listener/dialer, validate certhash in web dialer, replace hardcoded Google STUN with configurable STUN/TURN, implement missing `Conn` metadata without `UnimplementedError`.

#### 4.6.2 WebTransport

##### Protocol IDs

- `/webtransport`
- `/quic-v1/webtransport`

##### Certhash Validation

When dialing a multiaddr containing `/certhash/<multibase>`:

```dart
bool validateCerthash(WebTransportConnection conn, List<String> expectedCerthashes) {
  final serverCertificateHashes = conn.serverCertificateHashes;
  for (final hash in expectedCerthashes) {
    final decoded = Multibase.decode(hash);
    if (serverCertificateHashes.any((h) => _listEquals(h, decoded))) return true;
  }
  return false;
}
```

If certhash validation fails, close the connection and log a security error.

##### IO Listener

Implement `WebTransportListener` for non-web platforms:

```dart
class WebTransportListener {
  Future<void> listen(String multiaddr);
  Future<void> close();
  Stream<WebTransportConnection> get onConnection;
}
```

The IO listener should bind to a local UDP socket and accept QUIC WebTransport sessions. If platform APIs are unavailable, stub cleanly and return a `NotSupportedException` rather than `UnimplementedError`.

##### Conn Metadata

```dart
class WebTransportConn implements Conn {
  @override
  String get remoteAddr => _connection.remoteAddress;
  @override
  String get localAddr => _connection.localAddress;
  @override
  Future<void> close();
  @override
  Stream<Uint8List> get readable;
  @override
  Future<void> write(Uint8List data);
  @override
  Map<String, dynamic> get metadata => {
    'transport': 'webtransport',
    'security': 'quic',
    'remotePeer': remotePeerId,
  };
}
```

#### 4.6.3 WebRTC

##### Configurable STUN/TURN

Replace `stun:stun.l.google.com:19302` with `NetworkConfig` fields:

```dart
class NetworkConfig {
  ...
  final List<String> stunServers;   // default empty
  final List<TurnServer> turnServers; // default empty
}

class TurnServer {
  final String url;
  final String username;
  final String credential;
}
```

Default STUN should be empty or configurable; do not hardcode Google STUN in production code.

##### Connection Metadata

Implement all `RTCPeerConnection` metadata fields:

```dart
class WebRTCConn implements Conn {
  String get remoteAddr;
  String get localAddr;
  String get transport => 'webrtc';
  Map<String, dynamic> get metadata => {
    'iceState': _pc.iceConnectionState,
    'signalingState': _pc.signalingState,
    'localDescription': _pc.localDescription?.toMap(),
    'remoteDescription': _pc.remoteDescription?.toMap(),
  };
}
```

#### 4.6.4 Acceptance Criteria

- WebTransport dialer validates certhash and fails closed on mismatch.
- WebTransport IO listener can accept a connection on a non-web platform.
- No `UnimplementedError` is thrown from `Conn` metadata.
- WebRTC uses configurable STUN/TURN; no hardcoded Google STUN remains.

---

### 4.7 P1 MODIFIED — Server-Side GraphSync MVP

#### 4.7.1 Goal

Respond to a single requesting peer with selected blocks in `GraphsyncMessage.blocks`, enforce selector depth/block-count budgets, fall back to Bitswap for missing blocks. Defer bidirectional pause/resume and client-side matching until the router supports unicast response streams.

#### 4.7.2 Protocol ID

- `/ipfs/graphsync/1.0.0`
- `/ipfs/graphsync/2.0.0` (optional, depends on selector support)

#### 4.7.3 Message Format

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

#### 4.7.4 Request Handling

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
        blocks.add(Block(prefix: cid.toBytes(), data: data));
      },
      onMissing: (cid) async {
        // Fall back to Bitswap for missing blocks.
        final block = await _bitswap.getBlock(cid);
        if (block != null) {
          blocks.add(Block(prefix: cid.toBytes(), data: block.data));
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

#### 4.7.5 Budgets

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

  void leaveDepth() => _currentDepth--;
}
```

Default budgets:

- `maxDepth`: 32
- `maxBlocks`: 1024
- `maxBytes`: 16 MiB

#### 4.7.6 Unicast Response Requirement

`GraphsyncHandler` must send responses only to the requesting peer. If `RouterInterface` does not support unicast, add a helper:

```dart
Future<void> _sendResponseToPeer(String peer, GraphsyncMessage response) async {
  if (_router.supportsUnicast) {
    await _router.sendMessage(peer, response.writeToBuffer(), protocolId: protocolId);
  } else {
    // Defer: broadcast fallback is prohibited; log and drop.
    _logger.warning('Cannot unicast GraphSync response; deferring until router supports unicast.');
  }
}
```

#### 4.7.7 Configuration

```dart
class GraphsyncConfig {
  final bool enabled;
  final int defaultMaxDepth;
  final int defaultMaxBlocks;
  final int defaultMaxBytes;
  final bool fallBackToBitswap;
}
```

#### 4.7.8 Acceptance Criteria

- Server-side GraphSync responds to a single requester with blocks.
- Selector depth and block-count budgets are enforced.
- Missing blocks fall back to Bitswap.
- No broadcast of GraphSync responses.

---

### 4.8 P1 MODIFIED — Bitswap HTTP Fallback

#### 4.8.1 Goal

Integrate `HttpGatewayClient` as fallback inside `BitswapHandler` after P2P attempts fail; verify every HTTP-fetched block against the requested CID.

#### 4.8.2 Protocol ID

- `/ipfs/bitswap/1.2.0` (P2P)
- HTTP trustless gateway endpoints: `/ipfs/<cid>?format=raw` (raw block), `/ipfs/<cid>?format=car` (CAR)

#### 4.8.3 Fallback Flow

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

#### 4.8.4 CID Verification

```dart
bool _verifyBlock(Block block, String expectedCidStr) {
  final expectedCid = CID.decode(expectedCidStr);
  final actualHash = _hash(expectedCid.codec, block.data);
  return _listEquals(actualHash, expectedCid.multihash.digest);
}
```

If the codec is raw (`0x55`), verify the hash directly. If the codec is DAG-PB/DAG-CBOR/etc., verify the serialized block hash matches the CID multihash.

#### 4.8.5 Configuration

```dart
class BitswapConfig {
  ...
  final List<String> httpFallbackGateways; // e.g., ['https://gateway.ipfs.io']
  final Duration p2pTimeout;
  final Duration httpTimeout;
  final bool verifyHttpBlocks;
}
```

#### 4.8.6 APIs

```dart
class BitswapHandler {
  ...
  Future<Block?> getBlock(String cidStr, {bool useHttpFallback = true});
}
```

#### 4.8.7 Acceptance Criteria

- P2P Bitswap is attempted first.
- HTTP fallback is used only after P2P timeout/failure.
- Every HTTP block is verified against the CID; mismatched blocks are discarded.
- Verified HTTP blocks are stored in the local blockstore.

---

### 4.9 P2 DEFERRED — Badger / Pebble Datastore Backends

Deferred. No specification in v2.1. Revisit when storage layer is refactored.

---

### 4.10 P1 APPROVED — AutoTLS / TLS for WSS Gateway

#### 4.10.1 Goal

Optional TLS termination in `GatewayServer` using `SecurityContext` from config; off-by-default AutoTLS/ACME mode for public gateways.

#### 4.10.2 Configuration

Extend `GatewayConfig`:

```dart
class GatewayConfig {
  ...
  final bool enableTls;
  final String? certificatePath;
  final String? privateKeyPath;
  final String? certificatePassword;
  final bool autoTls;
  final String? autoTlsDomain;
  final String? autoTlsEmail;
  final String? autoTlsProvider; // 'letsencrypt', 'zerossl'
  final bool autoTlsAcceptTos;   // default false
  final List<String> autoTlsSANs;
  final int tlsPort;              // default 443
  final bool redirectHttpToHttps; // default false
}
```

YAML/JSON:

```yaml
gateway:
  enabled: true
  port: 8080
  enableTls: true
  certificatePath: /etc/dart_ipfs/cert.pem
  privateKeyPath: /etc/dart_ipfs/key.pem
  # OR
  autoTls: true
  autoTlsDomain: gateway.example.com
  autoTlsEmail: admin@example.com
  autoTlsAcceptTos: true
```

#### 4.10.3 Implementation

1. On `GatewayServer.start()`, if `enableTls` is true and certificate paths are provided, load them into a `SecurityContext`.
2. If `autoTls` is true, use an ACME client (e.g., `acme_client` package or LEgo-style wrapper) to obtain/renew a certificate for `autoTlsDomain`.
3. Bind the TLS server to `tlsPort` (default 443).
4. Optionally start an HTTP redirect server on `port` that redirects to `https://<autoTlsDomain>:<tlsPort>`.
5. If neither TLS nor AutoTLS is enabled, bind plain HTTP as today.

#### 4.10.4 ACME State Machine

```
[Idle] -> autoTls requested -> [Acquiring]
[Acquiring] -> challenge accepted -> [Validating]
[Validating] -> certificate issued -> [Active]
[Active] -> renewal due -> [Renewing]
```

#### 4.10.5 APIs

```dart
class GatewayServer {
  Future<void> start();
  Future<void> stop();
  Future<bool> isTlsActive();
  Future<DateTime?> certificateExpiry();
}
```

#### 4.10.6 Acceptance Criteria

- `GatewayServer` serves HTTPS when `enableTls` is true with valid cert/key.
- AutoTLS obtains a certificate when `autoTlsAcceptTos` is true.
- AutoTLS is off by default.
- WSS (WebSocket Secure) gateway works when TLS is enabled.

---

## 5. Implementation Sequence

### Phase 1 — P0 Foundations

1. **QUIC Transport** (4.1)
   - Add `QuicTransport` and wire into `Libp2pRouter`.
   - Add config fields.
   - Test against TCP fallback.

2. **DHT Request/Response Correlation & Iterative Queries** (4.3)
   - Add `DHTEnvelope` and request map.
   - Implement iterative `FIND_NODE` and `GET_PROVIDERS`.
   - Fix multiaddr byte encoding.

3. **IPNS DHT-First Signed Records** (4.4)
   - Derive names from public keys.
   - Implement `publish` via `DHTClient.storeValue`.
   - Implement `resolve` with `DHTClient.getValue` and signature verification.
   - Remove hardcoded fallback CID.

4. **Gossipsub Compliance** (4.2)
   - Add Gossipsub protobuf.
   - Implement signing, message cache, peer scoring.
   - Wire as optional PubSub backend for IPNS notifications.

5. **Circuit Relay v2 Client** (4.5)
   - Complete reservation and relayed dialing.
   - Test NAT traversal with Kubo.

### Phase 2 — P1 Hardening & Efficiency

6. **Browser Transport Hardening** (4.6)
   - WebTransport IO listener/dialer.
   - Certhash validation.
   - Configurable STUN/TURN.

7. **GraphSync Server MVP** (4.7)
   - Unicast blocks to requester.
   - Enforce budgets.
   - Bitswap fallback.

8. **Bitswap HTTP Fallback** (4.8)
   - Integrate `HttpGatewayClient`.
   - CID verification.

9. **AutoTLS / TLS Gateway** (4.10)
   - `SecurityContext` loading.
   - ACME client integration.

### Phase 3 — P2 Deferred

10. **Badger / Pebble Datastore Backends** (4.9)
    - Revisit after Phase 2 stability.

---

## 6. Testing Strategy

### 6.1 Unit Tests

| Component | Test Focus | Target Coverage |
|-----------|------------|-----------------|
| QUIC Transport | address parsing, transport selection, fallback | ≥80% |
| Gossipsub | message signing, cache, scoring, control messages | ≥85% |
| DHT Client | XOR ordering, iterative query, correlation, provider validation | ≥85% |
| IPNS | record signing, name derivation, DHT publish/resolve, verification | ≥85% |
| Circuit Relay | reservation parsing, connect flow, timeout | ≥80% |
| WebTransport | certhash validation, IO listener stub, conn metadata | ≥80% |
| GraphSync | selector traversal, budget enforcement, block population | ≥80% |
| Bitswap HTTP Fallback | fallback ordering, CID verification, caching | ≥80% |
| Gateway TLS | cert loading, AutoTLS state machine | ≥80% |

### 6.2 Local DHT Network Tests

- Spin up 3–5 dart_ipfs nodes on localhost.
- Bootstrap from a local bootstrapper.
- Publish a CID and verify another node finds providers.
- Test iterative query convergence with `k=20`.
- Test provider record validation rejects malformed records.

### 6.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command / Helia API | Expected Result |
|----------|--------------------------|-----------------|
| DHT provide/find | `ipfs dht provide <cid>` then dart_ipfs `findProviders` | dart_ipfs finds Kubo |
| IPNS publish | dart_ipfs publishes, Kubo `ipfs name resolve /ipns/<name>` | Kubo resolves |
| IPNS resolve | Kubo publishes, dart_ipfs resolves | dart_ipfs resolves and validates |
| Gossipsub | Kubo `ipfs pubsub pub topic data` | dart_ipfs receives |
| Bitswap | Kubo pins a CID, dart_ipfs fetches via Bitswap | block verified |
| GraphSync | dart_ipfs serves a DAG, Kubo/Helia client requests | blocks received |
| Circuit Relay | Kubo as relay, dart_ipfs behind NAT dials another peer | connection succeeds |
| Gateway TLS | `curl -k https://localhost:443/ipfs/<cid>` | HTTPS response |

### 6.4 CI Integration

- Add a new GitHub Actions workflow `interop.yml` that starts Kubo and Helia Docker containers.
- Run interop tests nightly and on PRs touching `lib/src/transport`, `lib/src/protocols/dht`, `lib/src/protocols/ipns`, `lib/src/protocols/pubsub`, `lib/src/protocols/graphsync`, `lib/src/protocols/bitswap`, `lib/src/services/gateway`.
- Enforce coverage thresholds with `coverage` package.

---

## 7. Security Considerations

### 7.1 DHT Attacks

- **Sybil/eclipse**: Maintain Kademlia k-buckets with XOR distance. Limit incoming peers per bucket. Validate provider records.
- **Record poisoning**: Validate IPNS signatures and DHT record expiration. Reject records with mismatched public keys.
- **Amplification**: Rate-limit `ADD_PROVIDER` and `GET_PROVIDERS` per peer. Limit concurrent iterative queries.

### 7.2 Relay Abuse

- Limit the number of active circuits per relay.
- Enforce reservation expiry and refresh.
- Do not relay traffic to private/reserved IP ranges unless explicitly allowed.

### 7.3 Signature Verification

- Gossipsub messages must be signed with the sender's peer key; strict signing mode on by default.
- IPNS records must verify Ed25519 signature and name/public-key binding before caching or returning.
- Bitswap HTTP blocks must verify CID multihash before storage.

### 7.4 TLS

- Load certificates from secure filesystem paths; do not log private keys.
- AutoTLS must require explicit ToS acceptance.
- Use TLS 1.2+; disable weak ciphers.
- Redirect HTTP to HTTPS only when `redirectHttpToHttps` is enabled.

### 7.5 Transport Security

- QUIC uses TLS 1.3 or Noise.
- WebTransport validates server certhash to prevent MITM.
- WebRTC uses configurable TURN with credentials; avoid hardcoded public STUN in production.

### 7.6 Privacy

- Do not leak local IP addresses in relay reservations unless intended.
- Gate IPNS PubSub notifications behind user consent and Gossipsub compliance.

---

## 8. Backward Compatibility / Migration Notes

### 8.1 Configuration Migration

- New `NetworkConfig` fields (`enableQuic`, `preferQuic`, `stunServers`, `turnServers`) have sensible defaults; existing configs continue to work.
- New `GatewayConfig` TLS fields default to off; existing gateways remain plain HTTP.
- New `IPNSConfig` requires signature verification by default; existing tests that relied on unsigned/hardcoded records must be updated.

### 8.2 API Migration

- `IPNSHandler.publish(String cid, {String? keyName})` will be deprecated in favor of `publish(CID cid, SimpleKeyPair keyPair, {int? sequence})`.
- `IPNSHandler.resolve(String name)` will return `IPNSRecord` instead of `String CID` in a future version; during v2.1 keep a `resolveAsString` helper for compatibility.
- `PubSubClient` custom JSON/HMAC format will be replaced by `GossipsubHandler`. Keep the old class as a deprecated shim until v2.2.
- `DHTClient` will add the new `storeValue` / `getValue` / `reprovide` methods; existing `findProviders` / `findPeer` / `addProvider` signatures remain but behavior becomes iterative.

### 8.3 Wire Format Migration

- Gossipsub wire format change is breaking; the old JSON/HMAC PubSub protocol will be removed. Nodes must upgrade to communicate via the new handler.
- DHT multiaddr byte encoding fix is wire-compatible with Kubo but may break existing dart_ipfs-only deployments that decoded the old string format.

### 8.4 Database / State Migration

- IPNS cache format remains compatible; no migration needed.
- DHT routing table format remains compatible; no migration needed.
- Gateway TLS certificates are managed externally or by ACME; no datastore migration.

### 8.5 Deprecation Timeline

| Feature | Deprecation | Removal |
|---------|-------------|---------|
| Custom JSON/HMAC PubSub | v2.1 | v2.2 |
| `IPNSHandler.publish(String, {String? keyName})` | v2.1 | v2.3 |
| `IPNSHandler.resolve(String) -> String` | v2.1 | v2.3 |
| Hardcoded Google STUN | v2.1 | v2.2 |
| GraphSync broadcast responses | v2.1 | v2.1 (removed immediately) |

---

## 9. Appendix: Glossary

- **Amino DHT**: libp2p Kademlia DHT used by IPFS.
- **Gossipsub**: libp2p topic-based pubsub with gossip and mesh overlays.
- **IPNS**: InterPlanetary Name System; mutable pointers to CIDs.
- **GraphSync**: Protocol for exchanging IPLD DAGs using selectors.
- **Circuit Relay v2**: Protocol for relaying connections through an intermediate peer.
- **WebTransport**: Web API providing QUIC-like client-server transport.
- **AutoTLS**: Automatic TLS certificate provisioning via ACME.

---

## 10. Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-25 | v2.1 | Initial specification from Ciel Council of Five verdicts |

---

*End of Specification*
