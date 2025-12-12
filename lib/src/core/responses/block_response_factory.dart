import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

class BlockResponseFactory {
  // Add Block Responses
  static AddBlockResponse successAdd(String message) {
    return AddBlockResponse()
      ..success = true
      ..message = message;
  }

  static AddBlockResponse failureAdd(String message) {
    return AddBlockResponse()
      ..success = false
      ..message = message;
  }

  // Get Block Responses
  static GetBlockResponse successGet(BlockProto block) {
    return GetBlockResponse()
      ..block = block
      ..found = true;
  }

  static GetBlockResponse notFound() {
    return GetBlockResponse()
      ..found = false;
  }

  // Remove Block Responses
  static RemoveBlockResponse successRemove(String message) {
    return RemoveBlockResponse()
      ..success = true
      ..message = message;
  }

  static RemoveBlockResponse failureRemove(String message) {
    return RemoveBlockResponse()
      ..success = false
      ..message = message;
  }
}
