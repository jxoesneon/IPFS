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
import '/../src/proto/dht/kademlia_tree.pb.dart' as kademlia_tree_pb;
import '/../src/proto/dht/kademlia_node.pb.dart' as kademlia_node_pb;


/// Represents a Kademlia tree for efficient peer routing and lookup.
class KademliaTree {
  // Tree structure
  KademliaNode? _root; // Root node of the tree
  List<RedBlackTree<p2p.PeerId, KademliaNode>> _buckets =
      []; // List of k-buckets (now RedBlackTrees)
  Map<p2p.PeerId, DateTime> _lastSeen = {}; // Add _lastSeen map
  // Public getter for _lastSeen
  Map<p2p.PeerId, DateTime> get lastSeen => _lastSeen;
  Set<p2p.PeerId> _recentContacts = {}; // Store as member variable
  // Public getter for _recentContacts (optional, for access from outside)
  Set<p2p.PeerId> get recentContacts => _recentContacts;
  // Method to clear recent contacts
  void clearRecentContacts() {
    _recentContacts = {}; // Re-initialize to an empty set
  }

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
  // TODO: Implement `getAssociatedPeer` to retrieve the associated peer for a given ID.
  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) => 
      this.getAssociatedPeer(peerId); 
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) =>
      this.findClosestPeers(target, k);
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
  List<Future<List<p2p.PeerId>>> queries = [];
  for (var node in closestNodes) {
    queries.add(_queryNode(node, target)); // Assume _queryNode is a helper function
  }
  List<List<p2p.PeerId>> results = await Future.wait(queries);

    
    while (!converged && iterationCount < maxIterations) {
      // Select α closest nodes not yet queried
      List<p2p.PeerId> nodesToQuery = _selectClosestNodes(closestNodes, alpha);

      // Send parallel queries and await responses
      List<List<p2p.PeerId>> results = await Future.wait(
          nodesToQuery.map((node) => _queryNode(node, target)));

      // Process responses and update closestNodes
      _updateClosestNodes(closestNodes, results);

      // Check for convergence
      converged = _checkConvergence(closestNodes);

      iterationCount++;
    }
    
    return this.nodeLookup(target);
  }
  void refresh() => this.refresh();

  // Bucket management operations (using extensions)
  void splitBucket(int bucketIndex) => this.splitBucket(bucketIndex);
  void mergeBuckets(int bucketIndex1, int bucketIndex2) =>
      this.mergeBuckets(bucketIndex1, bucketIndex2);
}
