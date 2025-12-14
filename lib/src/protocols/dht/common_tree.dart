// lib/src/protocols/dht/common_tree.dart
/// Common tree structures and enums for DHT implementations

/// Node color for red-black tree implementation
enum NodeColor {
  RED,
  BLACK,
}

/// Base node interface for tree structures
abstract class TreeNode {
  NodeColor? color;
  TreeNode? parent;
  TreeNode? leftChild;
  TreeNode? rightChild;
}
