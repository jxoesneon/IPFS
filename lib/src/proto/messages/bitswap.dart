import '../base_message.dart';

class BitswapMessage extends BaseProtoMessage {
  @override
  BitswapMessage clone() => super.clone<BitswapMessage>();

  factory BitswapMessage.fromBytes(Uint8List bytes) {
    return BaseProtoMessage.fromBytes(
      bytes,
      () => BitswapMessage(),
    );
  }
}
