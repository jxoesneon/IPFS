import 'dart:typed_data';

import '../../core/types/peer_id.dart';

import 'dht_routing_table_interface.dart';
import 'kademlia_routing_table.dart';
import 'xor_distance_metric.dart';

/// Adapter that wraps [KademliaRoutingTable] to implement [DHTRoutingTable].
///
/// This bridges the existing KademliaRoutingTable implementation with the new
/// DHTRoutingTable interface, allowing the DHT protocol handler to use the
/// routing table through the abstraction.
class KademliaRoutingAdapter implements DHTRoutingTable {
  /// Creates an adapter wrapping the given [routingTable].
  ///
  /// [routingTable] - The underlying KademliaRoutingTable to adapt.
  KademliaRoutingAdapter(this._routingTable)
      : _distanceMetric = const XorDistanceMetric();

  /// The underlying Kademlia routing table.
  final KademliaRoutingTable _routingTable;

  /// The XOR distance metric used for peer selection.
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

  @override
  Future<void> addPeer(
    PeerId peerId,
    PeerId associatedPeerId, {
    String? address,
  }) {
    return _routingTable.addPeer(peerId, associatedPeerId, address: address);
  }

  @override
  void removePeer(PeerId peerId) {
    _routingTable.removePeer(peerId);
  }

  @override
  bool containsPeer(PeerId peerId) {
    return _routingTable.containsPeer(peerId);
  }

  @override
  int get peerCount => _routingTable.peerCount;

  @override
  void clear() {
    _routingTable.clear();
  }
}
