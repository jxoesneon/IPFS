// lib/src/protocols/dht/red_black_tree/insertion.dart

// This file handles the insertion of nodes into the Red-Black Tree used in the DHT.

import '../red_black_tree.dart';
import 'fix_violations.dart';
import '/../src/proto/dht/common_red_black_tree.pb.dart' as common_tree;

// The Insertion class provides methods to insert nodes while maintaining Red-Black Tree properties.
class Insertion<K_PeerId, V_PeerInfo> {
  // Inserts a new node into the Red-Black Tree.
  //
  // `tree`: The Red-Black Tree instance.
  // `node`: The node to be inserted.
  void insertNode<K_PeerId, V_PeerInfo>(
      RedBlackTree<K_PeerId, V_PeerInfo> tree,
      RedBlackTreeNode<K_PeerId, V_PeerInfo> node) {
    // `y` will eventually store the parent of the new node.
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? y = null;
    // `x` is used to traverse the tree to find the correct insertion point.
    RedBlackTreeNode<K_PeerId, V_PeerInfo>? x = tree.root;

    // Traverse the tree to find the appropriate position for the new node.
    while (x != null) {
      y = x; // Update `y` to the current node.
      // Compare the key of the new node with the key of the current node.
      final comparison = tree.compare(node.key as K_PeerId, x.key as K_PeerId);
      if (comparison < 0) {
        // If the new node's key is smaller, move to the left subtree.
        x = x.left_child;
      } else {
        // If the new node's key is larger or equal, move to the right subtree.
        x = x.right_child;
      }
    }

    // Set the parent of the new node to `y`.
    node.parent = y;
    if (y == null) {
      // If `y` is null, the tree was empty, and the new node becomes the root.
      tree.root = node; 
    } else if (tree.compare(node.key as K_PeerId, y.key as K_PeerId) < 0) {
      // If the new node's key is smaller than its parent's, it becomes the left child.
      y.left_child = node;
    } else {
      // Otherwise, it becomes the right child.
      y.right_child = node;
    }

    // New nodes are always inserted as RED to maintain Red-Black Tree properties.
    node.color = common_tree.NodeColor.RED; 
    // Ensure the root node remains black after insertion.
    if (tree.root != null && tree.root!.color == common_tree.NodeColor.RED) {
      tree.root!.color = common_tree.NodeColor.BLACK;
    }
    
    // Create an instance of FixViolations to handle potential Red-Black Tree violations.
    FixViolations<K_PeerId, V_PeerInfo> fixViolationsInstance = FixViolations<K_PeerId, V_PeerInfo>();
    // Call fixInsertion to restore Red-Black Tree properties if necessary.
    fixViolationsInstance.fixInsertion(tree, node);
  }
}
