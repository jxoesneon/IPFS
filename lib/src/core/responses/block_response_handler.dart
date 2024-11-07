import 'package:protobuf/protobuf.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

class BlockResponseHandler {
  static AddBlockResponse success(String message) {
    return AddBlockResponse()
      ..success = true
      ..message = message;
  }

  static AddBlockResponse failure(String message) {
    return AddBlockResponse()
      ..success = false
      ..message = message;
  }

  static GetBlockResponse found(BlockProto block) {
    return GetBlockResponse()
      ..found = true
      ..block = block;
  }

  static GetBlockResponse notFound() {
    return GetBlockResponse()..found = false;
  }

  static RemoveBlockResponse removed(String message) {
    return RemoveBlockResponse()
      ..success = true
      ..message = message;
  }

  static RemoveBlockResponse notRemoved(String message) {
    return RemoveBlockResponse()
      ..success = false
      ..message = message;
  }
}
