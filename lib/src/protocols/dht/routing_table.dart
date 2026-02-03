import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/remove_peer.dart';

/// Kademlia-based routing table for DHT peer management.
///
/// Wraps a KademliaTree for efficient peer lookup and management.
class RoutingTable {
  /// Creates a routing table for [_localPeerId].
  RoutingTable(this._localPeerId, DHTClient dhtClient) {
    _dhtClient = dhtClient;
    _kademliaTree = KademliaTree(
      _dhtClient,
      root: KademliaTreeNode(
        _localPeerId,
        0,
        _localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
  final PeerId _localPeerId;
  late final KademliaTree _kademliaTree;

  /// Standard k-bucket size.
  static const int K = 20;

  late final DHTClient _dhtClient;

  /// Returns the nearest peers to a key.
  List<PeerId> getNearestPeers(List<int> key, [int count = K]) {
    final targetPeerId = PeerId(value: Uint8List.fromList(key));
    return _kademliaTree.findClosestPeers(targetPeerId, count);
  }

  /// Adds a peer to the routing table.
  void addPeer(PeerId peerId, PeerId associatedPeerId) {
    _kademliaTree.addPeer(peerId, associatedPeerId);
  }

  /// Removes a peer from the routing table.
  void removePeer(PeerId peerId) {
    _kademliaTree.removePeer(peerId);
  }
}

