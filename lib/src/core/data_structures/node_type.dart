// lib/src/core/data_structures/node_type.dart

/// Enum representing the different types of nodes in the IPFS network.
enum NodeType {
  /// Represents a regular node that participates in the IPFS network.
  REGULAR,

  /// Represents a bootstrap node, which helps new nodes join the network.
  BOOTSTRAP,

  /// Represents a relay node, which assists in routing traffic for other nodes.
  RELAY,

  /// Represents a gateway node, which provides HTTP access to IPFS content.
  GATEWAY,

  /// Represents an archival node, which stores large amounts of data for long-term preservation.
  ARCHIVAL,
}

extension NodeTypeExtension on NodeType {
  /// Converts the [NodeType] to its string representation.
  String get name {
    switch (this) {
      case NodeType.REGULAR:
        return 'REGULAR';
      case NodeType.BOOTSTRAP:
        return 'BOOTSTRAP';
      case NodeType.RELAY:
        return 'RELAY';
      case NodeType.GATEWAY:
        return 'GATEWAY';
      case NodeType.ARCHIVAL:
        return 'ARCHIVAL';
      default:
        return 'UNKNOWN';
    }
  }

  /// Converts a string representation to a [NodeType].
  static NodeType fromName(String name) {
    switch (name.toUpperCase()) {
      case 'REGULAR':
        return NodeType.REGULAR;
      case 'BOOTSTRAP':
        return NodeType.BOOTSTRAP;
      case 'RELAY':
        return NodeType.RELAY;
      case 'GATEWAY':
        return NodeType.GATEWAY;
      case 'ARCHIVAL':
        return NodeType.ARCHIVAL;
      default:
        throw ArgumentError('Unknown node type: $name');
    }
  }
}