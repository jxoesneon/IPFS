import '../../core/types/peer_id.dart';

/// Interface for calculating distance between peers in the DHT.
///
/// Different distance metrics can be implemented (e.g., XOR distance for Kademlia).
abstract class DistanceMetric {
  /// Calculates the distance between two peer IDs.
  ///
  /// Returns a numeric distance value where lower values indicate closer peers.
  int calculateDistance(PeerId a, PeerId b);

  /// Calculates the distance between a peer ID and a raw key.
  ///
  /// Used when finding peers closest to a DHT key.
  int calculateDistanceToKey(PeerId peerId, List<int> key);
}

/// Interface for DHT routing table operations.
///
/// Provides methods for peer management and distance-based peer selection.
/// This abstraction allows different routing table implementations to be used
/// while maintaining a consistent API for DHT protocol handlers.
abstract class DHTRoutingTable {
  /// The distance metric used by this routing table.
  DistanceMetric get distanceMetric;

  /// Finds the K closest peers to the given target peer ID.
  ///
  /// [target] - The peer ID to find closest peers to.
  /// [k] - The number of closest peers to return (default: 20).
  ///
  /// Returns a list of peer IDs sorted by distance (closest first).
  List<PeerId> findClosestPeers(PeerId target, {int k = 20});

  /// Finds the K closest peers to the given DHT key.
  ///
  /// [key] - The DHT key (raw bytes) to find closest peers to.
  /// [k] - The number of closest peers to return (default: 20).
  ///
  /// Returns a list of peer IDs sorted by distance (closest first).
  List<PeerId> findClosestPeersToKey(List<int> key, {int k = 20});

  /// Adds a peer to the routing table.
  ///
  /// [peerId] - The peer ID to add.
  /// [associatedPeerId] - The associated peer ID (often same as peerId).
  /// [address] - Optional network address for diversity checks.
  Future<void> addPeer(
    PeerId peerId,
    PeerId associatedPeerId, {
    String? address,
  });

  /// Removes a peer from the routing table.
  ///
  /// [peerId] - The peer ID to remove.
  void removePeer(PeerId peerId);

  /// Checks if a peer is in the routing table.
  ///
  /// [peerId] - The peer ID to check.
  bool containsPeer(PeerId peerId);

  /// Returns the total number of peers in the routing table.
  int get peerCount;

  /// Clears all peers from the routing table.
  void clear();
}
