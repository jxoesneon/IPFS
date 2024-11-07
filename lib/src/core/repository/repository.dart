import '../data_structures/node.dart';
import '../data_structures/block.dart';
import '../data_structures/node_type.dart';
import '../../proto/generated/bitswap/bitswap.pb.dart' as proto;

class Repository {
  Future<NodeLink> addFile(String path, Block block) async {
    // ... implementation ...
  }

  Future<void> processProtoBlock(proto.Block protoBlock) async {
    // ... implementation ...
  }
}
