# Circuit Relay v2 Client Dialing Specification for dart_ipfs

**Document:** `CIRCUIT_RELAY_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\CIRCUIT_RELAY_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Maintainer review (2026-06-25)  
**Status:** P0 Approved — implementation pending  
**Scope:** Client-side Circuit Relay v2 support, including reservation, relayed dialing, and transparent integration into the router's peer connection set.

---

## 1. Goal and Scope

### 1.1 Goal

Complete the relayed client dialing path in `CircuitRelayClient` so a dart_ipfs node behind NAT can reach another peer through a public relay. The relayed connection must be usable transparently by Bitswap, DHT, IPNS, and Gossipsub.

### 1.2 Scope

- Relay discovery via static configuration and limited discovery.
- Reservation protocol flow (`RESERVE`).
- Relayed connect flow (`CONNECT`).
- Multiaddr parsing and construction for `/p2p-circuit` addresses.
- Transparent routing of relayed connections through `RouterInterface`.
- Reservation refresh and expiry handling.

### 1.3 Non-Goals

- Acting as a relay server (hop) is not required for v2.1; only the client side is in scope.
- Autorelay (automatic relay discovery and selection) is deferred to a later release.
- Relayed listener (relay reservation for inbound connections) is limited to static relays.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| Circuit Relay v2 | https://github.com/libp2p/specs/blob/master/relay/circuit-v2.md | Reservation and connect message flow, status codes, multiaddr semantics |
| libp2p Connection establishment | https://github.com/libp2p/specs/blob/master/connections/ | Security handshake over relayed streams |
| libp2p Peer ID | https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md | Peer identity in relay messages |
| multiformats / multiaddr | https://github.com/multiformats/multiaddr | `/p2p-circuit` address composition |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/protocols/relay/circuit_relay_client.dart` — existing relay client with incomplete dialing path.
- `lib/src/transport/libp2p_router.dart` — transport/router layer that must expose relayed connections.
- `lib/src/core/config/network_config.dart` — network configuration where relay settings live.

### 3.2 Gaps

- `CircuitRelayClient` exists but the relayed client dialing path is incomplete after reservation.
- The reservation flow does not fully parse the `Reservation` response or refresh before expiry.
- Relayed connections are not exposed through `RouterInterface.connectedPeers`.
- There is no configuration class for static relays, timeouts, or max circuits.

---

## 4. Target State / Requirements

### 4.1 Protocol IDs

- Reservation protocol: `/libp2p/circuit/relay/0.2.0/hop`
- Relayed transport: `/p2p-circuit`

### 4.2 Multiaddr Semantics

- Relay listen address: `/ip4/.../tcp/.../p2p/<relay-peer-id>/p2p-circuit/p2p/<target-peer-id>`
- Relay reservation address: `/ip4/.../tcp/.../p2p/<relay-peer-id>/p2p-circuit`

### 4.3 State Machine

```
[Idle]
  -> discover relay
    -> [RelayDiscovered]
      -> reserve slot
        -> [Reserved]
          -> dial target via circuit
            -> [Connected]
              -> disconnect
                -> [Reserved]
```

### 4.4 Reservation Flow

Use the `HopMessage` protobuf:

```protobuf
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

### 4.5 Implementation Requirements

1. Extend `CircuitRelayClient` to send a `RESERVE` hop message to the relay.
2. Parse the `Reservation` response; store `expire` and relay addresses.
3. On `connect(targetPeerId)`, send a `CONNECT` hop message with the target peer.
4. Wait for `SUCCESS` status; then upgrade the stream to a `Conn` object usable by the router.
5. Expose the relayed connection through `RouterInterface` so Bitswap/DHT/IPNS can use it transparently.
6. Refresh reservations before expiry based on `reservationRefreshInterval`.

### 4.6 Configuration

```dart
class CircuitRelayConfig {
  final bool enabled;
  final List<String> staticRelays;
  final Duration reservationTimeout;
  final Duration reservationRefreshInterval;
  final int maxCircuits;
}
```

### 4.7 APIs

```dart
class CircuitRelayClient {
  Future<void> start();
  Future<void> stop();
  Future<RelayReservation> reserve(String relayAddr);
  Future<Connection> connectThroughRelay(String relayAddr, String targetPeerId);
  List<String> get activeRelayAddrs;
}
```

---

## 5. Detailed Acceptance Criteria

- dart_ipfs can reserve a slot on a Kubo relay v2 (`/libp2p/circuit/relay/0.2.0/hop`).
- dart_ipfs can dial a peer behind NAT via the relay and the resulting connection appears in `RouterInterface.connectedPeers`.
- The relayed connection can carry Bitswap, DHT, and IPNS traffic transparently.
- Reservations are refreshed before expiry.
- Failed reservations return clear errors and do not leave dangling connections.
- `maxCircuits` is enforced; additional attempts are rejected or queued.

---

## 6. Security Considerations

- Limit the number of active circuits per relay to mitigate relay abuse.
- Enforce reservation expiry and refresh; do not use expired reservations.
- Do not relay traffic to private/reserved IP ranges unless explicitly allowed by configuration.
- Validate the relay's `PeerId` matches the multiaddr before trusting the reservation.
- Use the standard libp2p security handshake (Noise/TLS) inside the relayed stream; do not treat the relay as a trusted intermediary.
- Log relay connection events but do not log relay credentials or target peer payload.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- `HopMessage` encode/decode for `RESERVE`, `CONNECT`, and status responses.
- Reservation parsing and expiry calculation.
- Multiaddr construction for relay and relayed target addresses.
- `connectThroughRelay` state transitions and timeout handling.
- Max circuits enforcement.

### 7.2 Local Network Tests

- Run a local Kubo relay and two dart_ipfs nodes on separate localhost ports.
- Place one dart_ipfs node behind a simulated NAT (no direct dial addresses) and verify it can reach the other via the relay.
- Test reservation refresh by keeping the connection alive longer than the reservation TTL.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo Command | Expected Result |
|----------|--------------|-----------------|
| Reserve | dart_ipfs reserves on Kubo relay | Kubo accepts reservation |
| Relayed dial | dart_ipfs behind NAT dials another peer via Kubo relay | Connection succeeds and traffic flows |
| Peer list | `ipfs swarm peers` on Kubo | Relayed dart_ipfs peer appears |
| Bitswap over relay | Kubo pins a CID; dart_ipfs fetches via relayed connection | Block retrieved |

### 7.4 CI Integration

- Add a Kubo relay container to the interop workflow.
- Run relay matrix on PRs touching `lib/src/protocols/relay` or `lib/src/transport`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- `RouterInterface` must be able to register a relayed `Conn` as a normal peer connection with a protocol muxer.
- The security handshake must work over relayed streams.

### 8.2 Order Relative to Other Features

- **Before**: GraphSync server unicast (relayed connections may be used by requesters), DHT queries over relay.
- **Parallel with**: QUIC, DHT, Gossipsub, IPNS.
- **After**: Basic TCP and identity.

### 8.3 External Dependencies

- Circuit Relay v2 protobuf definitions (existing or generated).
- `package:ipfs_libp2p` or equivalent for stream upgrade and security handshake.

---

## 9. Backward Compatibility Notes

- `CircuitRelayConfig` is a new configuration class with all fields optional; existing configs are unaffected.
- Relayed connections are additive; they do not replace direct TCP/QUIC connections.
- The existing `CircuitRelayClient` class may need API changes (`reserve`/`connectThroughRelay` return typed objects); keep backward-compatible overloads if possible during v2.1.
- No wire-format breaking changes for compliant v2 relays; the v2 protocol is unchanged.
