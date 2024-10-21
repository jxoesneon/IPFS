// lib/src/protocols/dht/red_black_tree/insertion.dart
import '../red_black_tree.dart';
import 'fix_violations.dart' as fix_violations;
import 'rotations.dart' as rotations;

class Insertion<K_PeerId, V_PeerInfo> {
  void insertNode<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo> node) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = null;
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x = tree.root;

    while (x != null) {
      y = x;
      final comparison = tree.compare(node.key, x.key);
      if (comparison < 0) {
        x = x.left_child;
      } else {
        x = x.right_child;
      }
    }

    node.parent = y;
    if (y == null) {
      tree._root = node; // if y is null, it means x was null and the tree was empty. So node is the new root
    } else if (tree.compare(node.key, y.key) < 0) {
      y.left_child = node;
    } else {
      y.right_child = node;
    }

    node.color = common_tree.NodeColor.RED; // New nodes are always inserted as RED
    fix_violations._fixInsertion(tree, node);
  }
}