import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';

/// Converts between internal responses and protobuf messages.
class ResponseHandler {
  static AddBlockResponse toAddBlockResponse(
    BlockOperationResponse<dynamic> response,
  ) {
    return AddBlockResponse()
      ..success = response.success
      ..message = response.message;
  }

  static GetBlockResponse toGetBlockResponse(
    BlockOperationResponse<Block> response,
  ) {
    final getBlockResponse = GetBlockResponse()..found = response.success;
    if (response.data != null) {
      getBlockResponse.block = response.data!.toProto();
    }
    return getBlockResponse;
  }

  static RemoveBlockResponse toRemoveBlockResponse(
    BlockOperationResponse<dynamic> response,
  ) {
    return RemoveBlockResponse()
      ..success = response.success
      ..message = response.message;
  }

  static BlockOperationResponse<dynamic> fromProtoResponse(
    dynamic protoResponse,
  ) {
    if (protoResponse is AddBlockResponse ||
        protoResponse is RemoveBlockResponse) {
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
