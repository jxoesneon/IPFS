// lib/src/protocols/dht/red_black_tree/deletion.dart
import '../red_black_tree.dart';
import 'fix_violations.dart';
import '/../src/proto/dht/common_red_black_tree.pb.dart' as common_tree;

class Deletion<K_PeerId, V_PeerInfo> {
  void delete(RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    deleteNode(tree, key);
  }

  void deleteNode(RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? z = searchNode(tree, key);

    if (z == null) {
      // Key not found, nothing to delete
      return;
    }

    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = z;
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x;
    var yOriginalColor = y.color;

    if (z.left_child == null) {
      x = z.right_child;
      transplant(tree, z, z.right_child);
    } else if (z.right_child == null) {
      x = z.left_child;
      transplant(tree, z, z.left_child);
    } else {
      y = minimum(z.right_child!);
      yOriginalColor = y!.color;
      x = y.right_child;
      if (y.parent == z) {
        x?.parent = y;
      } else {
        transplant(tree, y, y.right_child);
        y.right_child = z.right_child;
        y.right_child?.parent = y;
      }
      transplant(tree, z, y);
      y.left_child = z.left_child;
      y.left_child?.parent = y;
      y.color = z.color;
    }

    // Create an instance of FixViolations to fix any violations after deletion
    FixViolations<K_PeerId, V_PeerInfo> fixViolations =
        FixViolations<K_PeerId, V_PeerInfo>();

    if (yOriginalColor == common_tree.NodeColor.BLACK) {
      fixViolations.fixDeletion(tree, x!, x.parent); // Fix any violations
    }
  }

  void transplant(RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo> u,
      RedBlackTreeNode<K_PeerId, V_PeerInfo>? v) {
    if (u.parent == null) {
      tree.root = v;
    } else if (u == u.parent!.left_child) {
      u.parent!.left_child = v;
    } else {
      u.parent!.right_child = v;
    }
    v?.parent = u.parent;
  }

  RedBlackTreeNode<K_PeerId, V_PeerInfo>? minimum(
      RedBlackTreeNode<K_PeerId, V_PeerInfo> node) {
    while (node.left_child != null) {
      node = node.left_child!;
    }
    return node;
  }

  RedBlackTreeNode<K_PeerId, V_PeerInfo>? searchNode(
      RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? node = tree.root;

    while (node != null) {
      final comparison = tree.compare(key, node.key as K_PeerId);

      if (comparison == 0) {
        return node; // Key found
      } else if (comparison < 0) {
        node = node.left_child; // Search in the left_child subtree
      } else {
        node = node.right_child; // Search in the right_child subtree
      }
    }

    return null; // Key not found
  }
}