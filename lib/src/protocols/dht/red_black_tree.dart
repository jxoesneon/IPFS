// lib/src/protocols/dht/red_black_tree.dart

import 'package:collection/collection.dart';
import '/../src/proto/dht/red_black_tree.pb.dart'; // Import generated types from red_black_tree.proto
import '/../src/proto/dht/kademlia_tree.pb.dart'; // Import generated types from kademlia_tree.proto
import '/../src/proto/dht/routing_table.pb.dart'; // Import generated types from routing_table.proto
import '/../src/proto/dht/common_tree.pb.dart'; // Import generated types from common_tree.proto

class RedBlackTreeNode<K, V> {
  K key;
  V value;
  NodeColor color;
  RedBlackTreeNode<K, V>? parent;
  RedBlackTreeNode<K, V>? left;
  RedBlackTreeNode<K, V>? right;

  RedBlackTreeNode(this.key, this.value,
      {this.color = NodeColor.RED, this.parent, this.left, this.right});
}

class RedBlackTree<K extends Comparable<int>, V> {
  RedBlackTreeNode<K, V>? root;
  final Comparator<K> compare;

  RedBlackTree({Comparator<K>? compare}) : compare = compare ?? ((K a, K b) => (a as int).compareTo(b as int));



  void insert(K key, V value) {
    RedBlackTreeNode<K, V> newNode = RedBlackTreeNode(key, value);
    _insertNode(newNode);
    _fixInsertion(newNode);
    root?.color = NodeColor.BLACK;

  }

  void delete(K key) {
    RedBlackTreeNode<K, V>? nodeToRemove = _searchNode(key);
    if (nodeToRemove != null) {
      _deleteNode(nodeToRemove);
    }
    root?.color = NodeColor.BLACK;
    _checkAndAdjustRedBlackProperties(root);
  }

  V? search(K key) {
    RedBlackTreeNode<K, V>? node = _searchNode(key);
    return node?.value;
  }

  // Internal helper methods

  void _insertNode(RedBlackTreeNode<K, V> node) {
    RedBlackTreeNode<K, V>? current = root;
    RedBlackTreeNode<K, V>? parent;

    while (current != null) {
      parent = current;
      if (compare(node.key, current.key) < 0) {
        current = current.left;
      } else {
        current = current.right;
      }
    }

    node.parent = parent;
    if (parent == null) {
      root = node;
    } else if (compare(node.key, parent.key) < 0) {
      parent.left = node;
    } else {
      parent.right = node;
    }

    if (node.color == NodeColor.RED && node.parent?.color == NodeColor.RED) {
    // Red Node Property violation detected!
    _checkAndAdjustRedBlackProperties(node);
    }
  }

  void _transplant(RedBlackTreeNode<K, V> u, RedBlackTreeNode<K, V>? v) {
    if (u.parent == null) {
      root = v; // If u is the root, v becomes the new root
    } else if (u == u.parent!.left) {
      u.parent!.left = v; // If u is the left child, v becomes the new left child
    } else {
      u.parent!.right = v; // If u is the right child, v becomes the new right child
    }
    if (v != null) {
      v.parent = u.parent; // Update v's parent to u's parent
    }
  }

  RedBlackTreeNode<K, V> _minimum(RedBlackTreeNode<K, V> node) {
    while (node.left != null) {
      node = node.left!;
    }
    return node;
  }

  void _fixDeletion(RedBlackTreeNode<K, V>? x, RedBlackTreeNode<K, V>? xParent) {
    while (x != root && (x == null || x.color == NodeColor.BLACK)) {
      if (x == xParent?.left) { // x is a left child
        RedBlackTreeNode<K, V>? w = xParent?.right; // w is x's sibling
        if (w != null && w.color == NodeColor.RED) { // Case 1: x's sibling w is red
          w.color = NodeColor.BLACK;
          xParent!.color = NodeColor.RED;
          _rotateLeft(xParent);
          w = xParent.right;
        }
        if ((w?.left == null || w!.left!.color == NodeColor.BLACK) &&
            (w?.right == null || w!.right!.color == NodeColor.BLACK)) { // Case 2: x's sibling w is black, and both of w's children are black
          if (w != null) {
            w.color = NodeColor.RED;
          }
          x = xParent;
          xParent = x?.parent;
        } else {
          if (w.right == null || w.right!.color == NodeColor.BLACK) { // Case 3: x's sibling w is black, w's left child is red, and w's right child is black
            if (w.left != null) {
              w.left!.color = NodeColor.BLACK;
              w.color = NodeColor.RED;
              _rotateRight(w);
              w = xParent!.right;
            }
          }
          if (w != null) {
            w.color = xParent!.color;
          }
          xParent!.color = NodeColor.BLACK;
          if (w != null && w.right != null) {
            w.right!.color = NodeColor.BLACK;
          }
          _rotateLeft(xParent);
          x = root;
        }
      } else { // x is a right child (symmetric cases)
        // ... (Implementation for the symmetric cases, similar to above)
        RedBlackTreeNode<K, V>? w = xParent?.left; // w is x's sibling
        if (w != null && w.color == NodeColor.RED) {
          w.color = NodeColor.BLACK;
          xParent!.color = NodeColor.RED;
          _rotateRight(xParent);
          w = xParent.left;
        }
        if ((w?.right == null || w!.right!.color == NodeColor.BLACK) &&
            (w?.left == null || w!.left!.color == NodeColor.BLACK)) {
          if (w != null) {
            w.color = NodeColor.RED;
          }
          x = xParent;
          xParent = x?.parent;
        } else {
          if (w.left == null || w.left!.color == NodeColor.BLACK) {
            if (w.right != null) {
              w.right!.color = NodeColor.BLACK;
              w.color = NodeColor.RED;
              _rotateLeft(w);
              w = xParent!.left;
            }
          }
          if (w != null) {
            w.color = xParent!.color;
          }
          xParent!.color = NodeColor.BLACK;
          if (w != null && w.left != null) {
            w.left!.color = NodeColor.BLACK;
          }
          _rotateRight(xParent);
          x = root;
        }
      }
    }
    if (x != null) {
      x.color = NodeColor.BLACK;
    }
  }

  void _fixInsertion(RedBlackTreeNode<K, V> node) {
    while (node != root && node.parent?.color == NodeColor.RED) {
      if (node.parent == node.parent?.parent?.left) {
        RedBlackTreeNode<K, V>? uncle = node.parent?.parent?.right;
        if (uncle?.color == NodeColor.RED) {
          node.parent?.color = NodeColor.BLACK;
          uncle?.color = NodeColor.BLACK;
          node.parent?.parent?.color = NodeColor.RED;
          node = node.parent?.parent ?? node;
        } else {
          if (node == node.parent?.right) {
            node = node.parent ?? node;
            _rotateLeft(node);
          }
          node.parent?.color = NodeColor.BLACK;
          node.parent?.parent?.color = NodeColor.RED;
          _rotateRight(node.parent?.parent ?? node);
        }
      } else {
        // Symmetric case: node's parent is the right child of its grandparent
        RedBlackTreeNode<K, V>? uncle = node.parent?.parent?.left;
        if (uncle?.color == NodeColor.RED) {
          node.parent?.color = NodeColor.BLACK;
          uncle?.color = NodeColor.BLACK;
          node.parent?.parent?.color = NodeColor.RED;
          node = node.parent?.parent ?? node;
        } else {
          if (node == node.parent?.left) {
            node = node.parent ?? node;
            _rotateRight(node);
          }
          node.parent?.color = NodeColor.BLACK;
          node.parent?.parent?.color = NodeColor.RED;
          _rotateLeft(node.parent?.parent ?? node);
        }
      }
    }
    root?.color = NodeColor.BLACK;
  }

  void _deleteNode(RedBlackTreeNode<K, V> node) {
    RedBlackTreeNode<K, V>? y = node; // y is the node that will be physically removed
    NodeColor originalColor = y.color;

    RedBlackTreeNode<K, V>? x; // x is the node that may require rebalancing
    RedBlackTreeNode<K, V>? xParent; // x's parent (needed for potential rebalancing)

    // Cases for node deletion:
    if (node.left == null) {
      x = node.right;
      _transplant(node, node.right); // Transplant node with its right child (or null if no right child)
      xParent = node.parent;
    } else if (node.right == null) {
      x = node.left;
      _transplant(node, node.left); // Transplant node with its left child
      xParent = node.parent;
    } else {
      y = _minimum(node.right!); // Find the node with the minimum value in the node's right subtree
      originalColor = y.color;
      x = y.right;
      xParent = y; // x's parent will be y (even if x is null)

      if (y.parent == node) {
        xParent = y; // If y is node's right child, x's parent is y
      } else {
        _transplant(y, y.right);
        y.right = node.right;
        y.right!.parent = y;
        xParent = y.parent;
      }

      _transplant(node, y);
      y.left = node.left;
      y.left!.parent = y;
      y.color = node.color;
    }

    // If the removed node was black, we may need to rebalance the tree
    if (originalColor == NodeColor.BLACK) {
      _fixDeletion(x, xParent);
    }
  }

  RedBlackTreeNode<K, V>? _searchNode(K key) {
    RedBlackTreeNode<K, V>? current = root;
    while (current != null) {
      if (compare(key, current.key) == 0) {
        return current;
      } else if (compare(key, current.key) < 0) {
        current = current.left;
      } else {
        current = current.right;
      }
    }
    return null;
  }

  void _rotateLeft(RedBlackTreeNode<K, V> node) {
    RedBlackTreeNode<K, V>? y = node.right; // y is the node that will be rotated up
    if (y == null) return; // If there's no right child, no rotation is needed
    node.right = y.left; // y's left subtree becomes node's right subtree

    if (y.left != null) {
      y.left!.parent = node; // Update y's left child's parent to node
    }

    y.parent = node.parent; // y's parent becomes node's parent

    if (node.parent == null) {
      root = y; // If node was the root, y becomes the new root
    } else if (node == node.parent!.left) {
      node.parent!.left = y; // If node was a left child, y becomes the new left child
    } else {
      node.parent!.right = y; // If node was a right child, y becomes the new right child
    }

    y.left = node; // node becomes y's left child
    node.parent = y; // Update node's parent to y
  }

  void _rotateRight(RedBlackTreeNode<K, V> node) {
    RedBlackTreeNode<K, V>? y = node.left; // y is the node that will be rotated up
    if (y == null) return; // If there's no left child, no rotation is needed

    node.left = y.right; // y's right subtree becomes node's left subtree
    if (y.right != null) {
      y.right!.parent = node; // Update y's right child's parent to node
    }

    y.parent = node.parent; // y's parent becomes node's parent

    if (node.parent == null) {
      root = y; // If node was the root, y becomes the new root
    } else if (node == node.parent!.right) {
      node.parent!.right = y; // If node was a right child, y becomes the new right child
    } else {
      node.parent!.left = y; // If node was a left child, y becomes the new left child
    }

    y.right = node; // node becomes y's right child
    node.parent = y; // Update node's parent to y
  }

  void _checkAndAdjustRedBlackProperties(RedBlackTreeNode<K, V>? node) {
    if (node == null || node == root) {
      return; // Nothing to check for root or null node
    }

    // 1. Red Property Violation Check:
    if (node.color == NodeColor.RED && node.parent?.color == NodeColor.RED) {
      _fixRedViolation(node); // Call a helper function to handle the violation
    }

  // 2. Black Property Violation Check (Refined):
  int blackHeightLeft = _blackHeight(node.left);
  int blackHeightRight = _blackHeight(node.right);

  if (blackHeightLeft != blackHeightRight) {
    // Black Property Violation Detected

    // Determine the type of violation and the necessary adjustments

    // Case 1: node is black, its sibling is red
    if (node.color == NodeColor.BLACK && node.parent?.right?.color == NodeColor.RED) {

      // 1. Rotate the parent node to the left
      _rotateLeft(node.parent!);

      // 2. Swap the colors of the parent and sibling
      node.parent!.color = NodeColor.BLACK; // Parent becomes black
      node.parent!.right!.color = NodeColor.RED; // Sibling becomes red

      // 3. Update the sibling for further checks
      node.parent!.parent?.right = node.parent; // Update grandparent's right child to the current parent.
    }
    // Case 2: node is black, its sibling is black, and both of its sibling's children are black
    else if (node.color == NodeColor.BLACK && 
            node.parent?.right?.color == NodeColor.BLACK &&
            node.parent?.right?.left?.color == NodeColor.BLACK &&
            node.parent?.right?.right?.color == NodeColor.BLACK) {

      // 1. Color flip: Change the sibling's color to red
      node.parent?.right?.color = NodeColor.RED;

      // 2. Move the violation up the tree:
      node = node.parent;  // Set current node to its parent
      var xParent = node?.parent;  // Set parent to its grandparent (optional, if needed for context)
      _checkAndAdjustRedBlackProperties(xParent);  // Recursively check and adjust properties
    }

    } 
    // Case 3: node is black, its sibling is black, its sibling's left child is red, and its sibling's right child is black
    else if (node.color == NodeColor.BLACK &&
            node.parent?.right?.color == NodeColor.BLACK &&
            node.parent?.right?.left?.color == NodeColor.RED &&
            node.parent?.right?.right?.color == NodeColor.BLACK) {

      // 1. Perform a right rotation on the sibling:
      _rotateRight(node.parent!.right!);

      // 2. Swap the colors of the sibling and its former left child (now its right child):
      node.parent!.right!.color = NodeColor.BLACK;  // Sibling becomes black
      node.parent!.right!.right!.color = NodeColor.RED; // Sibling's right child (formerly left child) becomes red
      
      // After these adjustments, the situation should now resemble Case 4.
      // The Black Property violation check will likely loop back and handle Case 4.
    }
    // Case 4: node is black, its sibling is black, and its sibling's right child is red
    else if (node.color == NodeColor.BLACK &&
            node.parent?.right?.color == NodeColor.BLACK &&
            node.parent?.right?.right?.color == NodeColor.RED) {

      // 1. Perform a left rotation on the parent:
      _rotateLeft(node.parent!);

      // 2. Swap the colors of the parent and sibling:
      node.parent!.color = node.parent!.parent!.color; //Parent color is grandparent color;
      node.parent!.parent!.color = NodeColor.BLACK; // Grandparent color is black;
      node.parent!.right!.color = NodeColor.BLACK; //Sibling color is black
    }

    // Perform adjustments (e.g., rotations, color flips) to restore the
    // Black Property. This might involve calling helper functions
    // similar to _fixRedViolation, but tailored for Black Property violations.

    // Example (Illustrative):
    // if (node.color == NodeColor.BLACK && 
    //     node.parent?.right?.color == NodeColor.RED && 
    //     node.parent?.right?.left?.color == NodeColor.BLACK && 
    //     node.parent?.right?.right?.color == NodeColor.BLACK) {
    //   // Perform a specific rotation and color flip combination
    //   // to address this particular violation scenario.
    //   // ...
    // }

    // ... (Other violation scenarios and adjustments)

    // Recursively check and adjust child nodes
    _checkAndAdjustRedBlackProperties(node?.left);
    _checkAndAdjustRedBlackProperties(node?.right);
  }
  }

  // Helper function to calculate black height of a subtree
  int _blackHeight(RedBlackTreeNode<K, V>? node) {
    if (node == null) {
      return 1; // Null nodes are considered black
    }
    int height = node.color == NodeColor.BLACK ? 1 : 0;
    return height + _blackHeight(node.left); // Assume left and right subtrees have the same black height
  }

  // Helper function to handle Red Property violation
  void _fixRedViolation(RedBlackTreeNode<K, V> node) {
    // ... (Implementation to perform rotations and color flips 
    // to fix the Red Property violation)
    // This would depend on the specific scenario and tree structure.
  }
}
