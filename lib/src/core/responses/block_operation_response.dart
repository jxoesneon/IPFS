import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Generic response wrapper for block operations.
///
/// Contains success status, message, and optional data payload.
/// Used by [BlockStoreOperations] for type-safe results.
class BlockOperationResponse<T> {
  /// Creates a response with status, message, and optional data.
  const BlockOperationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  /// Creates a success response with optional data.
  factory BlockOperationResponse.success(String message, [T? data]) {
    return BlockOperationResponse(success: true, message: message, data: data);
  }

  /// Creates a failure response.
  factory BlockOperationResponse.failure(String message) {
    return BlockOperationResponse(success: false, message: message);
  }

  /// Creates a response from a protobuf message.
  factory BlockOperationResponse.fromProto(dynamic proto) {
    if (proto is AddBlockResponse || proto is RemoveBlockResponse) {
      return BlockOperationResponse<T>(
        success: proto.success as bool,
        message: proto.message as String,
      );
    } else if (proto is GetBlockResponse) {
      if (T != BlockProto) {
        throw ArgumentError('Type mismatch: Expected BlockProto');
      }
      return BlockOperationResponse<T>(
        success: proto.found,
        message: proto.found ? 'Block found' : 'Block not found',
        data: proto.block as T?,
      );
    }
    throw ArgumentError('Unsupported proto type');
  }

  /// Whether the operation succeeded.
  final bool success;

  /// Human-readable result message.
  final String message;

  /// The result data, if any.
  final T? data;
}

