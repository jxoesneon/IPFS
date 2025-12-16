// lib/src/protocols/dht/red_black_tree.dart

import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    as common_tree;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/insertion.dart'
    as insertion;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/deletion.dart'
    as deletion;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/search.dart'
    as rb_search;

/// A node in the Red-Black tree.
class RedBlackTreeNode<K_PeerId, V_PeerInfo> {
  /// The key (peer ID).
  K_PeerId key;

  /// The value (peer info).
  V_PeerInfo value;

  /// Node color (RED or BLACK).
  common_tree.NodeColor color;

  /// Left child.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? leftChild;

  /// Right child.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? rightChild;

  /// Parent node.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? parent;

  /// Creates a tree node.
  RedBlackTreeNode(
    this.key,
    this.value, {
    this.color = common_tree.NodeColor.RED,
    this.leftChild,
    this.rightChild,
    this.parent,
  });
}

/// Self-balancing Red-Black tree for efficient peer lookup.
///
/// Used in Kademlia k-buckets for O(log n) peer operations.
class RedBlackTree<K_PeerId, V_PeerInfo> {
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? _root;
  int Function(K_PeerId, K_PeerId) _compare;

  final insertion.Insertion<K_PeerId, V_PeerInfo> _insertion;
  final deletion.Deletion<K_PeerId, V_PeerInfo> _deletion;
  final rb_search.Search<K_PeerId, V_PeerInfo> _search;

  /// Number of nodes in the tree.
  var size = 0;

  /// Whether the tree is empty.
  bool isEmpty = true;

  /// All entries as key-value pairs.
  var entries = <MapEntry<K_PeerId, V_PeerInfo>>[];

  /// Creates a Red-Black tree with optional comparator.
  RedBlackTree({int Function(K_PeerId, K_PeerId)? compare})
    : _compare = compare ?? ((a, b) => (a as int).compareTo(b as int)),
      _insertion = insertion.Insertion<K_PeerId, V_PeerInfo>(),
      _deletion = deletion.Deletion<K_PeerId, V_PeerInfo>(),
      _search = rb_search.Search<K_PeerId, V_PeerInfo>();

  // Insert a new node with the given key and value into the tree.
  void insert(K_PeerId keyInsert, V_PeerInfo valueInsert) {
    final newNode = RedBlackTreeNode(keyInsert, valueInsert);
    _insertion.insertNode(this, newNode); // Use _insertion instance
  }

  // Delete the node with the given key from the tree.
  void delete(K_PeerId key) {
    _deletion.deleteNode(this, key); // Use _deletion instance
  }

  // Search for a node with the given key in the tree.
  V_PeerInfo? search(K_PeerId key) {
    final node = _search.searchNode(this, key); // Use _search instance
    return node?.value;
  }

  // Public getter for the root node.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? get root => _root;

  // Setter for the root node.
  set root(RedBlackTreeNode<K_PeerId, V_PeerInfo>? newRoot) {
    _root = newRoot;
  }

  int compare(K_PeerId a, K_PeerId b) => _compare(a, b);

  void clear() {
    _root = null;
    size = 0;
    isEmpty = true;
    entries.clear();
  }

  // Add this operator definition
  void operator []=(K_PeerId key, V_PeerInfo value) {
    insert(key, value);
  }

  // Add operator [] getter
  V_PeerInfo? operator [](K_PeerId key) {
    return search(key);
  }

  // Add the remove method
  void remove(K_PeerId key) {
    _deletion.deleteNode(this, key); // Use the existing deletion logic
  }
}
