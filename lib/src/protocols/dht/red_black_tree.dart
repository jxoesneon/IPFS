// lib/src/protocols/dht/red_black_tree.dart

import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart' as common_tree;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/deletion.dart' as deletion;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/insertion.dart' as insertion;
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/search.dart' as rb_search;

/// A node in the Red-Black tree.
class RedBlackTreeNode<K_PeerId, V_PeerInfo> {
  /// Creates a tree node.
  RedBlackTreeNode(
    this.key,
    this.value, {
    this.color = common_tree.NodeColor.RED,
    this.leftChild,
    this.rightChild,
    this.parent,
  });

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
}

/// Self-balancing Red-Black tree for efficient peer lookup.
///
/// Used in Kademlia k-buckets for O(log n) peer operations.
class RedBlackTree<K_PeerId, V_PeerInfo> {
  /// Creates a Red-Black tree with optional comparator.
  RedBlackTree({int Function(K_PeerId, K_PeerId)? compare})
    : _compare = compare ?? ((a, b) => (a as int).compareTo(b as int)),
      _insertion = insertion.Insertion<K_PeerId, V_PeerInfo>(),
      _deletion = deletion.Deletion<K_PeerId, V_PeerInfo>(),
      _search = rb_search.Search<K_PeerId, V_PeerInfo>();

  /// The root node.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? root;

  final int Function(K_PeerId, K_PeerId) _compare;

  final insertion.Insertion<K_PeerId, V_PeerInfo> _insertion;
  final deletion.Deletion<K_PeerId, V_PeerInfo> _deletion;
  final rb_search.Search<K_PeerId, V_PeerInfo> _search;

  /// Number of nodes in the tree.
  var size = 0;

  /// Whether the tree is empty.
  bool isEmpty = true;

  /// All entries as key-value pairs.
  var entries = <MapEntry<K_PeerId, V_PeerInfo>>[];

  /// Inserts a new node with the given key and value.
  void insert(K_PeerId keyInsert, V_PeerInfo valueInsert) {
    final newNode = RedBlackTreeNode(keyInsert, valueInsert);
    _insertion.insertNode(this, newNode);
  }

  /// Deletes the node with the given key.
  void delete(K_PeerId key) {
    _deletion.deleteNode(this, key);
  }

  /// Searches for a node with the given key.
  V_PeerInfo? search(K_PeerId key) {
    final node = _search.searchNode(this, key);
    return node?.value;
  }

  /// Compares two keys.
  int compare(K_PeerId a, K_PeerId b) => _compare(a, b);

  /// Clears all nodes from the tree.
  void clear() {
    root = null;
    size = 0;
    isEmpty = true;
    entries.clear();
  }

  /// Sets a value by key (insertion).
  void operator []=(K_PeerId key, V_PeerInfo value) {
    insert(key, value);
  }

  /// Gets a value by key.
  V_PeerInfo? operator [](K_PeerId key) {
    return search(key);
  }

  /// Removes a node by key.
  void remove(K_PeerId key) {
    _deletion.deleteNode(this, key);
  }
}
