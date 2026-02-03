import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Factory for creating standard block operation responses.
class BlockResponseFactory {
  /// Creates a successful add block response.
  static AddBlockResponse successAdd(String message) {
    return AddBlockResponse()
      ..success = true
      ..message = message;
  }

  /// Creates a failed add block response.
  static AddBlockResponse failureAdd(String message) {
    return AddBlockResponse()
      ..success = false
      ..message = message;
  }

  /// Creates a successful get block response.
  static GetBlockResponse successGet(BlockProto block) {
    return GetBlockResponse()
      ..block = block
      ..found = true;
  }

  /// Creates a not found response.
  static GetBlockResponse notFound() {
    return GetBlockResponse()..found = false;
  }

  /// Creates a successful remove block response.
  static RemoveBlockResponse successRemove(String message) {
    return RemoveBlockResponse()
      ..success = true
      ..message = message;
  }

  /// Creates a failed remove block response.
  static RemoveBlockResponse failureRemove(String message) {
    return RemoveBlockResponse()
      ..success = false
      ..message = message;
  }
}
