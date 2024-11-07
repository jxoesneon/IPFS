import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

class BlockOperationResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const BlockOperationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory BlockOperationResponse.success(String message, [T? data]) {
    return BlockOperationResponse(
      success: true,
      message: message,
      data: data,
    );
  }

  factory BlockOperationResponse.failure(String message) {
    return BlockOperationResponse(
      success: false,
      message: message,
    );
  }

  factory BlockOperationResponse.fromProto(dynamic proto) {
    if (proto is AddBlockResponse || proto is RemoveBlockResponse) {
      return BlockOperationResponse<T>(
        success: proto.success,
        message: proto.message,
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
}
