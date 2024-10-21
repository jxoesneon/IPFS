// lib/src/protocols/dht/red_black_tree.dart
import '/../src/proto/dht/common_tree.pb.dart' as common_tree;
import 'red_black_tree/insertion.dart' as insertion;
import 'red_black_tree/deletion.dart' as deletion;
import 'red_black_tree/search.dart' as rb_search;
import 'red_black_tree/rotations.dart' as rotations;
import 'red_black_tree/fix_violations.dart' as fix_violations;

// Represents a node in a Red-Black Tree.
class RedBlackTreeNode<K_PeerId, V_PeerInfo> {
  common_tree.K_PeerId key;
  common_tree.V_PeerInfo value;
  common_tree.NodeColor color;
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? left_child; // Renamed from 'left'
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? right_child; // Renamed from 'right'
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? parent;

  // Constructor
  RedBlackTreeNode(this.key, this.value,
      {this.color = common_tree.NodeColor.RED,
      this.left_child,
      this.right_child,
      this.parent});
}

class RedBlackTree<K_PeerId, V_PeerInfo> {
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? _root; // Private root node
  int Function(K_PeerId, K_PeerId) _compare;

  // Instances of insertion, deletion, and search classes
  final insertion.Insertion<K_PeerId, V_PeerInfo> _insertion;
  final deletion.Deletion<K_PeerId, V_PeerInfo> _deletion;
  final rb_search.Search<K_PeerId, V_PeerInfo> _search;

  var size;

  RedBlackTree({int Function(K_PeerId, K_PeerId)? compare})
      : _compare = compare ?? ((a, b) => (a as int).compareTo(b as int)),
        _insertion = insertion.Insertion<K_PeerId, V_PeerInfo>(),
        _deletion = deletion.Deletion<K_PeerId, V_PeerInfo>(),
        _search = rb_search.Search<K_PeerId, V_PeerInfo>();

  // Insert a new node with the given key and value into the tree.
  void insert(K_PeerId key_insert, V_PeerInfo value_insert) {
    final newNode = RedBlackTreeNode(key_insert as common_tree.K_PeerId,
        value_insert as common_tree.V_PeerInfo);
    _insertion.insertNode(this, newNode); // Use _insertion instance
  }

  // Delete the node with the given key from the tree.
  void delete(K_PeerId key) {
    _deletion.deleteNode(this, key); // Use _deletion instance
  }

  // Search for a node with the given key in the tree.
  common_tree.V_PeerInfo? search(K_PeerId key) {
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
}
