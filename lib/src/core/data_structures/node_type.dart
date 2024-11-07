import '../../proto/generated/core/node_type.pb.dart';
// lib/src/core/data_structures/node_type.dart

enum NodeType { unknown, file, directory, symlink, raw }

extension NodeTypeExtension on NodeType {
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
