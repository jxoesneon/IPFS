// lib/src/core/data_structures/node_type.dart

/// Types of nodes in the UnixFS data model.
enum NodeType {
  /// An unrecognized node type.
  unknown,

  /// A regular file node.
  file,

  /// A directory containing links to other nodes.
  directory,

  /// A symbolic link to another path.
  symlink,

  /// Raw binary data without structure.
  raw,
}

/// Extension for protobuf conversion of [NodeType].
extension NodeTypeExtension on NodeType {
  /// Converts this [NodeType] to its protobuf integer representation.
  int toProto() {
    switch (this) {
      case NodeType.unknown:
        return 0;
      case NodeType.file:
        return 1;
      case NodeType.directory:
        return 2;
      case NodeType.symlink:
        return 3;
      case NodeType.raw:
        return 4;
    }
  }

  /// Creates a [NodeType] from its protobuf integer representation.
  static NodeType fromProto(int value) {
    switch (value) {
      case 1:
        return NodeType.file;
      case 2:
        return NodeType.directory;
      case 3:
        return NodeType.symlink;
      case 4:
        return NodeType.raw;
      default:
        return NodeType.unknown;
    }
  }
}

