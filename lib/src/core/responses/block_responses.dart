import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

abstract class BaseResponse {
  final bool success;
  final String message;

  const BaseResponse({
    required this.success,
    required this.message,
  });

  Map<String, dynamic> toJson();

  @override
  String toString() => '${runtimeType}(success: $success, message: $message)';
}

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
