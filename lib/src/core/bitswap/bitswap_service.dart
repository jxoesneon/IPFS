import '../data_structures/block.dart';
import '../../proto/generated/bitswap/bitswap.pb.dart' as proto;

class BitswapService {
  proto.Block convertToProtoBlock(Block block) {
    return block.toBitswapProto();
  }

  Block convertFromProtoBlock(proto.Block protoBlock) {
    return Block.fromBitswapProto(protoBlock);
  }
}
