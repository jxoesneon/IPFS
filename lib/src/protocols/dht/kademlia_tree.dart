// lib/src/protocols/dht/kademlia_tree.dart
import 'package:p2plib/p2plib.dart' as p2p;

import 'kademlia_tree/add_peer.dart';
import 'kademlia_tree/bucket_management.dart';
import 'kademlia_tree/find_closest_peers.dart';
import 'kademlia_tree/helpers.dart';
import 'kademlia_tree/kademlia_node.dart';
import 'kademlia_tree/node_lookup.dart';
import 'kademlia_tree/refresh.dart';
import 'kademlia_tree/remove_peer.dart';
import 'red_black_tree.dart';


/// Represents a Kademlia tree for efficient peer routing and lookup.
class KademliaTree {
  // Tree structure
  KademliaNode? _root; // Root node of the tree
  List<RedBlackTree<p2p.PeerId, KademliaNode>> _buckets =
      []; // List of k-buckets (now RedBlackTrees)

  // Define kBucketSize (usually 20)
  static const int kBucketSize = 20;

  KademliaNode? get root => _root;
  List<RedBlackTree<p2p.PeerId, KademliaNode>> get buckets => _buckets;

  // Constructor
  KademliaTree(p2p.PeerId localPeerId) {
    _root = KademliaNode(localPeerId, 0, localPeerId);
    // Pre-allocate buckets (e.g., for 256-bit Peer IDs, you might have 256 buckets)
    for (int i = 0; i < 256; i++) {
      _buckets.add(RedBlackTree<p2p.PeerId, KademliaNode>(
          compare: (p2p.PeerId a, p2p.PeerId b) =>
              a.toString().compareTo(b.toString())));
    }
  }

  // Core Kademlia operations (using extensions)
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) =>
      this.addPeer(peerId, associatedPeerId);
  void removePeer(p2p.PeerId peerId) => this.removePeer(peerId);
  //p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) =>
  //    this.getAssociatedPeer(peerId); // TODO: Implement this if needed
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) =>
      this.findClosestPeers(target, k);
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) =>
      this.nodeLookup(target);
  void refresh() => this.refresh();

  // Bucket management operations (using extensions)
  void splitBucket(int bucketIndex) => this.splitBucket(bucketIndex);
  void mergeBuckets(int bucketIndex1, int bucketIndex2) =>
      this.mergeBuckets(bucketIndex1, bucketIndex2);
}
