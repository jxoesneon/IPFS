// lib/src/protocols/dht/red_black_tree/fix_violations.dart

import '../../../proto/generated/dht/common_red_black_tree.pb.dart' as common_tree;
import '../red_black_tree.dart';
import 'rotations.dart';

/// Fixes Red-Black tree violations after insertions and deletions.
///
/// Restores tree balance through recoloring and rotations.
class FixViolations<K_PeerId, V_PeerInfo> {
  /// Fixes violations after inserting [z] into [tree].
  void fixInsertion(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo> z,
  ) {
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance = Rotations<K_PeerId, V_PeerInfo>();

    if (z.color != common_tree.NodeColor.RED) {
      z.color = common_tree.NodeColor.RED;
    }

    while (z.parent != null && z.parent!.color == common_tree.NodeColor.RED) {
      fixInsertionHelper(tree, z, rotationsInstance, z.parent == z.parent!.parent!.rightChild);
    }

    tree.root?.color = common_tree.NodeColor.BLACK;
  }

  /// Helper for insertion fix-up operations.
  void fixInsertionHelper(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo> z,
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance,
    bool isMirrorCase,
  ) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y;

    if (isMirrorCase) {
      y = z.parent!.parent!.leftChild;
    } else {
      y = z.parent!.parent!.rightChild;
    }

    if (y != null && y.color == common_tree.NodeColor.RED) {
      z.parent!.color = common_tree.NodeColor.BLACK;
      y.color = common_tree.NodeColor.BLACK;
      z.parent!.parent!.color = common_tree.NodeColor.RED;
      z = z.parent!.parent!;
    } else {
      if (isMirrorCase) {
        if (z == z.parent!.leftChild) {
          z = z.parent!;
          rotationsInstance.rotateRight(tree, z);
        }
        z.parent!.color = common_tree.NodeColor.BLACK;
        z.parent!.parent!.color = common_tree.NodeColor.RED;
        rotationsInstance.rotateLeft(tree, z.parent!.parent!);
      } else {
        if (z == z.parent!.rightChild) {
          z = z.parent!;
          rotationsInstance.rotateLeft(tree, z);
        }
        z.parent!.color = common_tree.NodeColor.BLACK;
        z.parent!.parent!.color = common_tree.NodeColor.RED;
        rotationsInstance.rotateRight(tree, z.parent!.parent!);
      }
    }
  }

  /// Fixes violations after deleting a node.
  void fixDeletion(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? parent,
  ) {
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance = Rotations<K_PeerId, V_PeerInfo>();

    if (x == null || x.color == common_tree.NodeColor.RED) {
      return; // No need to fix violations if the node is red or null
    }

    while (x != tree.root && x?.color == common_tree.NodeColor.BLACK) {
      if (x == parent?.leftChild) {
        var w = parent?.rightChild;
        if (w?.color == common_tree.NodeColor.RED) {
          w?.color = common_tree.NodeColor.BLACK;
          parent?.color = common_tree.NodeColor.RED;
          rotationsInstance.rotateLeft(tree, parent!);
          w = parent.rightChild;
        }
        if ((w?.leftChild == null || w?.leftChild!.color == common_tree.NodeColor.BLACK) &&
            (w?.rightChild == null || w?.rightChild!.color == common_tree.NodeColor.BLACK)) {
          w?.color = common_tree.NodeColor.RED;
          x = parent!;
        } else {
          if (w?.rightChild == null || w?.rightChild!.color == common_tree.NodeColor.BLACK) {
            w?.leftChild?.color = common_tree.NodeColor.BLACK;
            w?.color = common_tree.NodeColor.RED;
            rotationsInstance.rotateRight(tree, w!);
            w = parent?.rightChild;
          }
          w?.color = parent!.color;
          parent?.color = common_tree.NodeColor.BLACK;
          w?.rightChild?.color = common_tree.NodeColor.BLACK;
          rotationsInstance.rotateLeft(tree, parent!);
          x = tree.root!;
        }
      } else {
        // Mirror case for right child
        var w = parent?.leftChild;
        if (w?.color == common_tree.NodeColor.RED) {
          w?.color = common_tree.NodeColor.BLACK;
          parent?.color = common_tree.NodeColor.RED;
          rotationsInstance.rotateRight(tree, parent!);
          w = parent.leftChild;
        }
        if ((w?.rightChild == null || w?.rightChild!.color == common_tree.NodeColor.BLACK) &&
            (w?.leftChild == null || w?.leftChild!.color == common_tree.NodeColor.BLACK)) {
          w?.color = common_tree.NodeColor.RED;
          x = parent!;
        } else {
          if (w?.leftChild == null || w?.leftChild!.color == common_tree.NodeColor.BLACK) {
            w?.rightChild?.color = common_tree.NodeColor.BLACK;
            w?.color = common_tree.NodeColor.RED;
            rotationsInstance.rotateLeft(tree, w!);
            w = parent?.leftChild;
          }
          w?.color = parent!.color;
          parent?.color = common_tree.NodeColor.BLACK;
          w?.leftChild?.color = common_tree.NodeColor.BLACK;
          rotationsInstance.rotateRight(tree, parent!);
          x = tree.root!;
        }
      }
    }
    x?.color = common_tree.NodeColor.BLACK;
  }
}
