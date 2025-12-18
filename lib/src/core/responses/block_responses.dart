import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Base class for block operation responses.
///
/// Contains success status and message for all block operations.
abstract class BaseResponse {
  /// Creates a response with [success] status and [message].
  const BaseResponse({required this.success, required this.message});

  /// Whether the operation succeeded.
  final bool success;

  /// Human-readable result message.
  final String message;

  /// Converts to JSON representation.
  Map<String, dynamic> toJson();

  @override
  String toString() => '$runtimeType(success: $success, message: $message)';
}

/// Response for block add operations.
class BlockAddResponse extends BaseResponse {
  /// Creates an add response.
  const BlockAddResponse({required super.success, required super.message});

  /// Creates from protobuf.
  factory BlockAddResponse.fromProto(AddBlockResponse proto) {
    return BlockAddResponse(success: proto.success, message: proto.message);
  }

  /// Converts to protobuf.
  AddBlockResponse toProto() {
    return AddBlockResponse()
      ..success = success
      ..message = message;
  }

  @override
  Map<String, dynamic> toJson() => {'success': success, 'message': message};
}

/// Response for block get operations.
class BlockGetResponse extends BaseResponse {
  /// Creates a get response with optional [block].
  const BlockGetResponse({
    required super.success,
    required super.message,
    this.block,
  });

  /// Creates from protobuf.
  factory BlockGetResponse.fromProto(GetBlockResponse proto) {
    return BlockGetResponse(
      success: proto.found,
      message: proto.found ? 'Block found' : 'Block not found',
      block: proto.hasBlock() ? proto.block : null,
    );
  }

  /// The retrieved block, if found.
  final BlockProto? block;

  /// Converts to protobuf.
  GetBlockResponse toProto() {
    final response = GetBlockResponse()..found = success;
    if (block != null) {
      response.block = block!;
    }
    return response;
  }

  @override
  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'block': block?.toString(),
  };
}

/// Response for block remove operations.
class BlockRemoveResponse extends BaseResponse {
  /// Creates a remove response.
  const BlockRemoveResponse({required super.success, required super.message});

  /// Creates from protobuf.
  factory BlockRemoveResponse.fromProto(RemoveBlockResponse proto) {
    return BlockRemoveResponse(success: proto.success, message: proto.message);
  }

  /// Converts to protobuf.
  RemoveBlockResponse toProto() {
    return RemoveBlockResponse()
      ..success = success
      ..message = message;
  }

  @override
  Map<String, dynamic> toJson() => {'success': success, 'message': message};
}
