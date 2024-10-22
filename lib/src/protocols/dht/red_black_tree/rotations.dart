// lib/src/protocols/dht/red_black_tree/rotations.dart
import '../red_black_tree.dart';
import '/../src/proto/dht/common_red_black_tree.pb.dart' as common_tree;

class Rotations<K_PeerId, V_PeerInfo> {
  void rotateLeft<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo>? x) {
    if (x == null) return; // Null nodes are treated as black (leaves)
    
    // 1. Get the right child of x, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = x.right_child;
    if (y == null) return; // Ensure y is not null for the rotation

    // 2. Update x's right child to be y's left child (transfer y's left subtree)
    x.right_child = y.left_child;
    if (y.left_child != null) {
      y.left_child?.parent = x;
    }

    // 3. Update y's parent to be x's parent
    y.parent = x.parent;

    // 4. If x was the root, y becomes the new root
    if (x.parent == null) {
      tree.root = y;  // Root node update
    } else if (x == x.parent?.left_child) {
      x.parent?.left_child = y;
    } else {
      x.parent?.right_child = y;
    }

    // 5. Make x the left child of y
    y.left_child = x;
    x.parent = y;

    // Verify tree.root update when root node is involved
    assert(tree.root == y || tree.root != x, "Root node not updated correctly in rotateLeft");
  }

  void rotateRight<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo>? y) {
    if (y == null) return; // Null nodes are treated as black (leaves)

    // 1. Get the left child of y, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x = y.left_child;
    if (x == null) return; // Ensure x is not null for the rotation

    // 2. Update y's left child to be x's right child (transfer x's right subtree)
    y.left_child = x.right_child;
    if (x.right_child != null) {
      x.right_child?.parent = y;
    }

    // 3. Update x's parent to be y's parent
    x.parent = y.parent;

    // 4. If y was the root, x becomes the new root
    if (y.parent == null) {
      tree.root = x;  // Root node update
    } else if (y == y.parent?.right_child) {
      y.parent?.right_child = x;
    } else {
      y.parent?.left_child = x;
    }

    // 5. Make y the right child of x
    x.right_child = y;
    y.parent = x;

    // Verify tree.root update when root node is involved
    assert(tree.root == x || tree.root != y, "Root node not updated correctly in rotateRight");
  }

  // Validation method for node colors (all nodes must be either red or black)
  bool validateNodeColors(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
    if (node == null) return true; // Null nodes (leaves) are treated as black
    if (node.color != common_tree.NodeColor.RED && node.color != common_tree.NodeColor.BLACK) {
      return false; // Every node must be either red or black
    }
    return validateNodeColors(node.left_child) && validateNodeColors(node.right_child);
  }

  // Validate the red-black tree properties
  bool validateTree(RedBlackTree<K_PeerId, V_PeerInfo> tree) {
    // 1. The root must be black
    if (tree.root == null || tree.root!.color != common_tree.NodeColor.BLACK) {
      return false;
    }

    // 2. Red nodes must have black children (no consecutive red nodes)
    bool validateRedProperty(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
      if (node == null) return true;
      if (node.color == common_tree.NodeColor.RED) {
        if ((node.left_child != null && node.left_child!.color == common_tree.NodeColor.RED) ||
            (node.right_child != null && node.right_child!.color == common_tree.NodeColor.RED)) {
          return false;
        }
      }
      return validateRedProperty(node.left_child) && validateRedProperty(node.right_child);
    }

    // 3. Every path from root to leaf must have the same number of black nodes (black-height property)
    int countBlackNodes(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
      if (node == null) return 1; // Null nodes (leaves) count as black
      int left = countBlackNodes(node.left_child);
      int right = countBlackNodes(node.right_child);
      if (left != right) {
        throw StateError('Black height property violated');
      }
      return node.color == common_tree.NodeColor.BLACK ? left + 1 : left;
    }

    try {
      return validateRedProperty(tree.root) && 
             countBlackNodes(tree.root) > 0 && 
             validateNodeColors(tree.root);  // Ensure all nodes are either red or black
    } catch (e) {
      print(e);
      return false;
    }
    
    // TODO: Enhance validateTree with additional checks for all Red-Black Tree properties,
    // including any performance optimizations or more complex cases for tree balancing.
  }
}
