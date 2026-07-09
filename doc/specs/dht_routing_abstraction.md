# DHT Routing Table Abstraction

## Overview

This document describes the DHT routing table abstraction that enables true Kademlia distance-based peer selection in the dart_ipfs implementation.

## Motivation

Prior to this abstraction, the DHT protocol handler (`dht_protocol_handler.dart`) had a limitation in its `_findClosestPeers` method. It simply returned connected peers without using true Kademlia XOR distance-based selection:

```dart
// Old implementation (simplified)
Future<List<kad.Peer>> _findClosestPeers(List<int> key, {int numPeers = 20}) async {
  final connectedPeers = _router.connectedPeers.take(numPeers);
  return connectedPeers.map((peerId) => kad.Peer()..id = utf8.encode(peerId)).toList();
}
```

This was a simplification because the routing table was P2plibRouter-specific and not exposed via the RouterInterface.

## Solution

The solution introduces a layered abstraction:

1. **Distance Metric Interface** (`DistanceMetric`) - Pluggable distance calculation
2. **DHT Routing Table Interface** (`DHTRoutingTable`) - Abstract routing operations
3. **XOR Distance Implementation** (`XorDistanceMetric`) - Kademlia standard metric
4. **Routing Adapter** (`KademliaRoutingAdapter`) - Bridges existing implementation
5. **Router Interface Extension** - Exposes routing table to protocol handlers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DHTProtocolHandler                        │
│                  (uses DHTRoutingTable)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    RouterInterface                           │
│              (dhtRoutingTable getter)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Libp2pRouter                               │
│           (setDHTRoutingTable / dhtRoutingTable)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               KademliaRoutingAdapter                          │
│              (implements DHTRoutingTable)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              KademliaRoutingTable                            │
│           (existing implementation)                          │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Distance Metric Interface

**File:** `lib/src/protocols/dht/dht_routing_table_interface.dart`

```dart
abstract class DistanceMetric {
  /// Calculates the distance between two peer IDs.
  int calculateDistance(PeerId a, PeerId b);

  /// Calculates the distance between a peer ID and a raw key.
  int calculateDistanceToKey(PeerId peerId, List<int> key);
}
```

This interface allows different distance metrics to be plugged in (e.g., XOR for Kademlia, other metrics for alternative DHT implementations).

### 2. DHT Routing Table Interface

**File:** `lib/src/protocols/dht/dht_routing_table_interface.dart`

```dart
abstract class DHTRoutingTable {
  /// The distance metric used by this routing table.
  DistanceMetric get distanceMetric;

  /// Finds the K closest peers to the given target peer ID.
  List<PeerId> findClosestPeers(PeerId target, {int k = 20});

  /// Finds the K closest peers to the given DHT key.
  List<PeerId> findClosestPeersToKey(List<int> key, {int k = 20});

  /// Adds a peer to the routing table.
  Future<void> addPeer(PeerId peerId, PeerId associatedPeerId, {String? address});

  /// Removes a peer from the routing table.
  void removePeer(PeerId peerId);

  /// Checks if a peer is in the routing table.
  bool containsPeer(PeerId peerId);

  /// Returns the total number of peers in the routing table.
  int get peerCount;

  /// Clears all peers from the routing table.
  void clear();
}
```

This interface provides a clean abstraction for routing table operations, decoupling protocol handlers from specific implementations.

### 3. XOR Distance Metric Implementation

**File:** `lib/src/protocols/dht/xor_distance_metric.dart`

Implements the standard Kademlia XOR distance metric:

```dart
class XorDistanceMetric implements DistanceMetric {
  const XorDistanceMetric();

  @override
  int calculateDistance(PeerId a, PeerId b) {
    return _xorBytes(a.value, b.value);
  }

  @override
  int calculateDistanceToKey(PeerId peerId, List<int> key) {
    return _xorBytes(peerId.value, key);
  }

  int _xorBytes(List<int> a, List<int> b) {
    // XOR byte by byte and convert to integer
  }
}
```

**Properties:**
- Symmetric: `distance(a, b) == distance(b, a)`
- Non-negative: `distance(a, b) >= 0`
- Identity: `distance(a, a) == 0`
- Triangle inequality: approximately holds for practical purposes

### 4. Kademlia Routing Adapter

**File:** `lib/src/protocols/dht/kademlia_routing_adapter.dart`

Bridges the existing `KademliaRoutingTable` implementation with the new `DHTRoutingTable` interface:

```dart
class KademliaRoutingAdapter implements DHTRoutingTable {
  KademliaRoutingAdapter(this._routingTable)
      : _distanceMetric = const XorDistanceMetric();

  final KademliaRoutingTable _routingTable;
  final XorDistanceMetric _distanceMetric;

  @override
  DistanceMetric get distanceMetric => _distanceMetric;

  @override
  List<PeerId> findClosestPeers(PeerId target, {int k = 20}) {
    return _routingTable.findClosestPeers(target, k);
  }

  @override
  List<PeerId> findClosestPeersToKey(List<int> key, {int k = 20}) {
    final targetPeerId = PeerId(value: Uint8List.fromList(key));
    return _routingTable.findClosestPeers(targetPeerId, k);
  }

  // ... other methods delegate to _routingTable
}
```

### 5. Router Interface Extension

**File:** `lib/src/transport/router_interface.dart`

Added a new property to expose the DHT routing table:

```dart
abstract class RouterInterface {
  // ... existing methods

  /// Returns the DHT routing table for distance-based peer selection.
  ///
  /// This provides access to the Kademlia routing table for DHT protocol handlers
  /// to perform true distance-based peer selection. Returns null if the router
  /// does not support DHT routing operations.
  DHTRoutingTable? get dhtRoutingTable;
}
```

### 6. Libp2pRouter Implementation

**File:** `lib/src/transport/libp2p_router.dart`

Added support for setting and exposing the DHT routing table:

```dart
class Libp2pRouter implements RouterInterface {
  DHTRoutingTable? _dhtRoutingTable;

  @override
  DHTRoutingTable? get dhtRoutingTable => _dhtRoutingTable;

  /// Sets the DHT routing table for distance-based peer selection.
  void setDHTRoutingTable(DHTRoutingTable routingTable) {
    _dhtRoutingTable = routingTable;
    _logger.debug('DHT routing table set on router');
  }
}
```

### 7. DHT Client Integration

**File:** `lib/src/protocols/dht/dht_client.dart`

The DHT client now exposes the routing table via the router interface:

```dart
class DHTClient {
  Future<void> initialize() async {
    // ... existing initialization

    _kademliaRoutingTable = KademliaRoutingTable();
    _kademliaRoutingTable.initialize(this);

    // Expose the routing table via the router interface
    final routingAdapter = KademliaRoutingAdapter(_kademliaRoutingTable);
    if (_router is Libp2pRouter) {
      (_router as Libp2pRouter).setDHTRoutingTable(routingAdapter);
    }

    // ... rest of initialization
  }
}
```

### 8. Protocol Handler Migration

**File:** `lib/src/protocols/dht/dht_protocol_handler.dart`

The `_findClosestPeers` method now uses the routing table abstraction:

```dart
Future<List<kad.Peer>> _findClosestPeers(
  List<int> key, {
  int numPeers = 20,
}) async {
  // Try to use the DHT routing table for true distance-based selection
  final routingTable = _router.dhtRoutingTable;
  if (routingTable != null) {
    try {
      final closestPeerIds = routingTable.findClosestPeersToKey(key, k: numPeers);
      return closestPeerIds
          .map((peerId) => kad.Peer()..id = peerId.value)
          .toList();
    } catch (e) {
      _logger.warning('Failed to use DHT routing table, falling back to connected peers: $e');
    }
  }

  // Fallback: Get connected peers from router interface
  final connectedPeers = _router.connectedPeers.take(numPeers);
  return connectedPeers
      .map((peerId) => kad.Peer()..id = utf8.encode(peerId))
      .toList();
}
```

## Benefits

1. **True Kademlia Distance-Based Selection**: Peers are now selected based on XOR distance to the target key, improving DHT efficiency.

2. **Decoupling**: Protocol handlers are decoupled from specific routing table implementations.

3. **Testability**: The abstraction makes it easier to test routing logic with mock implementations.

4. **Extensibility**: Alternative distance metrics or routing table implementations can be plugged in without modifying protocol handlers.

5. **Backward Compatibility**: The fallback to connected peers ensures the system continues to work even if the routing table is unavailable.

## Testing

### XOR Distance Metric Tests

**File:** `test/protocols/dht/xor_distance_metric_test.dart`

Comprehensive tests for the XOR distance metric:
- Distance to self is zero
- Distance is symmetric
- Distance is non-negative
- Correct XOR calculation for simple and multi-byte values
- Handles different length peer IDs
- Handles empty peer IDs
- Triangle inequality holds approximately
- Distance ordering correctness

All tests pass: **15/15**

### DHT Routing Integration Tests

**File:** `test/protocols/dht/dht_routing_integration_test.dart`

Integration tests for distance-based peer selection:
- Selects closest peers by XOR distance
- Handles K closest peers selection
- Distance metric consistency
- Deterministic peer selection
- Edge case handling (identical peer IDs)

All tests pass: **5/5**

## Performance Impact

The performance impact is minimal:

1. **Distance Calculation**: XOR distance calculation is O(n) where n is the number of bytes in the peer ID (typically 32 bytes for SHA-256). This is very fast.

2. **Peer Selection**: The routing table already maintains peers sorted by distance, so finding the K closest peers is O(K) after the initial sort.

3. **Abstraction Overhead**: The adapter pattern adds a single method call overhead, which is negligible compared to network operations.

4. **Fallback Path**: The fallback to connected peers ensures no performance degradation if the routing table is unavailable.

## Future Enhancements

1. **Alternative Distance Metrics**: Implement other distance metrics (e.g., geographic distance, latency-based) for specialized use cases.

2. **Routing Table Metrics**: Add metrics to track routing table performance (hit rate, lookup latency, etc.).

3. **Caching**: Add caching for frequently accessed peer lists to reduce distance calculations.

4. **Adaptive K**: Dynamically adjust the K parameter based on network conditions.

## References

- [Kademlia DHT Specification](https://github.com/libp2p/specs/tree/master/kad-dht)
- [IPFS DHT Implementation](https://github.com/ipfs/kad-dht)
