import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Factory methods for creating block operation responses.
class BlockResponseHandler {
  /// Creates a success response for block addition.
  static AddBlockResponse success(String message) {
    return AddBlockResponse()
      ..success = true
      ..message = message;
  }

  /// Creates a failure response for block addition.
  static AddBlockResponse failure(String message) {
    return AddBlockResponse()
      ..success = false
      ..message = message;
  }

  /// Creates a response for a found block.
  static GetBlockResponse found(BlockProto block) {
    return GetBlockResponse()
      ..found = true
      ..block = block;
  }

  /// Creates a response for a not-found block.
  static GetBlockResponse notFound() {
    return GetBlockResponse()..found = false;
  }

  /// Creates a success response for block removal.
  static RemoveBlockResponse removed(String message) {
    return RemoveBlockResponse()
      ..success = true
      ..message = message;
  }

  /// Creates a failure response for block removal.
  static RemoveBlockResponse notRemoved(String message) {
    return RemoveBlockResponse()
      ..success = false
      ..message = message;
  }
}

