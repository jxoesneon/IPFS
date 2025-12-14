import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

/// Extension for JSON serialization of IPLD nodes.
extension IPLDNodeJson on IPLDNode {
  /// Converts this node to a JSON string.
  /// Converts this node to a JSON string.
  String toJson() {
    return writeToJson();
  }
}
