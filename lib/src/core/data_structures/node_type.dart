import '../../proto/generated/core/node_type.pb.dart';
// lib/src/core/data_structures/node_type.dart

extension NodeTypeProtoExtension on NodeTypeProto {
  /// Converts the [NodeTypeProto] to its string representation.
  String get name {
    switch (this) {
      case NodeTypeProto.NODE_TYPE_FILE:
        return 'FILE';
      case NodeTypeProto.NODE_TYPE_DIRECTORY:
        return 'DIRECTORY';
      case NodeTypeProto.NODE_TYPE_SYMLINK:
        return 'SYMLINK';
      case NodeTypeProto.NODE_TYPE_REGULAR:
        return 'REGULAR';
      case NodeTypeProto.NODE_TYPE_BOOTSTRAP:
        return 'BOOTSTRAP';
      case NodeTypeProto.NODE_TYPE_RELAY:
        return 'RELAY';
      case NodeTypeProto.NODE_TYPE_GATEWAY:
        return 'GATEWAY';
      case NodeTypeProto.NODE_TYPE_ARCHIVAL:
        return 'ARCHIVAL';
      default:
        return 'UNKNOWN';
    }
  }

  /// Converts a string representation to a [NodeTypeProto].
  static NodeTypeProto fromName(String name) {
    switch (name.toUpperCase()) {
      case 'FILE':
        return NodeTypeProto.NODE_TYPE_FILE;
      case 'DIRECTORY':
        return NodeTypeProto.NODE_TYPE_DIRECTORY;
      case 'SYMLINK':
        return NodeTypeProto.NODE_TYPE_SYMLINK;
      case 'REGULAR':
        return NodeTypeProto.NODE_TYPE_REGULAR;
      case 'BOOTSTRAP':
        return NodeTypeProto.NODE_TYPE_BOOTSTRAP;
      case 'RELAY':
        return NodeTypeProto.NODE_TYPE_RELAY;
      case 'GATEWAY':
        return NodeTypeProto.NODE_TYPE_GATEWAY;
      case 'ARCHIVAL':
        return NodeTypeProto.NODE_TYPE_ARCHIVAL;    
      default:
        return NodeTypeProto.NODE_TYPE_UNSPECIFIED;
    }
  }
}
