// lib/src/protocols/dht/common_tree.dart
/// Common tree structures and enums for DHT implementations
library;

/// Node color for red-black tree implementation.
enum NodeColor {
  /// Red node.
  red,

  /// Black node.
  black,
}

/// Base node interface for tree structures.
abstract class TreeNode {
  /// The node color (red or black).
  NodeColor? color;

  /// Parent node reference.
  TreeNode? parent;

  /// Left child node.
  TreeNode? leftChild;

  /// Right child node.
  TreeNode? rightChild;
}

