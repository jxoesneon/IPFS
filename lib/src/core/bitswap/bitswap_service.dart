import '../data_structures/block.dart';
import '../../proto/generated/bitswap/bitswap.pb.dart' as proto;

/// Service for converting blocks to and from Bitswap protocol format.
///
/// Bitswap is the block exchange protocol used by IPFS nodes to request
/// and send blocks between peers. This service handles the serialization
/// between the internal [Block] representation and Bitswap protocol buffers.
///
/// Example:
/// ```dart
/// final service = BitswapService();
///
/// // Convert block for network transmission
/// final protoBlock = service.convertToProtoBlock(block);
///
/// // Convert received block back to internal format
/// final block = await service.convertFromProtoBlock(protoBlock);
/// ```
///
/// See also:
/// - [BitswapHandler] for the full Bitswap protocol implementation
/// - [Block] for the internal block representation
class BitswapService {
  /// Converts an internal [Block] to a Bitswap protocol buffer message.
  proto.Message_Block convertToProtoBlock(Block block) {
    return block.toBitswapProto();
  }

  /// Converts a Bitswap protocol buffer block to an internal [Block].
  Future<Block> convertFromProtoBlock(proto.Message_Block protoBlock) async {
    return await Block.fromBitswapProto(protoBlock);
  }
}
