// lib/src/protocols/dht/red_black_tree/deletion.dart
import '../../../proto/generated/dht/common_red_black_tree.pb.dart'
    as common_tree;
import '../red_black_tree.dart';
import 'fix_violations.dart';

/// Handles deletion operations for Red-Black trees.
///
/// Removes nodes while maintaining Red-Black tree properties
/// through transplanting and fix-up operations.
class Deletion<K_PeerId, V_PeerInfo> {
  /// Deletes the node with [key] from [tree].
  void delete(RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    deleteNode(tree, key);
  }

  /// Internal deletion with tree balancing.
  void deleteNode(RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? z = searchNode(tree, key);

    if (z == null) {
      // Key not found, nothing to delete
      return;
    }

    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = z;
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x;
    var yOriginalColor = y.color;

    if (z.leftChild == null) {
      x = z.rightChild;
      transplant(tree, z, z.rightChild);
    } else if (z.rightChild == null) {
      x = z.leftChild;
      transplant(tree, z, z.leftChild);
    } else {
      y = minimum(z.rightChild!);
      yOriginalColor = y!.color;
      x = y.rightChild;
      if (y.parent == z) {
        x?.parent = y;
      } else {
        transplant(tree, y, y.rightChild);
        y.rightChild = z.rightChild;
        y.rightChild?.parent = y;
      }
      transplant(tree, z, y);
      y.leftChild = z.leftChild;
      y.leftChild?.parent = y;
      y.color = z.color;
    }

    // Create an instance of FixViolations to fix any violations after deletion
    FixViolations<K_PeerId, V_PeerInfo> fixViolations =
        FixViolations<K_PeerId, V_PeerInfo>();

    if (yOriginalColor == common_tree.NodeColor.BLACK && x != null) {
      fixViolations.fixDeletion(tree, x, x.parent); // Fix any violations
    }

    // Update tree size and entries
    tree.size--;
    if (tree.size == 0) {
      tree.isEmpty = true;
    }
  }

  /// Replaces subtree rooted at [u] with subtree rooted at [v].
  void transplant(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo> u,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? v,
  ) {
    if (u.parent == null) {
      tree.root = v;
    } else if (u == u.parent!.leftChild) {
      u.parent!.leftChild = v;
    } else {
      u.parent!.rightChild = v;
    }
    v?.parent = u.parent;
  }

  /// Finds the minimum node in a subtree.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? minimum(
    RedBlackTreeNode<K_PeerId, V_PeerInfo> node,
  ) {
    while (node.leftChild != null) {
      node = node.leftChild!;
    }
    return node;
  }

  /// Searches for a node by key.
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? searchNode(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    K_PeerId key,
  ) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? node = tree.root;

    while (node != null) {
      final comparison = tree.compare(key, node.key);

      if (comparison == 0) {
        return node; // Key found
      } else if (comparison < 0) {
        node = node.leftChild; // Search in the leftChild subtree
      } else {
        node = node.rightChild; // Search in the rightChild subtree
      }
    }

    return null; // Key not found
  }
}

