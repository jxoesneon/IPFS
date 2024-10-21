// lib/src/protocols/dht/red_black_tree/fix_violations.dart

import '../red_black_tree.dart';
import 'rotations.dart';
import '/../src/proto/dht/common_tree.pb.dart' as common_tree;

class FixViolations<K_PeerId, V_PeerInfo> {
  void fixInsertion(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo> z
  ) {
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance = Rotations<K_PeerId, V_PeerInfo>();

    if (z.color != common_tree.NodeColor.RED) {
      z.color = common_tree.NodeColor.RED;
    }

    while (z.parent != null && z.parent!.color == common_tree.NodeColor.RED) {
      fixInsertionHelper(tree, z, rotationsInstance,
        z.parent == z.parent!.parent!.right_child);
    }

    tree.root?.color = common_tree.NodeColor.BLACK;
  }

  void fixInsertionHelper(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo> z,
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance,
    bool isMirrorCase
  ) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y;

    if (isMirrorCase) {
      y = z.parent!.parent!.left_child;
    } else {
      y = z.parent!.parent!.right_child;
    }

    if (y != null && y.color == common_tree.NodeColor.RED) {
      z.parent!.color = common_tree.NodeColor.BLACK;
      y.color = common_tree.NodeColor.BLACK;
      z.parent!.parent!.color = common_tree.NodeColor.RED;
      z = z.parent!.parent!;
    } else {
      if (isMirrorCase) {
        if (z == z.parent!.left_child) {
          z = z.parent!;
          rotationsInstance.rotateRight(tree, z);
        }
        z.parent!.color = common_tree.NodeColor.BLACK;
        z.parent!.parent!.color = common_tree.NodeColor.RED;
        rotationsInstance.rotateLeft(tree, z.parent!.parent!);
      } else {
        if (z == z.parent!.right_child) {
          z = z.parent!;
          rotationsInstance.rotateLeft(tree, z);
        }
        z.parent!.color = common_tree.NodeColor.BLACK;
        z.parent!.parent!.color = common_tree.NodeColor.RED;
        rotationsInstance.rotateRight(tree, z.parent!.parent!);
      }
    }
  }

  void fixDeletion(
    RedBlackTree<K_PeerId, V_PeerInfo> tree,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x,
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? parent
  ) {
    Rotations<K_PeerId, V_PeerInfo> rotationsInstance = Rotations<K_PeerId, V_PeerInfo>();

    if (x == null || x.color == common_tree.NodeColor.RED) {
      return; // No need to fix violations if the node is red or null
    }

    while (x != tree.root && x?.color == common_tree.NodeColor.BLACK) {
      if (x == parent?.left_child) {
        var w = parent?.right_child;
        if (w?.color == common_tree.NodeColor.RED) {
          w?.color = common_tree.NodeColor.BLACK;
          parent?.color = common_tree.NodeColor.RED;
          rotationsInstance.rotateLeft(tree, parent!);
          w = parent.right_child;
        }
        if ((w?.left_child == null || w?.left_child!.color == common_tree.NodeColor.BLACK) &&
            (w?.right_child == null || w?.right_child!.color == common_tree.NodeColor.BLACK)) {
          w?.color = common_tree.NodeColor.RED;
          x = parent!;
        } else {
          if (w?.right_child == null || w?.right_child!.color == common_tree.NodeColor.BLACK) {
            w?.left_child?.color = common_tree.NodeColor.BLACK;
            w?.color = common_tree.NodeColor.RED;
            rotationsInstance.rotateRight(tree, w!);
            w = parent?.right_child;
          }
          w?.color = parent!.color;
          parent?.color = common_tree.NodeColor.BLACK;
          w?.right_child?.color = common_tree.NodeColor.BLACK;
          rotationsInstance.rotateLeft(tree, parent!);
          x = tree.root!;
        }
      } else {
        // Mirror case for right child
        var w = parent?.left_child;
        if (w?.color == common_tree.NodeColor.RED) {
          w?.color = common_tree.NodeColor.BLACK;
          parent?.color = common_tree.NodeColor.RED;
          rotationsInstance.rotateRight(tree, parent!);
          w = parent.left_child;
        }
        if ((w?.right_child == null || w?.right_child!.color == common_tree.NodeColor.BLACK) &&
            (w?.left_child == null || w?.left_child!.color == common_tree.NodeColor.BLACK)) {
          w?.color = common_tree.NodeColor.RED;
          x = parent!;
        } else {
          if (w?.left_child == null || w?.left_child!.color == common_tree.NodeColor.BLACK) {
            w?.right_child?.color = common_tree.NodeColor.BLACK;
            w?.color = common_tree.NodeColor.RED;
            rotationsInstance.rotateLeft(tree, w!);
            w = parent?.left_child;
          }
          w?.color = parent!.color;
          parent?.color = common_tree.NodeColor.BLACK;
          w?.left_child?.color = common_tree.NodeColor.BLACK;
          rotationsInstance.rotateRight(tree, parent!);
          x = tree.root!;
        }
      }
    }
    x?.color = common_tree.NodeColor.BLACK;
  }
}
