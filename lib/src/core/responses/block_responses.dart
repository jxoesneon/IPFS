import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Base class for block operation responses.
///
/// Contains success status and message for all block operations.
abstract class BaseResponse {
  /// Whether the operation succeeded.
  final bool success;

  /// Human-readable result message.
  final String message;

  /// Creates a response with [success] status and [message].
  const BaseResponse({
    required this.success,
    required this.message,
  });

  /// Converts to JSON representation.
  Map<String, dynamic> toJson();

  @override
  String toString() => '${runtimeType}(success: $success, message: $message)';
}

/// Response for block add operations.
class BlockAddResponse extends BaseResponse {
  const BlockAddResponse({
    required super.success,
    required super.message,
  });

  factory BlockAddResponse.fromProto(AddBlockResponse proto) {
    return BlockAddResponse(
      success: proto.success,
      message: proto.message,
    );
  }

  AddBlockResponse toProto() {
    return AddBlockResponse()
      ..success = success
      ..message = message;
  }

  @override
  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
      };
}

class BlockGetResponse extends BaseResponse {
  final BlockProto? block;

  const BlockGetResponse({
    required super.success,
    required super.message,
    this.block,
  });

  factory BlockGetResponse.fromProto(GetBlockResponse proto) {
    return BlockGetResponse(
      success: proto.found,
      message: proto.found ? 'Block found' : 'Block not found',
      block: proto.hasBlock() ? proto.block : null,
    );
  }

  GetBlockResponse toProto() {
    return GetBlockResponse()
      ..found = success
      ..block = block!;
  }

  @override
  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'block': block?.toString(),
      };
}

class BlockRemoveResponse extends BaseResponse {
  const BlockRemoveResponse({
    required super.success,
    required super.message,
  });

  factory BlockRemoveResponse.fromProto(RemoveBlockResponse proto) {
    return BlockRemoveResponse(
      success: proto.success,
      message: proto.message,
    );
  }

  RemoveBlockResponse toProto() {
    return RemoveBlockResponse()
      ..success = success
      ..message = message;
  }

  @override
  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
      };
}
