import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';
import 'package:dart_ipfs/src/proto/base_message.dart';

class BitswapMessage extends BaseProtoMessage {
  BitswapMessage() : super();

  @override
  GeneratedMessage clone() => super.clone();

  factory BitswapMessage.fromBytes(Uint8List bytes) {
    return BaseProtoMessage.fromBytes(
      bytes,
      () => BitswapMessage(),
    );
  }

  @override
  BitswapMessage createEmptyInstance() => BitswapMessage();

  static final BuilderInfo _info = BuilderInfo(
    'BitswapMessage',
    package: const PackageName('ipfs.bitswap'),
    createEmptyInstance: () => BitswapMessage(),
  );

  @override
  BuilderInfo get info_ => _info;
}
