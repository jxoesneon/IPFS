import '../data_structures/block.dart';
import '../../proto/generated/bitswap/bitswap.pb.dart' as proto;

class BitswapService {
  proto.Message_Block convertToProtoBlock(Block block) {
    return block.toBitswapProto();
  }

  Future<Block> convertFromProtoBlock(proto.Message_Block protoBlock) async {
    return await Block.fromBitswapProto(protoBlock);
  }
}
