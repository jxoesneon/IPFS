// lib/src/protocols/dht/red_black_tree/rotations.dart
import '../red_black_tree.dart';
class Rotations<K_PeerId, V_PeerInfo> {
  void rotateLeft<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo> x) {
    // 1. Get the right child of x, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = x.right_child;

    // 2. Update x's right child to be y's left child (transfer y's left subtree)
    x.right_child = y?.left_child;
    if (y?.left_child != null) {
      y?.left_child?.parent = x;
    }

    // 3. Update y's parent to be x's parent
    y?.parent = x.parent;

    // 4. If x was the root, y becomes the new root
    if (x.parent == null) {
      tree._root = y;
    } else if (x == x.parent.left_child) {
      // If x was a left child, make y the left child of x's parent
      x.parent.left_child = y;
    } else {
      // If x was a right child, make y the right child of x's parent
      x.parent.right_child = y;
    }

    // 5. Make x the left child of y
    y?.left_child = x;
    x.parent = y;
  }

  void rotateRight<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo> y) {
    // 1. Get the left child of y, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x = y.left_child;

    // 2. Update y's left child to be x's right child (transfer x's right subtree)
    y.left_child = x?.right_child;
    if (x?.right_child != null) {
      x?.right_child?.parent = y;
    }

    // 3. Update x's parent to be y's parent
    x?.parent = y.parent;

    // 4. If y was the root, x becomes the new root
    if (y.parent == null) {
      tree._root = x;
    } else if (y == y.parent.right_child) {
      // If y was a right child, make x the right child of y's parent
      y.parent.right_child = x;
    } else {
      // If y was a left child, make x the left child of y's parent
      y.parent.left_child = x;
    }

    // 5. Make y the right child of x
    x?.right_child = y;
    y.parent = x;
  }
}