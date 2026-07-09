# Gossipsub Compliance Specification for dart_ipfs

**Document:** `GOSSIPSUB_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\GOSSIPSUB_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Maintainer review (2026-06-25)  
**Status:** P0 Approved — implementation pending  
**Scope:** Full libp2p Gossipsub v1.1 compliance, replacing the existing custom JSON/HMAC PubSub implementation.

---

## 1. Goal and Scope

### 1.1 Goal

Replace the custom JSON/HMAC PubSub wire format in dart_ipfs with spec-compliant Gossipsub v1.1 protobuf messages, peer-key message signing, message-history cache, and peer scoring. The result must be wire-interoperable with `go-libp2p-pubsub` and `js-libp2p-pubsub`.

### 1.2 Scope

- Gossipsub v1.1 protocol registration and message handling.
- Canonical protobuf wire format with all control messages.
- Message signing using the node's peer key.
- Message-history cache and duplicate suppression.
- Peer scoring per topic and per peer.
- Subscription, publish, unsubscribe, and message stream APIs.

### 1.3 Non-Goals

- Gossipsub v1.0-only networks are optional backward compatibility.
- Advanced peer-score parameter tuning beyond the defaults is left to configuration files.
- Message encryption at the pubsub layer is not required; payload security is the application's responsibility.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| Gossipsub v1.1 | https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md | Wire format, mesh, gossip, peer scoring, message signing |
| Gossipsub v1.0 | https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.0.md | Optional backward compatibility |
| libp2p Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Key types used for signing |
| libp2p Connection establishment | https://github.com/libp2p/specs/blob/master/connections/ | Securing underlying streams |
| Protocol Buffers | https://protobuf.dev/ | Wire encoding |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/pubsub/pubsub_client.dart` — custom JSON/HMAC wire format incompatible with libp2p Gossipsub.
- `lib/src/transport/libp2p_router.dart` — generic protocol registration surface, no Gossipsub handler registered.

### 3.2 Gaps

- No dedicated Gossipsub implementation exists.
- No peer scoring, message history cache, or message signing with peer keys.
- The existing PubSub cannot exchange messages with Kubo or Helia.
- IPNS real-time notifications cannot be implemented on a standards-compliant substrate.

---

## 4. Target State / Requirements

### 4.1 Protocol IDs

- Primary: `/meshsub/1.1.0` (Gossipsub v1.1)
- Optional compatibility: `/meshsub/1.0.0`

### 4.2 Message Formats

Use the canonical Gossipsub protobuf `RPC` envelope:

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

Implement peer-key signing per Gossipsub spec §2.4:

- `from` = sender `PeerId` bytes.
- `signature` = Ed25519 signature over the protobuf prefix plus `data`, `seqno`, `topic`.
- `key` = sender public key (may be omitted if `from` can be decoded to key).
- `seqno` = 8-byte big-endian monotonic counter.

### 4.3 Message-History Cache

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

### 4.4 Peer Scoring

Implement per-topic scoring per Gossipsub v1.1:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `topicScoreCap` | 100.0 | max score from a topic |
| `timeInMeshQuantum` | 1h | mesh presence bonus |
| `firstMessageDeliveries` | 5.0 | bonus for first deliveries |
| `meshMessageDeliveries` | threshold | expected deliveries per window |
| `meshFailurePenalty` | -1.0 | penalty for under-delivery |
| `invalidMessageDeliveries` | -10.0 | penalty for invalid messages |
| `decayInterval` | 1 minute | score decay cadence |

Keep a `PeerScore` table keyed by `PeerId`.

### 4.5 State Machine

```
[Stopped]
  -> start()
    -> [Initializing]
      -> router.registerProtocol('/meshsub/1.1.0')
        -> [Subscribing]
          -> subscribe(topic)
            -> [Gossip]
              -> receive PRUNE
                -> update mesh
                  -> [Mesh]
                    -> receive GRAFT
                      -> validate score
                        -> add/remove peer
```

### 4.6 Configuration

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

### 4.7 APIs

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

---

## 5. Detailed Acceptance Criteria

- dart_ipfs can subscribe to a topic and receive signed messages published by Kubo (`ipfs pubsub pub topic data`).
- dart_ipfs can publish a message to a topic that Kubo and Helia receive.
- Invalid signatures are rejected and the sender's peer score is penalized.
- Duplicate messages are suppressed using the message cache.
- Gossipsub `IHAVE`/`IWANT`/`GRAFT`/`PRUNE` control messages are sent and parsed correctly.
- The mesh degree stays between `dLow` and `dHigh` for active topics.
- `maxMessageSize` is enforced; oversized messages are rejected.

---

## 6. Security Considerations

- Strict signing must be enabled by default. Messages without valid signatures are dropped and the sender penalized.
- Message IDs must be collision-resistant (SHA-256 of `from || seqno || topic || data`).
- Peer scoring must decay scores for bad behavior and cap positive contributions to prevent score inflation.
- Do not forward messages that fail validation; forwarding invalid data amplifies attacks.
- Limit the number of topics a peer can subscribe to in order to mitigate mesh exhaustion.
- Validate topic strings for length and UTF-8 well-formedness before propagating subscriptions.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥85%)

- Protobuf encode/decode round-trip for `RPC`, `Message`, `ControlMessage`.
- Message signing and verification with Ed25519 peer keys.
- Message cache hit/miss, eviction, and `getForIWant` correctness.
- Peer scoring decay, penalties, and cap enforcement.
- Mesh maintenance (`GRAFT`/`PRUNE`) with synthetic peers.

### 7.2 Local Network Tests

- Spin up 5 dart_ipfs nodes on localhost, form a mesh, and verify that a single published message reaches all subscribers.
- Introduce a malicious node that sends invalid signatures and verify it is penalized and dropped.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command / Helia API | Expected Result |
|----------|--------------------------|-----------------|
| Publish to Kubo | dart_ipfs publishes; Kubo `ipfs pubsub sub topic` | Kubo receives the message |
| Receive from Kubo | Kubo `ipfs pubsub pub topic data` | dart_ipfs receives and validates |
| Helia interop | Helia publishes on a topic | dart_ipfs receives and validates |
| Invalid signature | Custom node sends unsigned message | dart_ipfs drops and penalizes |

### 7.4 CI Integration

- Add `interop.yml` step that starts Kubo and Helia pubsub endpoints and runs the above matrix.
- Enforce coverage thresholds with the `coverage` package.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- Peer key management must support Ed25519 signing.
- `RouterInterface` must support registering handlers by protocol ID and opening protocol streams to peers.

### 8.2 Order Relative to Other Features

- **Before**: IPNS PubSub notifications (optional real-time IPNS path requires Gossipsub).
- **Parallel with**: QUIC, DHT, IPNS DHT-first records.
- **After**: Basic libp2p routing and identity.

### 8.3 External Dependencies

- `package:protobuf` or `protoc` generated Dart messages for the Gossipsub wire format.
- Ed25519 signing from `package:libp2p_crypto` or `package:cryptography`.

---

## 9. Backward Compatibility Notes

- The existing `PubSubClient` custom JSON/HMAC wire format is deprecated in v2.1 and will be removed in v2.2.
- Keep `PubSubClient` as a thin shim that delegates to `GossipsubHandler` for one release cycle, logging deprecation warnings.
- Gossipsub v1.1 is wire-incompatible with the old format; dart_ipfs nodes must upgrade to communicate via the new handler.
- Existing IPNS publish code that broadcasts base64-encoded CIDs must be rerouted to `GossipsubHandler` only when `enablePubSubNotifications` is enabled.
