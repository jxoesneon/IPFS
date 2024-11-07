import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

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
      return BlockOperationResponse(
        success: proto.success,
        message: proto.message,
      );
    } else if (proto is GetBlockResponse) {
      return BlockOperationResponse(
        success: proto.found,
        message: proto.found ? 'Block found' : 'Block not found',
        data: proto.found ? proto.block : null,
      );
    }
    throw ArgumentError('Unsupported proto type');
  }
}
