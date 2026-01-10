import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Converts between internal responses and protobuf messages.
class ResponseHandler {
  /// Converts to AddBlockResponse protobuf.
  static AddBlockResponse toAddBlockResponse(BlockOperationResponse<dynamic> response) {
    return AddBlockResponse()
      ..success = response.success
      ..message = response.message;
  }

  /// Converts to GetBlockResponse protobuf.
  static GetBlockResponse toGetBlockResponse(BlockOperationResponse<Block> response) {
    final getBlockResponse = GetBlockResponse()..found = response.success;
    if (response.data != null) {
      getBlockResponse.block = response.data!.toProto();
    }
    return getBlockResponse;
  }

  /// Converts to RemoveBlockResponse protobuf.
  static RemoveBlockResponse toRemoveBlockResponse(BlockOperationResponse<dynamic> response) {
    return RemoveBlockResponse()
      ..success = response.success
      ..message = response.message;
  }

  /// Converts from protobuf response to BlockOperationResponse.
  static BlockOperationResponse<dynamic> fromProtoResponse(dynamic protoResponse) {
    if (protoResponse is AddBlockResponse || protoResponse is RemoveBlockResponse) {
      return BlockOperationResponse(
        success: protoResponse.success as bool,
        message: protoResponse.message as String,
      );
    } else if (protoResponse is GetBlockResponse) {
      return BlockOperationResponse(
        success: protoResponse.found,
        message: protoResponse.found ? 'Block found' : 'Block not found',
        data: Block.fromProto(protoResponse.block),
      );
    }
    throw ArgumentError('Unsupported proto response type');
  }
}
