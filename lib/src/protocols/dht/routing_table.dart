import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/remove_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'kademlia_tree.dart';

/// Kademlia-based routing table for DHT peer management.
///
/// Wraps a KademliaTree for efficient peer lookup and management.
class RoutingTable {
  final p2p.PeerId _localPeerId;
  late final KademliaTree _kademliaTree;

  /// Standard k-bucket size.
  static const int K = 20;

  late final DHTClient _dhtClient;

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

  List<p2p.PeerId> getNearestPeers(List<int> key, [int count = K]) {
    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key));
    return _kademliaTree.findClosestPeers(targetPeerId, count);
  }

  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    _kademliaTree.addPeer(peerId, associatedPeerId);
  }

  void removePeer(p2p.PeerId peerId) {
    _kademliaTree.removePeer(peerId);
  }
}
