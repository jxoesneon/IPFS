// lib/src/protocols/dht/red_black_tree/rotations.dart
import '../../../proto/generated/dht/common_red_black_tree.pb.dart'
    as common_tree;
import '../red_black_tree.dart';

/// Handles rotation operations for Red-Black tree balancing.
///
/// Provides left and right rotations, plus tree validation.
class Rotations<K_PeerId, V_PeerInfo> {
  /// Performs a left rotation around [x].
  void rotateLeft(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x,
  ) {
    if (x == null) return; // Null nodes are treated as black (leaves)

    // 1. Get the right child of x, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = x.rightChild;
    if (y == null) return; // Ensure y is not null for the rotation

    // 2. Update x's right child to be y's left child (transfer y's left subtree)
    x.rightChild = y.leftChild;
    if (y.leftChild != null) {
      y.leftChild?.parent = x;
    }

    // 3. Update y's parent to be x's parent
    y.parent = x.parent;

    // 4. If x was the root, y becomes the new root
    if (x.parent == null) {
      tree.root = y; // Root node update
    } else if (x == x.parent?.leftChild) {
      x.parent?.leftChild = y;
    } else {
      x.parent?.rightChild = y;
    }

    // 5. Make x the left child of y
    y.leftChild = x;
    x.parent = y;

    // Verify tree.root update when root node is involved
    assert(
      tree.root == y || tree.root != x,
      'Root node not updated correctly in rotateLeft',
    );
  }

  void rotateRight(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y,
  ) {
    if (y == null) return; // Null nodes are treated as black (leaves)

    // 1. Get the left child of y, which will become the new parent
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x = y.leftChild;
    if (x == null) return; // Ensure x is not null for the rotation

    // 2. Update y's left child to be x's right child (transfer x's right subtree)
    y.leftChild = x.rightChild;
    if (x.rightChild != null) {
      x.rightChild?.parent = y;
    }

    // 3. Update x's parent to be y's parent
    x.parent = y.parent;

    // 4. If y was the root, x becomes the new root
    if (y.parent == null) {
      tree.root = x; // Root node update
    } else if (y == y.parent?.rightChild) {
      y.parent?.rightChild = x;
    } else {
      y.parent?.leftChild = x;
    }

    // 5. Make y the right child of x
    x.rightChild = y;
    y.parent = x;

    // Verify tree.root update when root node is involved
    assert(
      tree.root == x || tree.root != y,
      'Root node not updated correctly in rotateRight',
    );
  }

  // Validation method for node colors (all nodes must be either red or black)
  bool validateNodeColors(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
    if (node == null) return true; // Null nodes (leaves) are treated as black
    if (node.color != common_tree.NodeColor.RED &&
        node.color != common_tree.NodeColor.BLACK) {
      return false; // Every node must be either red or black
    }
    return validateNodeColors(node.leftChild) &&
        validateNodeColors(node.rightChild);
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
        if ((node.leftChild != null &&
                node.leftChild!.color == common_tree.NodeColor.RED) ||
            (node.rightChild != null &&
                node.rightChild!.color == common_tree.NodeColor.RED)) {
          return false;
        }
      }
      return validateRedProperty(node.leftChild) &&
          validateRedProperty(node.rightChild);
    }

    // 3. Every path from root to leaf must have the same number of black nodes (black-height property)
    int countBlackNodes(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
      if (node == null) return 1; // Null nodes (leaves) count as black
      int left = countBlackNodes(node.leftChild);
      int right = countBlackNodes(node.rightChild);
      if (left != right) {
        throw StateError('Black height property violated');
      }
      return node.color == common_tree.NodeColor.BLACK ? left + 1 : left;
    }

    // 4. Validate parent pointers
    bool validateParentPointers(
      RedBlackTreeNode<K_PeerId, V_PeerInfo>? node,
      RedBlackTreeNode<K_PeerId, V_PeerInfo>? expectedParent,
    ) {
      if (node == null) return true;
      if (node.parent != expectedParent) return false;
      return validateParentPointers(node.leftChild, node) &&
          validateParentPointers(node.rightChild, node);
    }

    // 5. Validate binary search tree property
    bool validateBSTProperty(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
      if (node == null) return true;

      if (node.leftChild != null &&
          tree.compare(node.leftChild!.key, node.key) >= 0) {
        return false;
      }

      if (node.rightChild != null &&
          tree.compare(node.rightChild!.key, node.key) <= 0) {
        return false;
      }

      return validateBSTProperty(node.leftChild) &&
          validateBSTProperty(node.rightChild);
    }

    // 6. Validate tree size
    int validateSize(RedBlackTreeNode<K_PeerId, V_PeerInfo>? node) {
      if (node == null) return 0;
      return 1 + validateSize(node.leftChild) + validateSize(node.rightChild);
    }

    try {
      // Run all validations
      final bool isValid =
          validateRedProperty(tree.root) &&
          countBlackNodes(tree.root) > 0 &&
          validateNodeColors(tree.root) &&
          validateParentPointers(tree.root, null) &&
          validateBSTProperty(tree.root);

      // Verify tree size if size property is maintained
      if (tree.size != validateSize(tree.root)) {
        return false;
      }

      return isValid;
    } catch (e) {
      // print('Validation error: $e');
      return false;
    }
  }
}
