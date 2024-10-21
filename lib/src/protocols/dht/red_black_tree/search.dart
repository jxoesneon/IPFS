// lib/src/protocols/dht/red_black_tree/search.dart
import '../red_black_tree.dart';

class Search<K_PeerId, V_PeerInfo> { 
  RedBlackTreeNode<K_PeerId, V_PeerInfo>? searchNode<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree, K_PeerId key) {
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? node = tree.root;

    while (node != null) {
      final comparison = tree.compare(key, node.key as K_PeerId);

      if (comparison == 0) {
        return node; // Key found
      } else if (comparison < 0) {
        node = node.left_child; // Search in the left subtree
      } else {
        node = node.right_child; // Search in the right subtree
      }
    }

    return null; // Key not found
  }
}