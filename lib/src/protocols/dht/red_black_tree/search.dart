// lib/src/protocols/dht/red_black_tree/search.dart
import '../red_black_tree.dart';

/// Handles search operations for Red-Black trees.
///
/// Provides O(log n) key lookup.
class Search<K_PeerId, V_PeerInfo> {
  /// Searches for [key] in [tree], returning the node if found.
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
        node = node.leftChild; // Search in the left subtree
      } else {
        node = node.rightChild; // Search in the right subtree
      }
    }

    return null; // Key not found
  }
}

